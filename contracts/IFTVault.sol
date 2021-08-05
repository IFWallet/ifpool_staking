// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./library/SafeMath.sol";
import "./library/SafeERC20.sol";
import "./library/IERC20.sol";
import "./library/AccessControl.sol";

contract IFTVault is AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");
    
    // Token contract address
    IERC20 token;
    // Token amount saved in this contract
    uint256 public amount;
    
    constructor(IERC20 _token) {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        token = _token;
    }
    receive() external payable {}

    function deposit(uint256 _amount) public onlyRole(DEPOSIT_ROLE) {
        token.safeTransferFrom(msg.sender, address(this), _amount);
        amount = amount.add(_amount);
        emit Deposit(msg.sender, _amount);
    }
    
    function transferTo(address _address, uint256 _amount) public onlyRole(TRANSFER_ROLE) {
        require(amount >= _amount, "amount not enough");

        amount = amount.sub(_amount);
        token.safeTransfer(_address, _amount);
        emit Withdraw(_address, _amount);
    }

    function withdraw(address _address, uint256 _amount) public onlyRole(TRANSFER_ROLE) {
        require(_amount <= address(this).balance, "amount not enough");
        payable(_address).transfer(_amount);
    }
}
