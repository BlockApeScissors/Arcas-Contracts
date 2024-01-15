// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/IChampion.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RankOracle is Ownable {
    
    IChampionERC721 public championNFT;

    mapping(uint256 => uint256) public championMMRs;

    constructor(address _championNFTAddress, address initialOwner) Ownable(initialOwner) {
        championNFT = IChampionERC721(_championNFTAddress);
    }

    function setChampionMMRs(uint256[] memory ids, uint256[] memory mmrs) external onlyOwner {
        require(ids.length == mmrs.length, "Arrays length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 championCount = ids[i];
            uint256 mmr = mmrs[i];

            require(championCount < championNFT.counter(), "Champion count does not exist");
            championMMRs[championCount] = mmr;
        }
    }

    function getChampionMMR(uint256 championCount) external view returns (uint256) {
        require(championCount < championNFT.counter(), "Champion count does not exist");
        return championMMRs[championCount];
    }
}
