// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
//import {StGAS} from "../src/StGAS.sol";
import {Fluid} from "../src/Fluid.sol";
import {StGAS} from "src/StGAS.sol";
import {IBlast} from "../src/interfaces/IBlast.sol";

// stGAS: 0x9E182F96EaA5D53CaFA7A1d9ADD79eb5f2a8d6a3
// Fluid: 0x8191Fad7362A8188e2EbfD234E75C73C65cB6fb7
contract FluidTest is Test {
    StGAS public stGAS;
    Fluid public fluid;
    address alice = address(0x1234);
    address test = address(0x74E7b0aA3D60fa68D0626eb8Acb6bf0fEa8f39b0);
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    function setUp() public {
        stGAS = StGAS(0x7fbB72f51DDfF72bc2A4b8B6C08C08bFb4c5e9Df);
        fluid = Fluid(0x19865079fa4A71F9b63aE896D234A9964f9d3DD9);
    }

    function test_view() public {
        stGAS = new StGAS();
        fluid = new Fluid(address(stGAS));
        vm.deal(alice, 100 ether);
        deal(address(stGAS), address(this), 1000e18);
        stGAS.unstake(101e18);
        stGAS.unstake(102e18);
        stGAS.unstake(103e18);
        stGAS.unstake(104e18);

        StGAS.UnstakeInfo[] memory infos = stGAS.getUnstakeInfo(address(this));
        for(uint i =0;i<infos.length;i++) {
            console2.log(infos[i].amount);
        }
    }
    function test_claim() public {
        uint256 balBefore = alice.balance;
        (,uint256 gb,,) = BLAST.readGasParams(address(stGAS));
        console2.log(gb);
        vm.startPrank(alice);

        fluid.mint();
        fluid.stake(500e18);
        vm.stopPrank();

        vm.startPrank(test);
//
//        stGAS.addRewardToFluid();
        uint256 totalClaimed;
//        vm.warp(block.timestamp + 28 days);
//        uint256 claimed = stGAS.gasClaim(1);
//        totalClaimed += claimed;
        stGAS.addRewardToFluid();
        fluid.claim();
        uint256 testBalStGAS = stGAS.balanceOf(test);
        console2.log("claimed stGAS", testBalStGAS);

        stGAS.unstake(testBalStGAS);

        vm.stopPrank();

        vm.startPrank(alice);
        fluid.claim();
        testBalStGAS = stGAS.balanceOf(alice);
        stGAS.unstake(testBalStGAS);

        vm.deal(alice, 100 ether);
        stGAS.distributeGasToStaker{value: 1e18}(1e18);
        vm.stopPrank();
//        vm.warp(block.timestamp + 30 days);

        vm.prank(test);
        stGAS.claim(1, 0);

        vm.prank(alice);
        stGAS.claim(1, 0);
        uint256 balAfter = alice.balance;
        console2.log("stGas unstake", balBefore, balAfter);
//
//        for(uint i =0;i<30;i++) {
//            vm.warp(block.timestamp + 1 days);
//            uint256 claimed = stGAS.gasClaim(1);
//            totalClaimed += claimed;
//        }
//        console2.log(totalClaimed);

    }

}
