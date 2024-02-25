// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BlastApp, YieldMode, GasMode} from "./base/BlastApp.sol";

contract EtherBox is Initializable, OwnableUpgradeable, BlastApp {

    address public stGAS;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Because of foundry bug, this have to execute separately
    function initializeBlast() external onlyOwner {
        __BlastApp_init(YieldMode.CLAIMABLE, GasMode.CLAIMABLE, msg.sender);
    }

    function setStGAS(address _stGAS) external onlyOwner {
        stGAS = _stGAS;
    }

    // TODO: send with WETH and add reentrancy guard
    function withdraw(address recipient, uint256 amount) external {
        require(msg.sender == stGAS, "only stGAS");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool status, ) = recipient.call{value: amount}("");
        require(status, "not transferable");
    }

    receive() external payable{

    }
    fallback() external payable{

    }
}
