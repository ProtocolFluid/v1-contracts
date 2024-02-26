// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IBlast.sol";

interface IStGAS {
    function mint(address target, address recipient) external returns(uint256);
    function configureYieldModeTarget(address target, YieldMode yield) external;
    function claimYield(address target, address recipientOfYield, uint256 amount) external returns (uint256);
    function claimAllYield(address target, address recipientOfYield) external returns (uint256);
}

contract Operator {
    IStGAS stGAS;
    address owner;

    modifier onlyOwner {
        require(owner == msg.sender, "only owner");
        _;
    }
    constructor(address _stGAS){
        stGAS = IStGAS(_stGAS);
        owner = msg.sender;
    }


    function mint(address target, address recipient) external onlyOwner returns(uint256) {
        return stGAS.mint(target, recipient);
    }
    function configureYieldModeTarget(address target, YieldMode yield) external onlyOwner {
        stGAS.configureYieldModeTarget(target, yield);
    }
    function claimYield(address target, address recipientOfYield, uint256 amount) external onlyOwner returns (uint256) {
        return stGAS.claimYield(target, recipientOfYield, amount);
    }
    function claimAllYield(address target, address recipientOfYield) external onlyOwner returns (uint256) {
        return stGAS.claimAllYield(target, recipientOfYield);
    }
}
