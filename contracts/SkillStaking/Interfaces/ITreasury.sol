pragma solidity ^0.8.0;

// The treasury contract holds the usd to be distributed via skillstaking

interface IArcasTreasury {
    function payout(uint256 amount, address recipient) external;
}