// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces/IRankOracle.sol";
import "./Interfaces/IChampion.sol";

contract SkillStaking is Ownable {

    uint256 public champLimit;
    uint256 public yieldBlockReward;
    IRankOracle public rankOracle;
    IChampionERC721 public championNft;
    IERC20 public arcas;

    constructor(

        uint256 _champLimit,
        uint256 _yieldBlockReward,
        address _rankOracle,
        address _championNft,
        address _arcas

    ) Ownable(msg.sender) {

        champLimit = _champLimit;
        yieldBlockReward = _yieldBlockReward;
        rankOracle = IRankOracle(_rankOracle);
        championNft = IChampionERC721(_championNft);
        arcas = IERC20(_arcas);
    
    }

    function setChampLimit(uint256 newLimit) external onlyOwner {
        champLimit = newLimit;
    }

    function setYieldMultiplier(uint256 _yieldBlockReward) external onlyOwner {
        yieldBlockReward = _yieldBlockReward;
    }

    function setRankOracle(address _rankOracle) external onlyOwner {
        rankOracle = IRankOracle(_rankOracle);
    }

    function calculateEntryFee(uint256 amount, uint256 champStakedTotal) external view returns (uint256) {
        // Calculate the current entry fee level as a % * 1000
        return ((champStakedTotal + (amount/2) ) * 1000000 / champLimit);

    }

    function calculateBlockYield(uint256 champStakedTotal, uint256 championId, uint256 totalStaked) external view returns (uint256) {

        //We have RankOracle MMR of Champ, Total Champ count, total MMR, yieldreward, adjusted by 1000000
        uint256 avgMmr = (rankOracle.totalMMR()) / (championNft.counter() - 1);

        // MMR Skew as a % * 1000000, as mmr < avgMmr it is a reduction
        uint256 MmrSkew = (rankOracle.getChampionMMR(championId) * 1000000)/avgMmr;

        // Share of Skillstaking as a % * 1000000
        uint256 poolShare = (champStakedTotal * 1000000) / totalStaked;

        // Find the % of block rewards due to the champion
        return (((yieldBlockReward * poolShare) / 1000000) * MmrSkew) / 1000000; 

    }

}
