pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//This is the simple code for the ARCAS token

contract DummyArcas is ERC20 {

    constructor(
    ) ERC20("ARCAS", "ARCAS") {

        _mint(msg.sender, 100_000_000 * 10**decimals());
    }

}


