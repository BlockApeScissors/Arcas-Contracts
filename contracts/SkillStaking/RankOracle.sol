// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/IChampion.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RankOracle is Ownable {

    //The Champion ERC721
    IChampionERC721 public championNFT;
    //The mapping of Champion -> MMR
    mapping(uint256 => uint256) private championMMRs;
    //The total MMR on chain
    uint256 public totalMMR;

    constructor(address _championNFTAddress) Ownable(msg.sender) {
        championNFT = IChampionERC721(_championNFTAddress);
    }

    function setChampionMMRs(uint256[] memory mmrs) external onlyOwner {

        //Ensure the MMR list is the same as the number of champions, champ counter is supply + 1
        require(championNFT.counter() - 1 == mmrs.length, "Arrays length mismatch");

        uint256 temp = 0;

        for (uint256 i = 0; i < mmrs.length; i++) {
            championMMRs[i+1] = mmrs[i];
            temp += mmrs[i];
        }

        totalMMR = temp; 
    }

    function getChampionMMR(uint256 championId) external view returns (uint256) {
        require(championId < championNFT.counter(), "Champion count does not exist");
        return championMMRs[championId];
    }
}
