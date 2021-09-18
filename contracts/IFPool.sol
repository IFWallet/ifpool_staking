// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./library/IERC20.sol";
import "./library/SafeERC20.sol";

import "./library/OwnableUpgradeable.sol";
import "./library/PausableUpgradeable.sol";
import "./library/SafeMath.sol";

import "./ValidatorInterface.sol";
import "./Wallet.sol";

// TODO pausable implementation needed, e.g can't stake if contract is paused.
contract IFPool is OwnableUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;   // for add sub mul div methods
    using SafeERC20 for IERC20;   // for safeTransferFrom, safeTransfer methods 

    uint256 public totalStakeAmount;
    uint256 public totalRewardAmount;
    uint256 public totalIftRewardAmount;

    // Ratio base on 10000
    // E.g 9000 means 9000/10000 = 90%
    // uint256 public immutable ratioDivBase;
    uint256 public ratioDivBase;
    uint256 public userRewardRatio;           // User get 90% CET reward
    uint256 public iftBonusRatio;             // User get 10% IFT bonus, e.g user will get 0.1 IFT bonus for each CET reward. 
    uint256 public iftPoolRewardRatio; // User get 10% CET reward to IFT Staking Pool.

    // Info of each user.
    struct UserInfo {
      uint256 lastStakedBlock;       // Last time user staked
      uint256 stakeAmount;           // User staked amount
      uint256 lastClaimedBlock;      // Last time the user claimed reward
      bool unstaking;                // There will be no rewards during unstaking period
    }

    enum RewardType {
      NONE,                          // No use, just for padding 0th of enum
      ONLY_CET,                      // Only redistribute CET. E.g for cetfans validator
      IFT_BONUS                      // Redistribute CET with IFT as bonous. E.g for IF validator
    }

    struct ValidatorInfo {
      RewardType rewardType;         // Check RewardType above
      bool enabled;                  // No reward distribution if not enabled
    }

    ValidatorInterface validatorManager;
    IERC20 iftToken;
    address public iftPoolAddress;

    mapping(address => Wallet) public wallets;
    mapping(address => ValidatorInfo) public validatorInfos;
    mapping(address => mapping(address => UserInfo)) public userInfos;

    event Stake(
        address indexed user,
        address validator,
        uint256 amount
    );
    event UnStake(
        address indexed user,
        address validator
    );
    event WithdrawStaking(
        address indexed user,
        address validator
    );
    event Harvest(
        address indexed user,
        address validator,
        uint256 amount,
        string tokenType // CET or IFT;
    );

    function initialize(ValidatorInterface _validatorManager, IERC20 _iftToken, address _iftPoolAddress) public initializer {

      __Ownable_init();
      __Pausable_init();

      iftToken = _iftToken;
      iftPoolAddress = _iftPoolAddress;
      validatorManager = _validatorManager;

      totalStakeAmount = 0;
      totalRewardAmount = 0;
      totalIftRewardAmount = 0;
      userRewardRatio = 9000;
      iftBonusRatio = 2000;
      ratioDivBase = 10000;
      iftPoolRewardRatio = 1000;
    }

    receive() external payable {}

    /**
     * @dev Withdraw reserve CET to redistribute
     **/
    function withdrawReserve() public onlyOwner {
      payable(msg.sender).transfer(address(this).balance);
    }

    // ====== Validator related operations (Will change state) ======

    /**
     * @dev User stake CET to Validator (1000 CET at least due to limitation)
     * @param validator Validator address to stake 
     **/
    function stake(address validator) public payable whenNotPaused {
      Wallet wallet = _walletOf(msg.sender);

      harvest(validator);
      wallet.stake{value: msg.value}(validator);

      UserInfo storage user = userInfos[msg.sender][validator];

      user.lastStakedBlock = block.number;
      user.stakeAmount = user.stakeAmount.add(msg.value);
      user.unstaking = false;

      totalStakeAmount = totalStakeAmount.add(msg.value); // 平台总质押

      emit Stake(msg.sender, validator, msg.value);
    }

    /**
     * @dev User choose to unstake from validator, after StakingLockPeriod, user can withdrawStaking
     * @param validator Validator address to unstake 
     **/
    function unstake(address validator) public {
      harvest(validator);

      Wallet wallet = wallets[msg.sender];
      wallet.unstake(validator);

      UserInfo storage user = userInfos[msg.sender][validator];
      user.unstaking = true;

      
      emit UnStake(msg.sender, validator);
    }
    
    /**
     * @dev User withdrawStaking from validator, staked CET will return to user
     * @param validator Validator address to withdrawStaking 
     **/
    function withdrawStaking(address validator) public payable {
      Wallet wallet = wallets[msg.sender];
      wallet.withdrawStaking(msg.sender, validator);

      UserInfo storage user = userInfos[msg.sender][validator];
      totalStakeAmount = totalStakeAmount.sub(user.stakeAmount);
      user.stakeAmount = 0;

      emit WithdrawStaking(msg.sender, validator);
    }

    /**
     * @dev Havest according shares of block reward from ValidatorManager
     * @param validator Validator address to harvest 
     **/
    function harvest(address validator) public payable whenNotPaused {
      (uint256 rewardAmount, uint256 iftBonusAmount, uint256 iftPoolRewardAmount) = _rewardAmount(msg.sender, validator);

      userInfos[msg.sender][validator].lastClaimedBlock = block.number;
      if (rewardAmount == 0) {
        return;
      }

      ValidatorInfo storage validatorInfo = validatorInfos[validator];

      if (!validatorInfo.enabled) {
        return;
      }

      if (validatorInfo.rewardType == RewardType.IFT_BONUS) {
        // Revert if CET balance not enough to withdraw
        payable(msg.sender).transfer(rewardAmount);
        payable(iftPoolAddress).transfer(iftPoolRewardAmount);
        totalRewardAmount = totalRewardAmount.add(rewardAmount.add(iftPoolRewardAmount));

      } else if (validatorInfo.rewardType == RewardType.ONLY_CET) {
        Wallet wallet = wallets[msg.sender];
        wallet.withdraw(msg.sender, rewardAmount);
        wallet.withdraw(iftPoolAddress, iftPoolRewardAmount);
      }

      // Skip bonus if balanceOf IFT is not enough
      if (iftToken.balanceOf(address(this)) >= iftBonusAmount) {
        iftToken.safeTransfer(msg.sender, iftBonusAmount);
        totalIftRewardAmount = totalIftRewardAmount.add(iftBonusAmount);

        emit Harvest(msg.sender, validator, iftBonusAmount, 'IFT');
      }
      emit Harvest(msg.sender, validator, rewardAmount, 'CET');

    }

    // ====== Validator related query functions (Won't change state) ======

    function getStakingInfo(address staker, address validator) public view returns (uint256, uint256, uint256) {
      return validatorManager.getStakingInfo(address(wallets[staker]), validator);
    }

    function getUserReward(address staker, address validator) public view returns (uint256, uint256, uint256) {
      return _rewardAmount(staker, validator);
    }
    
    function getActivatedValidators() public view returns (address[] memory) {
      return validatorManager.getActivatedValidators();
    }
    
    function getValidatorDescription(address validator) public view
      returns (string memory, string memory, string memory, string memory) {

      return validatorManager.getValidatorDescription(validator);
    }
    
    function getValidatorInfo(address validator) public view
      returns (address, uint8, uint256, uint256, uint256, uint256, address[] memory) {

      return validatorManager.getValidatorInfo(validator);
    }
    
    function totalStaking() public view returns (uint256 ) {
      return validatorManager.totalStaking();
    }
    
    function StakingLockPeriod() public view returns (uint64) {
        return validatorManager.StakingLockPeriod();
    }

    // ====== Reward configuration related functions ======

    function setUserRewardRatio(uint256 _userRewardRatio) public onlyOwner {
      require(_userRewardRatio <= ratioDivBase, "> 10000");

      userRewardRatio = _userRewardRatio;
      iftPoolRewardRatio = ratioDivBase - _userRewardRatio;
    }

    function setIftBonusRatio(uint256 _iftBonusRatio) public onlyOwner {
      iftBonusRatio = _iftBonusRatio;
    }

    function setIftPoolAddress(address _iftPoolAddress) public onlyOwner {
      iftPoolAddress = _iftPoolAddress;
    }

    /**
     * @dev User stake CET to Validator (1000 CET at least due to limitation)
     * @param _validator Validator address to set 
     * @param _rewardType Reward type for according validator: 1 for ONLY_CET, 2 for IFT_BONUS
     **/
    function setValidatorInfo(address _validator, uint256 _rewardType, bool _enabled) public onlyOwner {
      ValidatorInfo storage info = validatorInfos[_validator];
      info.rewardType = RewardType(_rewardType);
      info.enabled = _enabled;
    }

    // ====== Internal helpers ======

    function _walletOf(address user) internal returns (Wallet wallet) {
      wallet = wallets[user];
      if (address(wallet) == address(0)) {
        wallets[user] = new Wallet(validatorManager);
      }

      return wallets[user];
    }

    function _rewardAmount(
      address staker,
      address validator
    ) internal view returns (uint256, uint256, uint256) {

      UserInfo storage userInfo = userInfos[staker][validator];
      ValidatorInfo storage validatorInfo = validatorInfos[validator];

      uint256 userShare = 0;
      uint256 rewardAmount = 0;
      uint256 iftBonusAmount = 0;
      uint256 iftPoolRewardAmount =0;

      // No reward distribution if not enabled
      if (!validatorInfo.enabled) {
        return (rewardAmount, iftBonusAmount, iftPoolRewardAmount);
      }

      if (validatorInfo.rewardType == RewardType.IFT_BONUS) {
        // No rewards during unstaking period
        if (userInfo.unstaking) {
          return (rewardAmount, iftBonusAmount, iftPoolRewardAmount);
        }

        // uint256 userStakeAmount = userInfo.stakeAmount;
        (uint256 userStakeAmount, , ) = getStakingInfo(staker, validator);

        if (userStakeAmount == 0) {
          return (rewardAmount, iftBonusAmount, iftPoolRewardAmount);
        }

        // Each new block generated will distribute 1 CET based on stakingAmount of validator
        // FIXME On rare condition(https://github.com/coinex-smart-chain/csc-genesis-contract/blob/9587caeacafa6c8fa2d452a777f64886c86034fe/contracts/Validators.sol#L460), totalStaking can be 0.

        uint256 deltaBlock = block.number.sub(userInfo.lastClaimedBlock);
        userShare = userStakeAmount.mul(1 ether).div(validatorManager.totalStaking());
        rewardAmount = userShare.mul(deltaBlock).mul(userRewardRatio).div(ratioDivBase);
        iftPoolRewardAmount = userShare.mul(deltaBlock).mul(iftPoolRewardRatio).div(ratioDivBase);

      } else if (validatorInfo.rewardType == RewardType.ONLY_CET) {
        if (address(wallets[staker]) == address(0)) {
          return (0, 0, 0);
        }

        userShare = address(wallets[staker]).balance;
        rewardAmount = userShare.mul(userRewardRatio).div(ratioDivBase);
        iftPoolRewardAmount = userShare.mul(iftPoolRewardRatio).div(ratioDivBase);
      }

      if (rewardAmount == 0) {
        return (0, 0, 0);
      }

      iftBonusAmount = iftPoolRewardAmount.mul(iftBonusRatio).div(ratioDivBase);

      if (iftToken.balanceOf(address(this)) < iftBonusAmount) {
        iftBonusAmount = 0;
      }

      return (rewardAmount, iftBonusAmount, iftPoolRewardAmount);
    }

    function withdraw(address to, uint256 amount) public onlyOwner {
      if (amount > address(this).balance) {
        amount = address(this).balance;
      }
      payable(to).transfer(amount);
    }

    function transferTo(address to, uint256 amount) public onlyOwner {
      if (amount > iftToken.balanceOf(address(this))) {
        amount = iftToken.balanceOf(address(this));
      }
      iftToken.safeTransfer(to, amount);
    }

    // emergency sweep
    function userTransferTo(address token, address user, uint256 amount) public onlyOwner {
      Wallet wallet = _walletOf(user);
      wallet.transferTo(token, user, amount);
    }
    
}
