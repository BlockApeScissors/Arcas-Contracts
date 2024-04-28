// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

/// @title - A Chainlink CCIP bridge for Arcas between AVAX and BNB chain.
/// The idea is same single deployment on both chains, allowing you to then set an immutable mirror for the bridge
contract Bridge is Ownable, CCIPReceiver, ReentrancyGuard {

    /////////////////////////////////////////////////////////
    //                                                     //
    //                      EVENTS                         //
    //                                                     //
    /////////////////////////////////////////////////////////

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver contract on the destination chain.
        uint256 amount, // The token amount being bridged
        address tokenRecipient, //The address of the bridge token recipient
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender contract from the source chain.
        address tokenRecipient, // The address of the token recipient
        uint256 amountReceived // The tokens that were sent.
    );

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
    IRouterClient private s_router;
    // Native wrapped token
    IWETH public immutable weth;
    // Bridge on other chain
    address public mirror;
    // Lock the bridge
    bool public lock;

    /////////////////////////////////////////////////////////
    //                                                     //
    //                      CONSTRUCTOR                    //
    //                                                     //            
    ///////////////////////////////////////////////////////// 

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _weth The address of the weth contract.
    /// @param _destinationChainSelector The address of the destination chain selector, this is immutable.
    /// @param _bridgeToken The address of the bridge token, this is immutable.
    constructor(
        address _router, 
        address _weth, 
        uint64 _destinationChainSelector,
        address _bridgeToken
        )
    Ownable()
    CCIPReceiver(_router)
     {
        s_router = IRouterClient(_router);
        weth = IWETH(_weth);
        allowedChainSelector = _destinationChainSelector;
        arcas = IERC20(_bridgeToken);
        lock = true;
        mirror = address(0);
        _initializeOwner(msg.sender);
    }

    /////////////////////////////////////////////////////////
    //                                                     //
    //                 ADMIN CONTROLS                      //
    //                                                     //        
    /////////////////////////////////////////////////////////

    /// @notice Sets receiver of the CCIP call, can only be set once, must be set after initialisation for corresponding address.
    /// @param _mirror the mirrored ccip crosschain contract
    function setMirror(address _mirror ) external onlyOwner {
        require(mirror == address(0) && _mirror != address(0));
        mirror = _mirror;   
    }

    /// @notice Toggle lock for users using the bridge function
    function toggleLock() external onlyOwner {
        lock = !lock;   
    }

    /// @notice Allows the owner to extract additional WETH in contract as fees.
    function withdrawWeth(
        uint256 _amount,
        address _recipient
    ) external onlyOwner {
        require(weth.balanceOf(address(this))>=_amount);
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
        require(!lock, "Bridge Locked");
        //Ensure recipient isn't burn
        require(_tokenRecipient != address(0), "Can't send to burn address");
        //Ensure amount is greater than 0
        require(_amount > 0, "Amout must be greater than 0");

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(mirror), // ABI-encoded receiver address
            data: abi.encode(_amount, _tokenRecipient), // ABI-encoded number and recipient for transfer
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 100_000})
            ),
            // Set the feeToken  address, indicating native wrapped WETH will be used for fees
            feeToken: address(weth)
        });

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            allowedChainSelector,
            evm2AnyMessage
        );

        // Require the msg.value to be larger than the fees
        require(fees <= msg.value, "fee too low");

        // Transfers the tokens into the bridge
        arcas.transferFrom(msg.sender, address(this), _amount);

        // Do wrap of msg.value to WETH
        weth.deposit{value: msg.value}();

        // Approve the Router to transfer WETH on contract's behalf. It will spend the fees in WETH
        weth.approve(address(s_router), fees);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(allowedChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            allowedChainSelector,
            mirror,
            _amount,
            msg.sender,
            address(weth),
            fees
        );

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
            receiver: abi.encode(mirror), // ABI-encoded receiver address
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
        require(any2EvmMessage.sourceChainSelector == allowedChainSelector, "Wrong chain");
        //Ensure the sender is the mirror
        require( abi.decode(any2EvmMessage.sender, (address)) == mirror, "Not mirror contract" );
        //Ensure the bridge is not locked
        require(!lock, "Bridge locked");

        // abi-decoding of the sent token amount for bridging
        (uint256 amount, address tokenRecipient) = abi.decode(any2EvmMessage.data, (uint256, address)); 

        require(arcas.balanceOf(address(this))>=amount);

        // Arcas token transfer
        arcas.transfer(tokenRecipient, amount);

        // Message
        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            mirror, // abi-decoding of the sender address,
            tokenRecipient, // address of the receiving wallet
            amount // amount bridged to receiving wallet
        );
    }
}
