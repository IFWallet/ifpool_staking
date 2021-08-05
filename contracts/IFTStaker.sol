// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./library/SafeMath.sol";
import "./library/SafeERC20.sol";
import "./library/IERC20.sol";
import "./library/OwnableUpgradeable.sol";
import "./library/PausableUpgradeable.sol";

import "./IFTVault.sol";

contract IFTStaker is OwnableUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;   // for add sub mul div methods
    using SafeERC20 for IERC20;   // for safeTransferFrom, safeTransfer methods 

    // PoolInfo
    //   Mapping between lockPeriod and unlockPeriod
    //   During lockPeriod, user can't withdraw,
    //   After lockPeriod, there are unlockPeriod
    //      when user can withdraw and then tokens goes new lockPeriod again
    struct PoolInfo {
        IERC20 lpToken;                 // Token Contract
        uint256 allocPointBase100;      // (Divide by 100 while calculating) How many allocation points assigned to this pool.
        uint256 amount;                 // Amount of token in pool.
        uint256 lockPeriod;             // lock period of  LP pool
        uint256 unlockPeriod;           // unlock period of  LP pool
        uint256 tokenPerDaily;          // 每天奖励金额
        uint256 startTime;              // 奖励发放开始时间
        uint256 endTime;                // 奖励发放结束时间
        bool isOpenReward;              // 是否开启奖励发放
        bool isRewardCet;               // 是否奖励CET 按天计算
        bool emergencyEnable;           // pool withdraw emergency enable
    }
    
    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many lpTokens the user has provided.
        uint256 rewardClaimed;  // Reward that user already claimed, preventing repeat calculation
        uint256 depositTime;    // Last time of deposit operation
        uint256 lastHarvestTime;
        uint256 lastHarvestBlock;
        string refAddress;      // Refer address
    }
    
    // IFT Token Contract
    IERC20 token;
    IFTVault vault;   

    // Fee
    address public feeAccount;
    uint256 public feePerThousand;
    
    // User and Pool registrations
    PoolInfo[] public poolInfo;
    // poolId => address => UserInfo
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total mint reward.
    uint256 public totalMintReward;
    uint256 public totalCetMintReward;

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        string indexed refAddress
    );
    event Withdraw(
        address indexed user, 
        uint256 indexed pid, 
        uint256 amount
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid, 
        uint256 amount
    );

    function initialize(
        IERC20 _ift,
        IFTVault _vault
    ) public initializer {

        __Ownable_init();
        __Pausable_init();

        token = _ift;
        vault = _vault;

        totalMintReward = 0;
        totalCetMintReward = 0;
    }

    function setFee(address _account, uint256 _feePerThousand) public onlyOwner {
        feeAccount = _account;
        feePerThousand = _feePerThousand;
    }
    
    function setVaultContract(IFTVault _vault) public onlyOwner {
        vault = _vault;
    }

    // === Stake pool operations ===

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new pool. Can only be called by the owner.
    function addPool(
        IERC20 _lpToken,
        uint256 _allocPointBase100
    ) public onlyOwner {

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPointBase100: _allocPointBase100,
                amount: 0,
                lockPeriod: 0,
                unlockPeriod: 0,
                tokenPerDaily: 0,
                startTime: 0,
                endTime: 0,
                isOpenReward: false,
                isRewardCet: false,
                emergencyEnable: false
            })
        );
    }

    // Update the given pool's reward setting
    function setPoolReward(uint256 _pid, uint256 _tokenPerDaily, bool _isOpenReward, bool _isRewardCet, uint256 _startTime, uint256 _endTime) public onlyOwner {
      poolInfo[_pid].tokenPerDaily = _tokenPerDaily;
      poolInfo[_pid].isOpenReward = _isOpenReward;
      poolInfo[_pid].isRewardCet = _isRewardCet;
      poolInfo[_pid].startTime = _startTime;
      poolInfo[_pid].endTime = _endTime;
    }

    // Update the given pool's lock period and unlock period.
    function setPoolLockTime(
        uint256 _pid,
        uint256 _lockPeriod,
        uint256 _unlockPeriod
    ) public onlyOwner {
        poolInfo[_pid].lockPeriod = _lockPeriod;
        poolInfo[_pid].unlockPeriod = _unlockPeriod;
    }

    // Update the given pool's withdraw emergency Enable.
    function setPoolEmergencyEnable(uint256 _pid, bool _emergencyEnable)
        public
        onlyOwner
    {
        poolInfo[_pid].emergencyEnable = _emergencyEnable;
    }

    function setPoolAllocPointBase100(
        uint256 _pid,
        uint256 _allocPointBase100
    ) public onlyOwner {
        poolInfo[_pid].allocPointBase100 = _allocPointBase100;
    }

    // View function to see pending tokens on frontend.
    function pendingTokenReward(uint256 _pid, address _user)
        public
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if (user.amount <= 0) {
            return 0;
        }

        uint256 remain = 0;
        uint256 poolReward = tokenRewardPerSecondForPool(_pid).mul(getTimeCount(_pid, user.lastHarvestTime, block.timestamp));
        uint256 userReward = user.amount.mul(100).div(pool.amount).mul(poolReward).div(100);

        if (userReward <= 0) {
          return 0;
        }

        if (pool.isRewardCet == true) {
          remain = address(vault).balance;
        } else {
          remain = vault.amount();
        }

        if (remain < userReward) {
          userReward = remain;
        }

        return userReward;
    }

    
    // === User operations ===

    // Deposit tokens.
    function deposit(
        uint256 _pid,
        uint256 _amount,
        string calldata _refuser
    ) public whenNotPaused {
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        user.refAddress = _refuser;
        harvest(_pid, msg.sender);
        
        if (_amount > 0) {
            // Fee
            if (feePerThousand != 0 && feeAccount != address(0)) {
                uint256 fee = _amount.mul(feePerThousand).div(1000); 
                pool.lpToken.safeTransferFrom(
                    msg.sender,
                    feeAccount,
                    fee
                );

                _amount = _amount.sub(fee);
            }

            pool.lpToken.safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
            
            user.amount = user.amount.add(_amount);
            pool.amount = pool.amount.add(_amount);
            user.depositTime = block.timestamp;

            emit Deposit(msg.sender, _pid, _amount, user.refAddress);
        }
    }

    function canWithdraw(address _address, uint256 _pid, uint256 _amount) view public returns (uint8) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_address];

        if(user.amount < _amount) {
            // Don't have enough to withdraw
            return 2;
        }

        if (_amount > 0 && pool.lockPeriod > 0) {
            uint256 timeDelta = block.timestamp - user.depositTime; 
            bool inLockPeriod = timeDelta < pool.lockPeriod;
            bool notInUnlockPeriod = pool.unlockPeriod > 0 && (timeDelta % pool.lockPeriod) > pool.unlockPeriod;
            if (inLockPeriod || notInUnlockPeriod) {
                return 1;
            }
        }

        return 0;
    }

    // Withdraw tokens.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(canWithdraw(msg.sender, _pid, _amount) == 0, "Not enough or not in unlockPeriod");

        harvest(_pid, msg.sender);
        
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.amount = pool.amount.sub(_amount);
            
            pool.lpToken.safeTransfer(msg.sender, _amount);

            emit Withdraw(msg.sender, _pid, _amount);
        }
    }

    // Havest tokenReward when deposit/withdraw
    function harvest(uint256 _pid, address _user) public {
        uint256 userReward = pendingTokenReward(_pid, _user);

        UserInfo storage user = userInfo[_pid][_user];
        PoolInfo storage pool = poolInfo[_pid];

        if (userReward > 0) {

          if (pool.isRewardCet) {
            vault.withdraw(_user, userReward);
            totalCetMintReward = totalCetMintReward.add(userReward);
          } else {
            totalMintReward = totalMintReward.add(userReward);
            vault.transferTo(_user, userReward);
          }
          user.rewardClaimed = user.rewardClaimed.add(userReward);
        }

        user.lastHarvestTime = block.timestamp;
        user.lastHarvestBlock = block.number;
    }

    // Withdraw all tokens without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            pool.lockPeriod == 0 || pool.emergencyEnable == true,
            "Can't emergencyWithdraw if pool have lockPeriod or not emergencyEnabled"
        );
        
        pool.lpToken.safeTransfer(msg.sender, user.amount);

        user.amount = 0;

        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    //  === Utility Methods ===
    
    // Return amount of block over the given _from to _to block.
    function getTimeCount(uint256 _pid, uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 fromFinal = _from > pool.startTime ? _from : pool.startTime;
        uint256 toFinal = _to > pool.endTime ? pool.endTime : _to;
        if (fromFinal >= toFinal) {
            return 0;
        }
        return toFinal.sub(fromFinal);
    }

    // 每秒产出奖励
    function tokenRewardPerSecondForPool(uint256 _pid) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 dailySecond = 86400;

        if (pool.isOpenReward == false) {
          return 0;
        }

        if (pool.tokenPerDaily == 0) {
          return 0;
        }

        uint256 tokenReward = pool.tokenPerDaily.div(dailySecond);
        return tokenReward;
    }
    
}

