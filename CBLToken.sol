// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CBLToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("CBL Token", "CBL") {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
}
