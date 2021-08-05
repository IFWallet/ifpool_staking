// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./library/IERC20.sol";
import "./library/SafeERC20.sol";
import "./library/Ownable.sol";
import "./ValidatorInterface.sol";

contract Wallet is Ownable {
  using SafeERC20 for IERC20;   // for safeTransferFrom, safeTransfer methods 

  // Fixed validator contract address to save some gas since this address won't change
  ValidatorInterface validatorManager;
  
  constructor(ValidatorInterface _validatorManager) {
    validatorManager = _validatorManager;
  }

  receive() external payable {}

  function stake(address validator) public payable onlyOwner {
    validatorManager.stake{value: msg.value}(validator);
  }
  
  function unstake(address validator) public onlyOwner {
    validatorManager.unstake(validator);
  }
  
  function withdrawStaking(address staker, address validator) public onlyOwner {
    validatorManager.withdrawStaking(validator);
    payable(staker).transfer(address(this).balance);
  }
  
  function withdraw(address staker, uint256 amount) public onlyOwner {
    if (amount > address(this).balance) {
      amount = address(this).balance;
    }
    payable(staker).transfer(amount);
  }

  function transferTo(address token, address staker, uint256 amount) public onlyOwner {
    if (amount > IERC20(token).balanceOf(address(this))) {
      amount = IERC20(token).balanceOf(address(this));
    }
    IERC20(token).safeTransfer(staker, amount);
  }
}
