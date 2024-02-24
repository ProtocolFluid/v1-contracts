// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BlastApp, YieldMode, GasMode} from "./base/BlastApp.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBlast, GasMode} from "src/interfaces/IBlast.sol";
import {EtherBox} from "./EtherBox.sol";

/// @custom:oz-upgrades-from StGAS
contract StGAS is Initializable, OwnableUpgradeable, ERC20Upgradeable, BlastApp {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct UnstakeInfo {
        uint256 index;
        address user;
        uint256 amount;
        uint256 gasClaimedPerToken;
        bool isClaimed;
    }
    mapping(address target => int256 deltaEtherBalance) public deltaEtherBalances;

    mapping(address unstaker => uint256 latestUnstakeId) public latestUnstakeId;
    mapping(bytes32 unstakeHash => UnstakeInfo unstakeInfo) public unstakeInfos;

    EnumerableSet.AddressSet whitelistedContract;
    mapping(address target => address operator) public isOperator;

    uint256 public totalUnstake;
    uint256 public gasClaimedPerToken;

    EtherBox public etherBox;

    uint256 public temp;

    modifier checkIsMintableCaller(address target) {
        require(whitelistedContract.contains(target), "Not Whitelisted");
        require(isOperator[target] == msg.sender, "Not Operator");
        _;
    }


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _etherBox, address owner) public initializer {
        __ERC20_init("stGAS", "stGAS");
        __Ownable_init(owner);
        etherBox = EtherBox(payable(_etherBox));
    }

    // Because of foundry bug, this have to execute separately
    function initializeBlast() external onlyOwner {
        __BlastApp_init(YieldMode.CLAIMABLE, GasMode.CLAIMABLE, msg.sender);
    }

    function setEtherBox(address _etherBox) external onlyOwner {
        etherBox = EtherBox(payable(_etherBox));
    }

    function setWhitelist(address target, address operator) external onlyOwner {
        whitelistedContract.add(target);
        isOperator[target] = operator;
    }

    function changeOperator(address target, address operator) external onlyOwner {
        isOperator[target] = operator;
    }

    // TODO: make external contract to add reward to $FLUID staker


    function mint(address target, address recipient) public checkIsMintableCaller(target) returns(uint256 amountToMint){
        // check stGAS is governor of target contract
        BLAST.configureClaimableGasOnBehalf(target);

        (,uint256 etherBalance,,) = BLAST.readGasParams(target);

        require(deltaEtherBalances[target] < int256(etherBalance), "deltaEtherBalance error");
        amountToMint = uint256(int256(etherBalance) - deltaEtherBalances[target]);
        deltaEtherBalances[target] += int256(amountToMint);
        _mint(recipient, amountToMint);
    }

    function unstake(uint256 amountToBurn) external {
        require(balanceOf(msg.sender) >= amountToBurn, "Insufficient Balance");

        uint256 nextId = latestUnstakeId[msg.sender] + 1;
        latestUnstakeId[msg.sender] = nextId;
        bytes32 unstakeHash = keccak256(abi.encode(msg.sender, nextId));

        UnstakeInfo memory unstakeInfo = UnstakeInfo({
            index: nextId,
            user: msg.sender,
            amount: amountToBurn,
            gasClaimedPerToken: gasClaimedPerToken,
            isClaimed : false
        });
        totalUnstake += amountToBurn;
        unstakeInfos[unstakeHash] = unstakeInfo;

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
        (bool success, ) = address(etherBox).call{value: msg.value}("");
        require(success, "transfer eth to EtherBox failed");
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
    function _claim(uint256 targetId, uint256 claimContractCount) internal{
        bytes32 unstakeHash = keccak256(abi.encode(msg.sender, targetId));
        UnstakeInfo storage unstakeInfo = unstakeInfos[unstakeHash];
        if(unstakeInfo.isClaimed) {
            return;
        }

        if(claimContractCount == 0) {
            claimContractCount = whitelistedContract.length();
        }

        unstakeInfo.isClaimed = true;

        for(uint256 i =0;i<claimContractCount;i++) {
            address target = whitelistedContract.at(i);
            // NOTICE: claimMaxGas revert when call twice in one block.
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
        return;
    }

    function claim(uint256 index, uint256 claimContractCount) external {
        _claim(index, claimContractCount);
    }

    function claimMultiple(uint256[] calldata indices, uint256 claimContractCount) external{
        for(uint i =0;i<indices.length;i++) {
            _claim(indices[i], claimContractCount);
        }
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
