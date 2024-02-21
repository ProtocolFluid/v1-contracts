// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Fluid} from "src/Fluid.sol";
import {StGAS} from "src/StGAS.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

// stGAS: 0xEC7C2FC9216037a4b40Bb24089Adc4D252E80792, 0x9E182F96EaA5D53CaFA7A1d9ADD79eb5f2a8d6a3, 0xCC162B9e6D9c49bBf64A97514D3Ecea55f5Ce593
// Fluid: 0x3e78874f021924310A2c6A5e31A875dda51BEB4E, 0x8191Fad7362A8188e2EbfD234E75C73C65cB6fb7, 0x674D09F41708A261E6b96771eC1439d5dA7af082
contract FluidScript is Script {
    address initialOwner = address(0x74E7b0aA3D60fa68D0626eb8Acb6bf0fEa8f39b0);
    function setUp() public {}

    function stakeAndGetStGAS() public {
        vm.startBroadcast();
        StGAS stGAS = StGAS(0x18B6C39773541999EFFDf988C89009e35Ae45D0A);
        Fluid fluid = Fluid(0xB7b69E6a35d6cF4B9a66774F999f613321BfcEdD);

//        fluid.mint();
//        fluid.stake(500e18);
        stGAS.makeGas(100);
//        stGAS.addRewardToFluid();
    }
    function run() public {
        vm.startBroadcast();
        address stGASProxy = Upgrades.deployTransparentProxy(
            "StGAS.sol",
            initialOwner,
            abi.encodeCall(StGAS.initialize, (initialOwner))
        );
         address fluidProxy = Upgrades.deployTransparentProxy(
             "Fluid.sol",
             initialOwner,
             abi.encodeCall(Fluid.initialize, (stGASProxy, initialOwner))
         );
        console2.log("DEPLOYED stGAS:", stGASProxy);
        console2.log("DEPLOYED fluid:", fluidProxy);

        //cast send --rpc-url https://sepolia.blast.io  --gas-price 10000 0x652537D675041eC4f7dfA0e7a66879439835e1DE "initializeBlast()"
        // fluid.initializeBlast();

        
        // StGAS stGAS = new StGAS();
        // Fluid fluid = new Fluid(address(stGAS));

        // stGAS.setFluid(address(fluid));
        // stGAS.setWhitelist(address(stGAS));
        // fluid.mint();
        // fluid.stake(500e18);
        // stGAS.makeGas(30);
//        stakeAndGetStGAS();
    }
}

