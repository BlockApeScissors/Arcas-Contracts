pragma solidity ^0.8.0;

// The skillstaking contract contains the dao set variables and formulas for the protocol. It holds protocol state not user state.

interface ISkillStaking {

    function calculateEntryFee(uint256 amount, uint256 champStakedTotal) external view returns (uint256);
    function calculateYield(uint256 amount, uint256 championId, uint256 yieldStamp) external view returns (uint256);
    function champLimit() external view returns (uint256);
    
}