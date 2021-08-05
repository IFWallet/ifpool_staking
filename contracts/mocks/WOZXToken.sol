// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../library/ERC20.sol";
import "../library/ERC20Burnable.sol";
import "../library/Pausable.sol";
import "../library/Ownable.sol";

contract WOZXToken is ERC20, ERC20Burnable, Pausable, Ownable {
    constructor() ERC20("EFFORCE", "WOZX") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
