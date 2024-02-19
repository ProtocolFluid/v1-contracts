// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBlast, YieldMode, GasMode} from "src/interfaces/IBlast.sol";
abstract contract BlastApp {

    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    uint256[50] private __gap;
    
    function __BlastApp_init(YieldMode yieldMode, GasMode gasMode, address governor) internal {
        BLAST.configure(yieldMode, gasMode, governor);
    }

}