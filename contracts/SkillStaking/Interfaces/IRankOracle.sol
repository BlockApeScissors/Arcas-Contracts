// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//This is a smart contract to which we write and update champion mmr scores

interface IRankOracle {

    //Address of the connected Champion NFTs
    function championNFT() external view returns (address);

    //Priveleged function to set and update MMRs
    function setChampionMMRs(uint256[] memory ids, uint256[] memory mmrs) external;
    
    //Function to retrieve the MMR of a champion
    function getChampionMMR(uint256 championId) external view returns (uint256);

}
