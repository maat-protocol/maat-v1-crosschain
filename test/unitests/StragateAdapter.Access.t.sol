//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {AdapterHelper, StargateAdapterHarness} from "../StargateAdapterHelper.sol";
import {StargateAdapter} from "../../src/StargateAdapter.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {StargateBase} from "@stargatefinance/stg-evm-v2/src/StargateBase.sol";
import {MessagingBase} from "@stargatefinance/stg-evm-v2/src//messaging/MessagingBase.sol";
import {MockTokenVault} from "../../src/mocks/MockTokenVault.sol";

import {MaatAddressProviderV1} from "@maat-v1-core/src/periphery/MaatAddressProviderV1.sol";
import {IMaatAddressProvider} from "@maat-v1-core/src/interfaces/IMaatAddressProvider.sol";

contract StargateAdapterAccessTesting is AdapterHelper, Test {
    StargateAdapterHarness adapter;

    function setUp() public {
        address admin = address(this);

        MaatAddressProviderV1 addressProvider = new MaatAddressProviderV1();
        addressProvider.initialize(admin);

        adapter = new StargateAdapterHarness(
            admin,
            address(addressProvider),
            1,
            makeAddr("lzEndpoint")
        );
    }

    function test_SetDstAdapter() public {
        vm.expectRevert();
        vm.prank(address(0x00000001));
        adapter.setDstAdapter(1, makeAddr("dstAdapter1"));

        address nonowner = address(0x1237);
        vm.expectRevert();
        vm.prank(nonowner);
        adapter.setDstAdapter(2, makeAddr("dstAdapter2"));
    }

    function test_SetStargate() public {
        vm.expectRevert();
        vm.prank(address(0x00000001));
        adapter.setStargate(makeAddr("stargate1"));

        address nonowner = address(0x1237);
        vm.expectRevert();
        vm.prank(nonowner);
        adapter.setStargate(makeAddr("stargate2"));
    }

    function test_Withdraw() public {
        vm.expectRevert();
        vm.prank(address(0x00000001));
        adapter.withdraw(makeAddr("EOA1"), 1000000);

        address nonowner = address(0x1237);
        vm.expectRevert();
        vm.prank(nonowner);
        adapter.withdraw(makeAddr("EOA2"), 200000);
    }

    function test_Sweep() public {
        vm.expectRevert();
        vm.prank(address(0x00000001));
        adapter.sweep(makeAddr("EOA1"), makeAddr("token"), 1000000);

        address nonowner = address(0x1237);
        vm.expectRevert();
        vm.prank(nonowner);
        adapter.sweep(makeAddr("EOA2"), makeAddr("token"), 200000);
    }
}
