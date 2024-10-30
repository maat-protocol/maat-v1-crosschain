//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {Test, console} from "forge-std/Test.sol";
import {AdapterFixture, CrossChainSetUp} from "./_.CrossChain.SetUp.t.sol";
import {StargateAdapter} from "../../src/StargateAdapter.sol";
import {StargateAdapterHarness} from "../StargateAdapterHelper.sol";

import {StargateFixture} from "../environment/StargateTestHelper.sol";

import {PoolToken} from "@stargatefinance/stg-evm-v2/src/mocks/PoolToken.sol";
import {MockTokenVault} from "../../src/mocks/MockTokenVault.sol";

import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {StargateBase} from "@stargatefinance/stg-evm-v2/src/StargateBase.sol";
import {MessagingBase} from "@stargatefinance/stg-evm-v2/src//messaging/MessagingBase.sol";

contract CrossChainTest is CrossChainSetUp {
    function test_SendTokens(uint amountIn) public {
        uint32 srcEid = 1;
        uint32 dstEid = 2;
        uint32 assetId = 1;

        amountIn = bound(amountIn, 1e12, 1e31);

        AdapterFixture memory srcAdapterFixture = adapterFixtures[srcEid];
        AdapterFixture memory dstAdapterFixture = adapterFixtures[dstEid];

        StargateAdapterHarness srcAdapter = StargateAdapterHarness(
            payable(srcAdapterFixture.adapter)
        );

        vm.deal(address(srcAdapter), 1 ether);

        StargateFixture memory srcStargateFixture = stargateFixtures[srcEid][
            uint16(assetId)
        ];
        StargateFixture memory dstStargateFixture = stargateFixtures[dstEid][
            uint16(assetId)
        ];

        PoolToken srcToken = PoolToken(
            IStargate(srcStargateFixture.stargate).token()
        );
        PoolToken dstToken = PoolToken(
            IStargate(dstStargateFixture.stargate).token()
        );

        srcToken.mint(address(this), amountIn);
        srcToken.approve(address(srcAdapter), amountIn);
        MockTokenVault dstTokenVault = MockTokenVault(
            mockVaults[dstEid][address(dstToken)]
        );

        srcAdapter.sendTokens(
            address(dstTokenVault),
            dstEid,
            address(srcToken),
            amountIn,
            bytes32("")
        );

        vm.expectCall(
            address(dstTokenVault),
            abi.encodeWithSelector(dstTokenVault.finishBridge.selector)
        );

        verifyAndExecutePackets();

        uint srcBalanceAfter = srcToken.balanceOf(srcAdapterFixture.adapter);
        uint dstBalanceAfter = dstToken.balanceOf(dstAdapterFixture.adapter);

        uint dstVaultBalanceAfter = dstToken.balanceOf(address(dstTokenVault));

        assertEq(
            dstVaultBalanceAfter + srcBalanceAfter + dstBalanceAfter,
            amountIn
        );
    }

    function test_SendTokensToReceiver(uint amountIn, address receiver) public {
        vm.assume(receiver != address(0));
        uint32 srcEid = 1;
        uint32 dstEid = 3;
        uint32 assetId = 1;

        amountIn = bound(amountIn, 1e12, 1e31);

        AdapterFixture memory srcAdapterFixture = adapterFixtures[srcEid];

        StargateAdapterHarness srcAdapter = StargateAdapterHarness(
            payable(srcAdapterFixture.adapter)
        );

        vm.deal(address(srcAdapter), 1 ether);

        StargateFixture memory srcStargateFixture = stargateFixtures[srcEid][
            uint16(assetId)
        ];
        StargateFixture memory dstStargateFixture = stargateFixtures[dstEid][
            uint16(assetId)
        ];

        PoolToken srcToken = PoolToken(
            IStargate(srcStargateFixture.stargate).token()
        );
        PoolToken dstToken = PoolToken(
            IStargate(dstStargateFixture.stargate).token()
        );

        srcToken.mint(address(this), amountIn);
        srcToken.approve(address(srcAdapter), amountIn);

        uint receiverBalanceBefore = dstToken.balanceOf(receiver);

        srcAdapter.sendTokensToReceiver(
            dstEid,
            address(srcToken),
            amountIn,
            receiver
        );
        verifyAndExecutePackets();
        uint senderBalanceAfter = srcToken.balanceOf(srcAdapterFixture.adapter);
        uint receiverBalanceAfter = dstToken.balanceOf(receiver);

        assertEq(
            receiverBalanceAfter + senderBalanceAfter,
            amountIn + receiverBalanceBefore
        );
    }
}
