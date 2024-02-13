// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {StGAS} from "./StGas.sol";
contract Fluid is ERC20, Ownable {

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
    constructor(address _stGAS) ERC20("Fluid", "Fluid") Ownable(msg.sender) {
        stGAS = StGAS(_stGAS);
    }


    function setStGAS(address _stGAS) external onlyOwner {
        stGAS = StGAS(_stGAS);
    }

    function mint() external {
        _mint(msg.sender, 10000e18);
    }

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
        StakeInfo memory stakeInfo = stakeInfos[msg.sender];
        return stakeInfo.amount;
    }

    function getAmountReward(address user) external view returns(uint256 claimAmount) {
        StakeInfo memory stakeInfo = stakeInfos[msg.sender];
        uint256 stakeAmount = stakeInfo.amount;
        uint256 rewardPerStakeDelta = rewardPerStake - stakeInfo.rewardPerStake;
        claimAmount = rewardPerStakeDelta * stakeAmount / 1e18;
    }
}
