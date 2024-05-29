// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Mock is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function burn(address _account, uint256 _value) public {
        _burn(_account, _value);
    }

    function mint(address _account, uint256 _value) public {
        _mint(_account, _value);
    }
}
