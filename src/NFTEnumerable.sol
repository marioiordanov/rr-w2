// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721Enumerable} from "@openzeppelin/contracts@v5.0.2/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721} from "@openzeppelin/contracts@v5.0.2/token/ERC721/ERC721.sol";
import {Ownable2Step} from "@openzeppelin/contracts@v5.0.2/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts@v5.0.2/access/Ownable.sol";

contract NFTEnumerable is ERC721Enumerable, Ownable2Step {
    uint256 public constant MAX_SUPPLY = 100;

    error MaxSupplyReached();

    constructor() ERC721("NFTEnumerable", "NFTE") Ownable(msg.sender) {}

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == MAX_SUPPLY) {
            revert MaxSupplyReached();
        }
        _mint(to, totalSupply + 1);
        return totalSupply + 1;
    }
}
