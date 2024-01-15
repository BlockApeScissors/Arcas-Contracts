// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IRankOracle.sol";

contract SkillStaking is Ownable {

    uint256 public champLimit;
    uint256 public yieldMultiplier;
    uint256 public yieldFeeConstant;

    constructor(
        uint256 _champLimit,
        uint256 _yieldMultiplier,
        uint256 _yieldFeeConstant
    ) Ownable(msg.sender) {

        champLimit = _champLimit;
        yieldMultiplier = _yieldMultiplier;
        yieldFeeConstant = _yieldFeeConstant;
    }

    function setChampLimit(uint256 newLimit) external onlyOwner {
        champLimit = newLimit;
    }

    function setYieldMultiplier(uint256 newMultiplier) external onlyOwner {
        yieldMultiplier = newMultiplier;
    }

    function setYieldFeeConstant(uint256 newConstant) external onlyOwner {
        yieldFeeConstant = newConstant;
    }

    function calculateEntryFee(uint256 amount, uint256 champStakedTotal) external view returns (uint256) {
        // Calculate the current entry fee level
        uint256 currentFeeLevel = (champStakedTotal * 1000) / champLimit;

        // Calculate the entry fee after staking the given amount
        uint256 feeAfter = ((champStakedTotal + amount) * 1000) / champLimit;

        // Calculate the mid-point fee
        uint256 midPointFee = (currentFeeLevel + feeAfter) / 2;

        return midPointFee;
    }


    function calculateYield(uint256 amount, uint256 championId, uint256 yieldStamp) external view returns (uint256) {
        // Apply your yield calculation logic here using yieldMultiplier, yieldFeeConstant, or any other factors
        // For demonstration purposes, a simple calculation is provided:
        return (amount * yieldMultiplier) / (championId + yieldFeeConstant);
    }
}
