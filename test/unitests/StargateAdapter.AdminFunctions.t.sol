// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {Test, console} from "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {AdapterHelper, StargateAdapterHarness} from "../StargateAdapterHelper.sol";
import {StargateAdapter} from "../../src/StargateAdapter.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {StargateFixture} from "../environment/StargateTestHelper.sol";
import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";

import {MockTokenVault} from "../../src/mocks/MockTokenVault.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {ERC165Registry} from "../../src/lib/ERC165Registry.sol";

import {MaatAddressProviderV1} from "@maat-v1-core/src/periphery/MaatAddressProviderV1.sol";
import {IMaatAddressProvider} from "@maat-v1-core/src/interfaces/IMaatAddressProvider.sol";

contract StargateAdapterAdminFunctionsTesting is
    AdapterHelper,
    Test,
    ERC165Registry
{
    StargateAdapterHarness adapter;

    using ERC165Checker for address;

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

    function test_Withdraw(uint amount) public {
        deal(address(adapter), amount);
        address receiver = makeAddr("EOA");

        adapter.withdraw(receiver, amount);
        assertEq(receiver.balance, amount);
    }

    function test_Sweep(uint amount) public {
        address token = address(new ERC20("Test", "Test"));

        deal(token, address(adapter), amount);

        uint adapterBalance = ERC20(token).balanceOf(address(adapter));

        adapter.sweep(address(this), token, adapterBalance);

        uint adminBalance = ERC20(token).balanceOf(address(this));

        assertEq(adminBalance, adapterBalance);
    }

    function test_setDstAdapter(uint32 dstEid, address dstAdapter) public {
        adapter.setDstAdapter(dstEid, dstAdapter);

        assertEq(adapter.dstAdapters(dstEid), dstAdapter);
    }

    // function test_setUpStargate(uint32 poolId) public {
    //     IStargate stargate = IStargate(makeAddr("stargate"));
    //     poolId = uint32(bound(poolId, 1, 22));
    //     address token = address(new ERC20("Test", "Test"));

    //     adapter.setStargate(address(stargate));
    //     assertEq(adapter.stargateByToken(token), address(stargate));
    // }

    function test_depositOnSrcChain(uint amount) public {
        bytes32 intentionId = "";
        address token = address(new ERC20("Test", "Test"));
        MockTokenVault mockTokenVault = new MockTokenVault();
        mockTokenVault.setAsset(token);
        IMaatAddressProvider addressProvider = IMaatAddressProvider(
            adapter.addressProvider()
        );

        addressProvider.addVault(address(mockTokenVault));

        deal(token, address(adapter), amount);

        vm.expectCall(
            address(mockTokenVault),
            abi.encodeWithSelector(mockTokenVault.finishBridge.selector)
        );

        vm.expectEmit(true, true, false, false);
        emit MockTokenVault.BridgeFinished(amount, intentionId);

        adapter.depositOnSrcChain(address(mockTokenVault), amount, intentionId);
    }

    function test_verifyAdapter() public {
        bool result = address(adapter).supportsInterface(
            adapter.getStargateAdapterInterfaceId()
        );

        assertEq(result, true);

        result = makeAddr("random").supportsInterface(
            adapter.getStargateAdapterInterfaceId()
        );
        console.log("result", result);

        assertEq(result, false);
    }
}
