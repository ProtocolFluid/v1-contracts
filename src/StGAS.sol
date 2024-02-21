// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BlastApp, YieldMode, GasMode} from "./base/BlastApp.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBlast, GasMode} from "src/interfaces/IBlast.sol";
import {EtherBox} from "./EtherBox.sol";
import {Fluid} from "./Fluid.sol";

/// @custom:oz-upgrades-from StGAS
contract StGAS is Initializable, OwnableUpgradeable, ERC20Upgradeable, BlastApp {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct UnstakeInfo {
        uint256 index;
        address user;
        uint256 unstakeTime;
        uint256 amount;
        uint256 gasClaimedPerToken;
        bool isClaimed;
    }
//    mapping(address target => bool isWhitelisted) public isWhitelistedContract;
    mapping(address target => int256 deltaEtherBalance) public deltaEtherBalances;

//    mapping(address unstaker => uint256[] unstakeId) public unstakeIds;
    mapping(address unstaker => uint256 latestUnstakeId) public latestUnstakeId;
    mapping(address unstaker => uint256 latestClaimedId) public latestClaimedId;
    mapping(bytes32 unstakeHash => UnstakeInfo unstakeInfo) public unstakeInfos;

    EnumerableSet.AddressSet whitelistedContract;

    uint256 public totalUnstake;
    uint256 public gasClaimedPerToken;

    EtherBox public etherBox;
    Fluid public fluid;

    uint256 public unbondingPeriod;

    uint256 public temp;

    modifier checkIsWhitelisted() {
        require(whitelistedContract.contains(msg.sender), "Not Whitelisted");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) public initializer {
        etherBox = new EtherBox();
        __ERC20_init("stGAS", "stGAS");
        __Ownable_init(owner);
    }

    // Because of foundry bug, this have to execute separately
    function initializeBlast() external onlyOwner {
        __BlastApp_init(YieldMode.CLAIMABLE, GasMode.CLAIMABLE, msg.sender);
    }

    function setFluid(address _fluid) external onlyOwner {
        fluid = Fluid(_fluid);
    }

    function setWhitelist(address target) external onlyOwner {
        whitelistedContract.add(target);
    }

    function addRewardToFluid() external {
        uint256 amountToMint = this.mint(address(this));
        this.approve(address(fluid), amountToMint);
        fluid.addReward(amountToMint);
    }

    function mint(address recipient) public checkIsWhitelisted returns(uint256 amountToMint){
        // check stGAS is governor
        BLAST.configureClaimableGasOnBehalf(msg.sender);
        (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode mode) = BLAST.readGasParams(msg.sender);

        require(deltaEtherBalances[msg.sender] < int256(etherBalance), "deltaEtherBalance error");
        amountToMint = uint256(int256(etherBalance) - deltaEtherBalances[msg.sender]);
        deltaEtherBalances[msg.sender] += int256(amountToMint);
        _mint(recipient, amountToMint);
    }

    function unstake(uint256 amountToBurn) external {
        require(balanceOf(msg.sender) >= amountToBurn, "Insufficient Balance");

//        uint256[] memory unstakeId = unstakeIds[msg.sender];
        uint256 nextId = latestUnstakeId[msg.sender] + 1;
        latestUnstakeId[msg.sender] = nextId;
        bytes32 unstakeHash = keccak256(abi.encode(msg.sender, nextId));

        UnstakeInfo memory unstakeInfo = UnstakeInfo({
            index: nextId,
            user: msg.sender,
            unstakeTime: block.timestamp,
            amount: amountToBurn,
            gasClaimedPerToken: gasClaimedPerToken,
            isClaimed : false
        });
        totalUnstake += amountToBurn;
        unstakeInfos[unstakeHash] = unstakeInfo;

//        unstakeIds.push(nextId);
        _burn(msg.sender, amountToBurn);
    }

    function makeGas(uint256 loop) external {
        for(uint256 i =0;i<loop;i++) {
            temp += 1;
        }
    }

//    function gasClaim(uint256 claimContractCount) external returns(uint256 amountClaimed) {
//        for(uint256 i =0;i<claimContractCount;i++) {
//            address target = whitelistedContract.at(i);
//            // TODO: consider call claimMaxGas with try catch
//            uint256 claimed = BLAST.claimMaxGas(target, address(etherBox));
//            amountClaimed += claimed;
//            deltaEtherBalances[target] -= int256(claimed);
//        }
//        return amountClaimed;
//    }

    function distributeGasToStaker(uint256 amount) external payable {
        require(amount == msg.value, "msg.value error");
        address(etherBox).call{value: msg.value}("");
        _distributeGasToStaker(msg.value);
    }

    function _distributeGasToStaker(uint256 amount) internal {
        if(totalUnstake > 0){
            gasClaimedPerToken = gasClaimedPerToken + amount * 1e18 / totalUnstake;
        } else {
            // TODO: add logic
        }
        
    }

    // TODO: make it ENUM
    function _claim(uint256 targetId, uint256 claimContractCount) internal returns(uint256) {
        bytes32 unstakeHash = keccak256(abi.encode(msg.sender, targetId));
        UnstakeInfo storage unstakeInfo = unstakeInfos[unstakeHash];
        if(unstakeInfo.unstakeTime == 0) {
            return 1;
        }
        if(unstakeInfo.isClaimed) {
            return 2;
        }

        if(claimContractCount == 0) {
            claimContractCount = whitelistedContract.length();
        }

        for(uint256 i =0;i<claimContractCount;i++) {
            address target = whitelistedContract.at(i);
            // TODO: consider call claimMaxGas with try catch. claimMaxGas revert when call twice in one block.
            try BLAST.claimMaxGas(target, address(etherBox)) returns(uint256 claimed) {
                deltaEtherBalances[target] -= int256(claimed);
                _distributeGasToStaker(claimed);
            } catch {}

        }

        uint256 claimedGas = (gasClaimedPerToken - unstakeInfo.gasClaimedPerToken) * unstakeInfo.amount / 1e18;
        require(claimedGas >= unstakeInfo.amount, "Insufficient gas");

        totalUnstake -= unstakeInfo.amount;

        if(claimedGas > unstakeInfo.amount) {
            _distributeGasToStaker(claimedGas - unstakeInfo.amount);
        }

        etherBox.withdraw(msg.sender, unstakeInfo.amount);
        unstakeInfo.isClaimed = true;
        return 0;
    }

    function claim(uint256 index, uint256 claimContractCount) external returns(uint256){
        uint256 error = _claim(index, claimContractCount);
        return error;
    }

    function claimSingle(uint256 claimContractCount) external {
        uint256 targetId = latestClaimedId[msg.sender] + 1;
        latestClaimedId[msg.sender] = targetId;
//        latestUnstakeId[msg.sender] = targetId + 1;
        uint256 error = _claim(targetId, claimContractCount);
        require(error != 1, "no more to claim");
    }

    // TODO: need refactoring, latestUnstakeId, latestClaimedId
    function claimAll(uint256 claimContractCount) external {
        uint256 targetId = latestUnstakeId[msg.sender];
        uint256 error;
        while(error != 1) {
            targetId += 1;
            if(latestUnstakeId[msg.sender] < targetId) {
                break;
            }
            error = _claim(targetId, claimContractCount);
        }
        latestUnstakeId[msg.sender] = targetId - 1;
    }

    function getUnstakeInfo(address user) external view returns(UnstakeInfo[] memory userUnstakeInfos) {
        uint256 targetId = latestUnstakeId[user];
        if(targetId == 0) return userUnstakeInfos;
        userUnstakeInfos = new UnstakeInfo[](targetId);
        for(uint i = 1; i<=targetId; i++) {
            bytes32 unstakeHash = keccak256(abi.encode(user, i));
            UnstakeInfo storage unstakeInfo = unstakeInfos[unstakeHash];
            userUnstakeInfos[i - 1] = unstakeInfo;
        }
    } 
}
