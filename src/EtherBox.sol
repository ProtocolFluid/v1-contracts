// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBlast, YieldMode} from "src/interfaces/IBlast.sol";
contract EtherBox {

    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    address public stGAS;

    constructor(){
        stGAS = msg.sender;
    }

    function setting() external {
        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();
    }
    // TODO: send with WETH and add reentrancy guard
    function withdraw(address recipient, uint256 amount) external {
        require(msg.sender == stGAS, "only stGAS");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool status, ) = recipient.call{value: amount}("");
        require(status, "not transferable");
    }

    // TODO: add access control
    function claimAllYield(address recipient) external {
        BLAST.claimAllYield(address(this), recipient);
    }
    function claimContractsGas() external {
        BLAST.claimMaxGas(address(this), msg.sender);
    }

    receive() external payable{

    }
}
