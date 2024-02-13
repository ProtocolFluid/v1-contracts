// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Fluid} from "src/Fluid.sol";
//import {StGAS} from "src/StGAS.sol";
import {StGAS} from "src/StGAS.sol";

// stGAS: 0xEC7C2FC9216037a4b40Bb24089Adc4D252E80792, 0x9E182F96EaA5D53CaFA7A1d9ADD79eb5f2a8d6a3, 0xCC162B9e6D9c49bBf64A97514D3Ecea55f5Ce593
// Fluid: 0x3e78874f021924310A2c6A5e31A875dda51BEB4E, 0x8191Fad7362A8188e2EbfD234E75C73C65cB6fb7, 0x674D09F41708A261E6b96771eC1439d5dA7af082
contract FluidScript is Script {
    function setUp() public {}

    function stakeAndGetStGAS() public {
        vm.startBroadcast();
        StGAS stGAS = StGAS(0x5996E5eDa8e77E0EE4394e7DB3D3F8509C66d978);
        Fluid fluid = Fluid(0xc573EA70d9f515Fc18a45e8799De23dC576227b5);

//        fluid.mint();
//        fluid.stake(500e18);
        stGAS.makeGas(100);
//        stGAS.addRewardToFluid();
    }
    function run() public {
        vm.startBroadcast();
        StGAS stGAS = new StGAS();
        Fluid fluid = new Fluid(address(stGAS));

        stGAS.setFluid(address(fluid));
        stGAS.setWhitelist(address(stGAS));
        fluid.mint();
        fluid.stake(500e18);
        stGAS.makeGas(30);
//        stakeAndGetStGAS();
    }
}
