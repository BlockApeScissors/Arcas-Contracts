// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/binance-cloud/binance-oracle/blob/main/contracts/mock/VRFConsumerBase.sol";


contract ChampionERC721 is ERC721Enumerable, VRFConsumerBase {
    bytes32 internal keyHash;
    uint64 internal subId; // Subscription ID
    uint32 internal callbackGasLimit = 200000; // Example value, adjust as needed
    uint16 internal requestConfirmations = 3; // Example value, adjust as needed

    IERC20 public arcasToken;
    uint256 public counter;

    struct ChampionMetadata {
        uint OwnedArcas;
        uint GeneticsSeed;
    }

    mapping(uint256 => ChampionMetadata) private _championDetails;
    mapping(uint256 => uint256) private _requestIdToTokenId;

    constructor(
        address arcasAddress
    )
        ERC721("Arcas Champion", "CHAMP")
        VRFConsumerBase(
            0x2B30C31a17Fe8b5dd397EF66FaFa503760D4eaF0, // VRF Coordinator on opBNB Testnet
            0x617abc3f53ae11766071d04ada1c7b0fbd49833b9542e9e91da4d3191c70cc80  // keyHash
        )
    {
        subId = 10; // Provided subscription ID
        arcasToken = IERC20(arcasAddress);
        counter = 1;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(tokenId < counter && tokenId != 0, "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked("https://champion.arcas.gg/", Strings.toString(tokenId)));
    }


    function mintChampion(address to) public {
        uint256 requestId = requestRandomWords(keyHash, subId, requestConfirmations, callbackGasLimit, 1);
        _requestIdToTokenId[requestId] = counter;
        _championDetails[counter] = ChampionMetadata(0, 0);
        _mint(to, counter);
        counter ++;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 tokenId = _requestIdToTokenId[requestId];
        _championDetails[tokenId].GeneticsSeed = randomWords[0];
    }

    function getChampionMetadata(uint256 tokenId) public view returns (ChampionMetadata memory) {
        require(tokenId < counter && tokenId != 0, "ERC721Metadata: Nonexistent token");
        return _championDetails[tokenId];
    }

    function depositArcas(uint256 tokenId, uint256 amount) public {
        require(tokenId < counter && tokenId != 0, "ERC721: operator query for nonexistent token");
        require(arcasToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        ChampionMetadata storage champion = _championDetails[tokenId];
        champion.OwnedArcas += amount;
    }

    function getOwnedTokens(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            // Return an empty array if the owner has no tokens
            return new uint256[](0);
        } else {
            uint256[] memory ownedTokens = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                ownedTokens[i] = tokenOfOwnerByIndex(owner, i);
            }
            return ownedTokens;
        }
    }

}
