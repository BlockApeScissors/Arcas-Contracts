// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// The Position manager contract manages the user positions on skillstaking

interface IPositionManager {

    // Struct determining a Staking position opened by a user, system needs to be upgraded
    struct Position {
        //Amount of Arcas staked
        uint256 stakeAmount;
        //Date Arcas staked
        uint256 stakeStamp;
        //Champion staked under
        uint256 stakeChamp;
        //Latest yield collected
        uint256 yieldStamp;
    }

    //Function to stake a champion with an amount of Arcas
    function deposit(uint256 amount, uint256 championId) external;

    //Function to withdraw staked Arcas from a position you deployed
    function withdraw(uint256 positionIndex) external;

    //Function to retrieve your position
    function getUserPositions(address user) external view returns (Position[] memory);
}