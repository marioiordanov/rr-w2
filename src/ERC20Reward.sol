// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts@v5.0.2/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts@v5.0.2/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts@v5.0.2/access/Ownable.sol";

contract ERC20Reward is ERC20, Ownable2Step {
    constructor() ERC20("ERC20Reward", "RWD") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
