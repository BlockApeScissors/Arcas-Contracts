// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Treasury is Ownable {
    
    IERC20 public usdToken;
    address public positionManager;

    constructor(address _usdToken) Ownable(msg.sender) {
        usdToken = IERC20(_usdToken);
    }

    function setPositionManager(address _positionManager) external onlyOwner {
        positionManager = _positionManager;
    }

    function depositUsd(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer USD tokens into the treasury
        require(usdToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

    }

    function payout(uint256 amount, address recipient) external {
        
        require(msg.sender == positionManager, "Payout must be via SkillStaking");
        require(recipient != address(0), "Recipient can't be burn");
        require(amount > 0, "Amount must be greater than 0");

        // Transfer USD tokens to the recipient
        require(usdToken.transfer(recipient, amount), "Transfer failed");

    }
}
