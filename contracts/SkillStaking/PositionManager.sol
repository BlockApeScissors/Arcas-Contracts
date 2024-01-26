// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/IChampion.sol";
import "./Interfaces/IArcasTreasury.sol";
import "./Interfaces/ISkillStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PositionManager {

    struct Position {
        uint256 stakeAmount;
        uint256 champId;
        uint256 yieldBlock;
    }

    // User Position mapping
    mapping(address => Position[]) public addressPositions;
    // Amount staked under each champion by ID
    mapping(uint256 => uint256) public champIdStakeAmount;
    // Contracts
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
        // Calculate the fee amount to burn to the champion, fix the decimals added on the returned value
        uint256 feeAmount = (amount * (skillStakingContract.calculateEntryFee(amount, champIdStakeAmount[championId]))) / 100000000;
        //Ensure that the total staked under the Champion doesn't go over the set limit
        require(champIdStakeAmount[championId] + amount - feeAmount <= skillStakingContract.champLimit());
        // Transfer ARCAS tokens from the user to the contract
        require(arcasToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Create a new position for the user
        Position memory newPosition = Position({
            stakeAmount: amount-feeAmount,
            champId: championId,
            yieldBlock: block.number

        });
        // Add the position to the user's positions array
        addressPositions[msg.sender].push(newPosition);
        // Add the amount staked under the champion
        champIdStakeAmount[championId] += (amount-feeAmount);
        // Approve the champ contract for the fee burning
        arcasToken.approve(address(championContract), feeAmount);
        // Call the depositArcas function in the Champion contract to pay entry fee
        championContract.depositArcas(championId, feeAmount);

    }

    function collect(uint256 positionIndex) public {

        //Positions of the user and position selected for collection
        Position[] storage positions = addressPositions[msg.sender];
        Position storage position = positions[positionIndex];

        //Calculate the effective block yield of the selected champion
        uint256 champBlockYield = skillStakingContract.calculateBlockYield(champIdStakeAmount[position.champId], position.champId, arcasToken.balanceOf(address(this)) );
        //Calculate the outstanding yield for the position
        uint256 positionYield = ((champBlockYield * (block.number - position.yieldBlock)) * position.stakeAmount ) /champIdStakeAmount[position.champId];
        //Calculate Player fee from 0 - 20% of positionYield
        uint256 playerFee = positionYield * ( champIdStakeAmount[position.champId] * 20000000 / skillStakingContract.champLimit()) / 100000000;

        //Payout player fee
        arcasTreasuryContract.payout(playerFee, championContract.ownerOf(position.champId));
        //Payout staker yield
        arcasTreasuryContract.payout(positionYield-playerFee, msg.sender);
        //Write yield stamp to position
        position.yieldBlock = block.number;

    }

    function withdraw(uint256 positionIndex) external {
        require(positionIndex < addressPositions[msg.sender].length, "Invalid position index");

        //Positions of the user and position selected for collection
        Position[] storage positions = addressPositions[msg.sender];
        Position storage position = positions[positionIndex];

        collect(positionIndex);

        // Transfer staked amount and yield back to the user
        require(arcasToken.transfer(msg.sender, position.stakeAmount), "Transfer failed");

        // Delete the position from the user's positions array
        if (positionIndex < addressPositions[msg.sender].length - 1) {
            // Move the last position to the deleted position index
            addressPositions[msg.sender][positionIndex] = addressPositions[msg.sender][addressPositions[msg.sender].length - 1];
        }
        // Remove the last position (duplicate)
        addressPositions[msg.sender].pop();
    }

    function getUserPositions(address user) external view returns (Position[] memory) {
        return addressPositions[user];
    }
}
