// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StGAS} from "src/StGAS.sol";
import {BlastApp, YieldMode, GasMode} from "./base/BlastApp.sol";

/// @custom:oz-upgrades-from Fluid
contract Fluid is Initializable, OwnableUpgradeable, ERC20Upgradeable, BlastApp {

    struct StakeInfo {
        uint256 amount;
        uint256 rewardPerStake;
    }

    event AddReward(uint256 amount, uint256 newRewardPerStake);
    event Claim(address indexed who, uint256 amount);
    event Stake(address indexed who, uint256 amount);
    event Unstake(address indexed who, uint256 amount);

    mapping(address => StakeInfo) public stakeInfos;
    uint256 public totalStake;
    uint256 public rewardPerStake;

    StGAS public stGAS;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stGAS, address _owner) public initializer {
        stGAS = StGAS(_stGAS);
        __ERC20_init("Fluid", "FLD");
        __Ownable_init(_owner);
    }

    // Because of foundry bug, this have to execute separately
    function initializeBlast() external onlyOwner {
        __BlastApp_init(YieldMode.CLAIMABLE, GasMode.CLAIMABLE, msg.sender);
    }

    function setStGAS(address _stGAS) external onlyOwner {
        stGAS = StGAS(_stGAS);
    }

    function mint() external {
        _mint(msg.sender, 10000e18);
    }

    // TODO: make only reward contract
    function addReward(uint256 amount) external {
        stGAS.transferFrom(msg.sender, address(this), amount);
        rewardPerStake += (amount * 1e18 / totalStake);
        emit AddReward(amount, rewardPerStake);
    }

    function claim() public {
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        uint256 stakeAmount = stakeInfo.amount;
        uint256 rewardPerStakeDelta = rewardPerStake - stakeInfo.rewardPerStake;
        uint256 claimAmount = rewardPerStakeDelta * stakeAmount / 1e18;
        stGAS.transfer(msg.sender, claimAmount);

        stakeInfo.rewardPerStake = rewardPerStake;
        emit Claim(msg.sender, claimAmount);
    }

    function stake(uint256 amount) external {
        claim();

        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        stakeInfo.amount += amount;
        stakeInfo.rewardPerStake = rewardPerStake;
        totalStake += amount;

        _transfer(msg.sender, address(this), amount);
        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        claim();
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        require(amount <= stakeInfo.amount, "no");
        stakeInfo.amount -= amount;
        totalStake -= amount;
        stakeInfo.rewardPerStake = rewardPerStake;

        transfer(msg.sender, amount);
        emit Unstake(msg.sender, amount);
    }


    // VIEW

    function getAmountStake(address user) external view returns(uint256) {
        StakeInfo memory stakeInfo = stakeInfos[user];
        return stakeInfo.amount;
    }

    function getAmountReward(address user) external view returns(uint256 claimAmount) {
        StakeInfo memory stakeInfo = stakeInfos[user];
        uint256 stakeAmount = stakeInfo.amount;
        uint256 rewardPerStakeDelta = rewardPerStake - stakeInfo.rewardPerStake;
        claimAmount = rewardPerStakeDelta * stakeAmount / 1e18;
    }
}
