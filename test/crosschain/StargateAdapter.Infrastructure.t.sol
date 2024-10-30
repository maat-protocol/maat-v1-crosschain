// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {Test, console} from "forge-std/Test.sol";
import {AdapterFixture, CrossChainSetUp} from "./_.CrossChain.SetUp.t.sol";
// import {StargateAdapter} from "../../src/StargateAdapter.sol";
import {StargateAdapterHarness} from "../StargateAdapterHelper.sol";

import {StargateFixture} from "../environment/StargateTestHelper.sol";

import {PoolToken} from "@stargatefinance/stg-evm-v2/src/mocks/PoolToken.sol";

import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {StargateBase} from "@stargatefinance/stg-evm-v2/src/StargateBase.sol";
import {MessagingBase} from "@stargatefinance/stg-evm-v2/src//messaging/MessagingBase.sol";
import {MockTokenVault} from "../../src/mocks/MockTokenVault.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrossChainInfrastructureTest is CrossChainSetUp {
    function test_AdaptersSetUp() public view {
        for (uint32 i = 0; i < NUM_CHAINS; i++) {
            uint32 eid = i + 1;
            AdapterFixture memory fixture = adapterFixtures[eid];
            StargateAdapterHarness adapter = StargateAdapterHarness(
                payable(fixture.adapter)
            );

            assertEq(adapter.srcEid(), eid);

            for (uint32 j = 0; j < NUM_ASSETS; j++) {
                uint32 assetId = j + 1;

                StargateFixture memory stargateFixture = stargateFixtures[eid][
                    uint16(assetId)
                ];
                address stargate = stargateFixture.stargate;
                address token = IStargate(stargate).token();

                assertEq(adapter.stargateByToken(token), stargate);
            }

            // for (uint32 j = 0; j < NUM_CHAINS; j++) {
            //     uint32 dstEid = j + 1;

            //     if (eid == dstEid) continue;

            //     AdapterFixture memory dstFixture = adapterFixtures[dstEid];
            //     address dstAdapter = adapter.dstAdapters(dstEid);

            //     assertEq(dstAdapter, dstFixture.adapter);

            //     // assertEq(adapter.dstAdapters(dstEid), adapterFixtures[dstEid].adapter);
            // }
        }
    }

    /* ======== TESTS OF Setting Up inside the infrastructure ======== */

    function test_setDstAdapter(uint32 eid, uint32 dstEid) public {
        vm.assume(eid != dstEid);
        eid = uint32(bound(eid, 1, NUM_CHAINS));
        dstEid = uint32(bound(dstEid, 1, NUM_CHAINS));

        AdapterFixture memory fixture = adapterFixtures[eid];
        StargateAdapterHarness adapter = StargateAdapterHarness(
            payable(fixture.adapter)
        );
        adapter.setDstAdapter(dstEid, crosschainAdapters[dstEid]);

        assertEq(adapter.dstAdapters(dstEid), crosschainAdapters[dstEid]);
    }

    function test_stargateSetUp(uint32 eid, uint32 assetId) public {
        eid = uint32(bound(eid, 1, NUM_CHAINS));
        assetId = uint32(bound(assetId, 1, NUM_ASSETS));

        AdapterFixture memory fixture = adapterFixtures[eid];
        StargateAdapterHarness adapter = StargateAdapterHarness(
            payable(fixture.adapter)
        );

        StargateFixture memory stargateFixture = stargateFixtures[eid][
            uint16(assetId)
        ];
        address stargate = stargateFixture.stargate;
        adapter.setStargate(stargate);
        assertEq(
            adapter.stargateByToken(IStargate(stargate).token()),
            stargate
        );
    }

    function test_addVault(uint32 eid) public {
        eid = uint32(bound(eid, 1, NUM_CHAINS));
        ERC20 token = new ERC20("Token", "TKN");
        AdapterFixture memory adapterFixture = adapterFixtures[eid];
        StargateAdapterHarness adapter = StargateAdapterHarness(
            payable(adapterFixture.adapter)
        );
        MockTokenVault vault = new MockTokenVault();
        vault.setAsset(address(token));
        adapter.addressProvider().addVault(address(vault));

        assertEq(adapter.addressProvider().isVault(address(vault)), true);
    }

    function test_lzEndpoint(uint32 eid, uint16 assetId) public view {
        eid = uint32(bound(eid, 1, NUM_CHAINS));
        assetId = uint16(bound(eid, 1, NUM_ASSETS));

        AdapterFixture memory adapterFixture = adapterFixtures[eid];
        StargateAdapterHarness adapter = StargateAdapterHarness(
            payable(adapterFixture.adapter)
        );

        StargateFixture memory stargateFixture = stargateFixtures[eid][assetId];
        address lzEndpoint = address(
            StargateBase(stargateFixture.stargate).endpoint()
        );

        assertEq(adapter.lzEndpoint(), lzEndpoint);
    }
}
