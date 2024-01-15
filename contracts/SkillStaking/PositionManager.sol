// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/IChampion.sol";
import "./Interfaces/IArcasTreasury.sol";
import "./Interfaces/ISkillStaking.sol";
import "./Interfaces/IRankOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PositionManager {

    struct Position {
        uint256 stakeAmount;
        uint256 stakeStamp;
        uint256 stakeChamp;
        uint256 yieldStamp;
    }

    mapping(address => Position[]) public userPositions;
    mapping(uint => uint) public ChampionStakedTotal;
    IERC20 public arcasToken;
    ISkillStaking public skillStakingContract;
    IArcasTreasury public arcasTreasuryContract;
    IChampionERC721 public championContract;

    constructor(
        address _arcasTokenAddress,
        address _skillStakingAddress,
        address _arcasTreasuryAddress,
        address _championContract
    ) {
        arcasToken = IERC20(_arcasTokenAddress);
        skillStakingContract = ISkillStaking(_skillStakingAddress);
        arcasTreasuryContract = IArcasTreasury(_arcasTreasuryAddress);
        championContract = IChampionERC721(_championContract);
    }

    function deposit(uint256 amount, uint256 championId) external {

        // Ensure amount is larger than 0 or deposit is useless
        require(amount > 0, "Amount must be greater than 0");

        // Ensure that the championId input is valid if below the total counter
        require(championId < championContract.counter());

        // Calculate the entry fee, based on champ TVL, skillstaking contract contains a constant alterable by the DAO
        uint256 entryFee = skillStakingContract.calculateEntryFee(amount, ChampionStakedTotal[championId]);

        // Calculate the fee amount to burn to the champion
        uint256 feeAmount = (amount * entryFee) / 100000;

        //Ensure that the total staked under the Champion doesn't go over the set limit
        require(ChampionStakedTotal[championId] + amount - feeAmount <= skillStakingContract.champLimit());

        // Transfer ARCAS tokens from the user to the contract
        require(arcasToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Create a new position for the user
        Position memory newPosition = Position({
            stakeAmount: amount-feeAmount,
            stakeStamp: block.timestamp,
            stakeChamp: championId,
            yieldStamp: block.timestamp

        });

        // Add the position to the user's positions array
        userPositions[msg.sender].push(newPosition);

        ChampionStakedTotal[championId] += amount-feeAmount;

        // Call the depositArcas function in the Champion contract to pay entry fee
        championContract.depositArcas(championId, feeAmount);

    }

    function withdraw(uint256 positionIndex) external {
        require(positionIndex < userPositions[msg.sender].length, "Invalid position index");

        Position storage position = userPositions[msg.sender][positionIndex];

        // Calculate the yield
        uint256 yield = skillStakingContract.calculateYield(position.stakeAmount, position.stakeChamp, position.yieldStamp);

        arcasTreasuryContract.payout(yield, msg.sender);

        // Transfer staked amount and yield back to the user
        require(arcasToken.transfer(msg.sender, position.stakeAmount), "Transfer failed");

        // Delete the position from the user's positions array
        if (positionIndex < userPositions[msg.sender].length - 1) {
            // Move the last position to the deleted position index
            userPositions[msg.sender][positionIndex] = userPositions[msg.sender][userPositions[msg.sender].length - 1];
        }
        // Remove the last position (duplicate)
        userPositions[msg.sender].pop();
    }

    function getUserPositions(address user) external view returns (Position[] memory) {
        return userPositions[user];
    }
}
