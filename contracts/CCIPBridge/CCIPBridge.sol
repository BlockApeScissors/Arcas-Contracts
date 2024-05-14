// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract CCIPBridgeConfiguration is Ownable {
    address router;
    address weth;
    uint64 destinationChainSelector;
    address bridgeToken;

    /// @param _owner The owner of the configuration contract, will be passed to the Bridge contract.
    constructor(address _owner) Ownable() {
        _initializeOwner(_owner);
    }

    /// @param _router The address of the router contract.
    /// @param _weth The address of the weth contract.
    /// @param _destinationChainSelector The address of the destination chain selector, this is immutable.
    /// @param _bridgeToken The address of the bridge token, this is immutable.
    function setConfiguration(
        address _router, 
        address _weth, 
        uint64 _destinationChainSelector,
        address _bridgeToken
    ) external onlyOwner {
        router = _router;
        weth = _weth;
        destinationChainSelector = _destinationChainSelector;
        bridgeToken = _bridgeToken;
    }

    function getRouter() external view returns(address _router) {
        _router = router;
    }

    function getConfiguration() external view returns(
        address _router, 
        address _weth, 
        uint64 _destinationChainSelector,
        address _bridgeToken
    ) {
        _router = router;
        _weth = weth;
        _destinationChainSelector = destinationChainSelector;
        _bridgeToken = bridgeToken;
    }
}

/// @title - A Chainlink CCIP bridge for Arcas between ETH and BNB chain.
/// The idea is same single deployment on both chains, allowing you to then set an immutable mirror for the bridge
contract Bridge is Ownable, CCIPReceiver, ReentrancyGuard {

    /////////////////////////////////////////////////////////
    //                                                     //
    //                      ERRORS                         //
    //                                                     //
    /////////////////////////////////////////////////////////

    error InsufficientWETH();
    error InvalidChainSelector();
    error InvalidSender();
    error BridgeLocked();
    error CannotSendToBurnAddress();
    error InvalidAmount();
    error InsufficientTokenBalance();
    error InsufficientFeePayment();

    /////////////////////////////////////////////////////////
    //                                                     //
    //                      PARAMETERS                     //
    //                                                     //            
    /////////////////////////////////////////////////////////

    // Bridge only for a single chain
    uint64 private immutable allowedChainSelector;
    // Arcas token to be bridged
    IERC20 public immutable arcas;
    // Chainlink CCIP Router 
    IRouterClient private immutable s_router;
    // Native wrapped token
    IWETH public immutable weth;
    // Lock the bridge
    bool public lock;

    /////////////////////////////////////////////////////////
    //                                                     //
    //                      CONSTRUCTOR                    //
    //                                                     //            
    ///////////////////////////////////////////////////////// 

    /// @notice Constructor initializes the contract with the router address.
    constructor(
        address _configuration
        )
    Ownable()
    CCIPReceiver(CCIPBridgeConfiguration(_configuration).getRouter())
     {
        (
            address _router, 
            address _weth, 
            uint64 _destinationChainSelector, 
            address _bridgeToken
        ) = CCIPBridgeConfiguration(_configuration).getConfiguration();

        s_router = IRouterClient(_router);
        weth = IWETH(_weth);
        allowedChainSelector = _destinationChainSelector;
        arcas = IERC20(_bridgeToken);
        lock = true;
        _initializeOwner(CCIPBridgeConfiguration(_configuration).owner());

        weth.approve(_router, type(uint256).max);
    }

    /////////////////////////////////////////////////////////
    //                                                     //
    //                 ADMIN CONTROLS                      //
    //                                                     //        
    /////////////////////////////////////////////////////////

    /// @notice Toggle lock for users using the bridge function
    function toggleLock() external onlyOwner {
        lock = !lock;   
    }

    /// @notice Allows the owner to extract additional WETH in contract as fees.
    function withdrawWeth(
        uint256 _amount,
        address _recipient
    ) external onlyOwner {
        if(weth.balanceOf(address(this)) < _amount) revert InsufficientWETH();

        weth.transfer(_recipient, _amount);
    }
    

    /// @notice Sends data to receiver on the destination chain.
    /// @dev Pays the gas fee with msg.value and wraps it to WETH
    /// @param _amount The uint amount to be sent.
    /// @param _tokenRecipient The address to send token to.
    /// @return messageId The ID of the message that was sent.
    function bridge(
        uint256 _amount,
        address _tokenRecipient
    ) external payable nonReentrant returns (bytes32 messageId) {

        //Ensure bridge is open for use
        if (lock) revert BridgeLocked();
        //Ensure recipient isn't burn
        if (_tokenRecipient == address(0)) revert CannotSendToBurnAddress();
        //Ensure amount is greater than 0
        if (_amount == 0) revert InvalidAmount();

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(address(this)), // ABI-encoded receiver address
            data: abi.encode(_amount, _tokenRecipient), // ABI-encoded number and recipient for transfer
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 100_000})
            ),
            // Set the feeToken  address, indicating native wrapped WETH will be used for fees
            feeToken: address(weth)
        });

        // Transfers the tokens into the bridge
        arcas.transferFrom(msg.sender, address(this), _amount);

        // Cache balance of wrapped native before message send
        uint256 wrappedNativeBalanceBefore = weth.balanceOf(address(this));

        // Do wrap of msg.value to wrapped native
        weth.deposit{value: msg.value}();

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(allowedChainSelector, evm2AnyMessage);

        // Revert if message send consumed more wrapped native than was supplied
        if (wrappedNativeBalanceBefore > weth.balanceOf(address(this))) {
            revert InsufficientFeePayment();
        }

        // Return the message ID
        return messageId;
    }


    // Function for frontend to estimate fee required for bridge in native tokens.
    function getFee(
        uint256 _amount,
        address _tokenRecipient
    ) external view returns (uint256 fee) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(address(this)), // ABI-encoded receiver address
            data: abi.encode(_amount, _tokenRecipient), // ABI-encoded number
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 100_000})
            ),
            // Set the feeToken  address, indicating native wrapped WETH will be used for fees
            feeToken: address(weth)
        });

        // Get the fee required to send the message
        fee = s_router.getFee(
            allowedChainSelector,
            evm2AnyMessage
        );
    }

    /// Handles a CCIP received message and bridges the tokens
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal nonReentrant override {
        
        //Ensure the chain is correct
        if (any2EvmMessage.sourceChainSelector != allowedChainSelector) revert InvalidChainSelector();
        //Ensure the sender is the mirror
        if (abi.decode(any2EvmMessage.sender, (address)) != address(this)) revert InvalidSender();
        //Ensure the bridge is not locked
        if (lock) revert BridgeLocked();

        // abi-decoding of the sent token amount for bridging
        (uint256 amount, address tokenRecipient) = abi.decode(any2EvmMessage.data, (uint256, address)); 

        if (arcas.balanceOf(address(this)) < amount) revert InsufficientTokenBalance();

        // Arcas token transfer
        arcas.transfer(tokenRecipient, amount);
    }
}
