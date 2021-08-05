// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ValidatorInterface {
  event AddToValidatorCandidate( address indexed validator ) ;
  event RemoveFromValidatorCandidate( address indexed valdiator ) ;
  event RewardDistributed( address[] validators,uint256[] rewards,uint256 rewardCount ) ;
  event Staking( address indexed staker,address indexed validator,uint256 amount ) ;
  event Unstake( address indexed staker,address indexed validator,uint256 amount,uint256 unLockHeight ) ;
  event ValidatorCreated( address indexed validator,address indexed rewardAddr ) ;
  event ValidatorSetUpdated( address[] validators ) ;
  event ValidatorSlash( address indexed validator,uint256 amount ) ;
  event ValidatorUnjailed( address indexed validator ) ;
  event ValidatorUpdated( address indexed validator,address indexed rewardAddr ) ;
  event WithdrawRewards( address indexed validator,address indexed rewardAddress,uint256 amount,uint256 nextWithdrawBlock ) ;
  event WithdrawStaking( address indexed staker,address indexed validator,uint256 amount ) ;
  function BlockEpoch(  ) external view returns (uint256 ) ;
  function MaxValidatorNum(  ) external view returns (uint16 ) ;
  function MinimalOfStaking(  ) external view returns (uint256 ) ;
  function MinimalStakingCoin(  ) external view returns (uint256 ) ;
  function SlashContractAddr(  ) external view returns (address ) ;
  function StakingLockPeriod(  ) external view returns (uint64 ) ;
  function ValidatorContractAddr(  ) external view returns (address ) ;
  function ValidatorSlashAmount(  ) external view returns (uint256 ) ;
  function WithdrawRewardPeriod(  ) external view returns (uint64 ) ;
  function create( address rewardAddr,string memory moniker,string memory website,string memory email,string memory details ) external payable returns (bool ) ;
  function distributeBlockReward(  ) external payable  ;
  function edit( address rewardAddr,string memory moniker,string memory website,string memory email,string memory details ) external  returns (bool ) ;
  function getActivatedValidators(  ) external view returns (address[] memory ) ;
  function getStakingInfo( address staker,address validator ) external view returns (uint256 , uint256 , uint256 ) ;
  function getValidatorCandidate(  ) external view returns (address[] memory , uint256[] memory , uint256 ) ;
  function getValidatorDescription( address validator ) external view returns (string memory , string memory , string memory , string memory ) ;
  function getValidatorInfo( address validator ) external view returns (address , uint8 , uint256 , uint256 , uint256 , uint256 , address[] memory ) ;
  function initialize( address[] memory validators ) external   ;
  function initialized(  ) external view returns (bool ) ;
  function isJailed( address validator ) external view returns (bool ) ;
  function isValidatorActivated( address validator ) external view returns (bool ) ;
  function isValidatorCandidate( address who ) external view returns (bool ) ;
  function slashValidator( address validator ) external   ;
  function stake( address validator ) external payable returns (bool ) ;
  function totalStaking(  ) external view returns (uint256 ) ;
  function unjailed(  ) external  returns (bool ) ;
  function unstake( address validator ) external  returns (bool ) ;
  function updateActivatedValidators(  ) external  returns (address[] memory ) ;
  function validateDescription( string memory moniker,string memory website,string memory email,string memory details ) external pure returns (bool ) ;
  function validatorCandidateSet( uint256  ) external view returns (address ) ;
  function validatorSet( uint256  ) external view returns (address ) ;
  function withdrawRewards( address validator ) external  returns (bool ) ;
  function withdrawStaking( address validator ) external  returns (bool ) ;
}
