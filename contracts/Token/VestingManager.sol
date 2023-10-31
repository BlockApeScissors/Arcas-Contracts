pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestingManager is Ownable { 

    // Start and End block for vesting
    uint256 public startBlock;
    uint256 public endBlock;

    // Failsafe wallet
    address public failsafeWallet;

    // Arcas token
    IERC20 public arcas;

    // Vesting struct
    struct Vesting {
        uint256 claimedAmount;
        uint256 totalAmount;
        bool deleted;
    }

    // Mapping to hold vestings
    mapping(address => Vesting) public addressToVestings;

    // Modifier to check if the caller is the failsafeWallet
    modifier onlyFailsafeWallet() {
        require(msg.sender == failsafeWallet, "Only failsafe wallet can call this function");
        _;
    }

    // Constructor
    constructor(uint256 _startBlock, uint256 _endBlock, address _failsafeWallet, address _arcas) {
        require(_failsafeWallet != address(0), "Failsafe wallet cannot be zero address");
        require(_startBlock < _endBlock, "Invalid vesting duration");
        startBlock = _startBlock;
        endBlock = _endBlock;
        failsafeWallet = _failsafeWallet;
        arcas = IERC20(_arcas);
    }

    // Function to change the failsafe wallet, permissioned to failsafewllet
    function changeFailSafe(address _newFailsafeWallet) public onlyFailsafeWallet {
        require(_newFailsafeWallet != address(0), "New failsafe wallet cannot be zero address");
        failsafeWallet = _newFailsafeWallet;

    }

    // Function to create a vesting, permissioned to owner
    function createVesting(address user, uint256 totalAmount) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(addressToVestings[user].totalAmount == 0, "Address has already received vesting");
        require(totalAmount > 0, "Invalid vesting amount");

        arcas.transferFrom(msg.sender, address(this), totalAmount);
        arcas.approve(address(this), totalAmount);
        addressToVestings[user] = Vesting(0, totalAmount, false);

    }

    // Function to delete a vesting, permissioned to failsafewallet
    function deleteVesting(address user) external onlyFailsafeWallet {
        Vesting storage vesting = addressToVestings[user];
        require(!vesting.deleted, "Vesting already deleted");

        arcas.transferFrom(address(this), failsafeWallet, vesting.totalAmount - vesting.claimedAmount);

        vesting.deleted = true;
    }

    //Function to claim available tokens for vesting recipients
    function claimTokens() external {
        Vesting storage vesting = addressToVestings[msg.sender];
        require(!vesting.deleted, "Vesting deleted");
        require(vesting.totalAmount > vesting.claimedAmount, "No vested tokens");

        // Calculate the number of tokens claimable at the current block
        uint256 claimableAmount = calculateClaimableAmount(vesting.totalAmount);

        arcas.transferFrom(address(this), msg.sender, claimableAmount - vesting.claimedAmount);

        vesting.claimedAmount = claimableAmount;

    }

    //Internal function to calculate claimable tokens based on vesting
    function calculateClaimableAmount(uint256 totalAmount) private view returns (uint256) {
        uint256 currentBlock = block.number;
        if (currentBlock <= startBlock) {
            return 0;
        } else if (currentBlock >= endBlock) {
            return totalAmount;
        } else {
            uint256 vestingDuration = endBlock - startBlock;
            uint256 elapsedTime = currentBlock - startBlock;
            return (totalAmount * elapsedTime) / vestingDuration;
        }
    }
}