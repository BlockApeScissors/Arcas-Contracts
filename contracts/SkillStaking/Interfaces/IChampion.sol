// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// The champion contract represents the ERC721 NFT. The contracts have 2 variables, a genetic seed for stat and trait generation as well as an OwnedArcas representing Arcas burnt under the NFT.

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IChampionERC721 {

    //The token to burn under the Champion
    function arcasToken() external view returns (IERC20);

    //The count of the next minted champion (supply + 1)
    function counter() external view returns (uint256);

    //Function to mint a champion, later to be locked under store logic
    function mintChampion(address to) external;

    //Function to retrieve the Genetics int and burnt Arcas int of a specific Champion
    function getChampionMetadata(uint256 tokenId) external view returns (uint, uint);

    //Function to deposit Arcas under a champion NFT effectively burning it forever
    function depositArcas(uint256 tokenId, uint256 amount) external;

    //Function to retrieve the array of token ids held by an address
    function getOwnedTokens(address owner) external view returns (uint256[] memory);
}
