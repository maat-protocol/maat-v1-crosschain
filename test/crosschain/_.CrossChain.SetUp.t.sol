// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";

import {MessagingFee, OFTReceipt, SendParam, MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import {StargateFixture, StargateTestHelper} from "../environment/StargateTestHelper.sol";

import {StargateAdapter} from "../../src/StargateAdapter.sol";
import {MockTokenVault} from "../../src/mocks/MockTokenVault.sol";

import {StargateAdapterHarness} from "../StargateAdapterHelper.sol";
import {PoolToken} from "@stargatefinance/stg-evm-v2/src/mocks/PoolToken.sol";

import {MaatAddressProviderV1} from "@maat-v1-core/src/periphery/MaatAddressProviderV1.sol";
import {IMaatAddressProvider} from "@maat-v1-core/src/interfaces/IMaatAddressProvider.sol";

// /// Stargate Fixture by chain and asset
struct AdapterFixture {
    address adapter;
    uint32 eid;
}

contract CrossChainSetUp is StargateTestHelper, Test {
    AdapterFixture[] public adapterFixtureList;

    mapping(uint32 eid => AdapterFixture) public adapterFixtures;
    mapping(uint32 dstEid => address adapter) public crosschainAdapters;
    mapping(uint32 eid => mapping(address token => address vault))
        public mockVaults;

    uint8 public NUM_ASSETS = 2;
    uint8 public NUM_CHAINS = 5;
    uint8 public NUM_NATIVE_POOLS = 0;
    uint8 public NUM_OFTS = 4;
    uint8 public NUM_POOLS = 1;

    function setUp() public {
        // 2 assets, each asset has 1 pools, 1 OFTs
        setUpStargate(NUM_ASSETS, NUM_POOLS, NUM_NATIVE_POOLS, NUM_OFTS);

        _setUpAdapterFixtures(NUM_CHAINS);
        _setUpAdapters(NUM_CHAINS, NUM_ASSETS);
    }

    function _setUpAdapterFixtures(uint8 chainNum) internal {
        for (uint32 i = 0; i < chainNum; i++) {
            uint32 eid = i + 1;

            StargateFixture memory stargateFixture = stargateFixtures[eid][1];
            address lzEndpoint = address(stargateFixture.lz.endpoint);
            address admin = address(this);

            MaatAddressProviderV1 addressProvider = new MaatAddressProviderV1();
            addressProvider.initialize(admin);

            StargateAdapterHarness adapter = new StargateAdapterHarness(
                admin,
                address(addressProvider),
                eid,
                lzEndpoint
            );

            AdapterFixture memory _adapterFixture = AdapterFixture({
                adapter: address(adapter),
                eid: eid
            });

            adapterFixtures[eid] = _adapterFixture;
            crosschainAdapters[eid] = _adapterFixture.adapter;
            adapterFixtureList.push(_adapterFixture);
        }
    }

    function _setUpAdapters(uint8 chainNum, uint8 assetNum) internal {
        for (uint32 i = 0; i < chainNum; i++) {
            uint32 eid = i + 1;

            AdapterFixture memory fixture = adapterFixtures[eid];

            StargateAdapterHarness adapter = StargateAdapterHarness(
                payable(fixture.adapter)
            );

            for (uint32 j = 0; j < assetNum; j++) {
                uint32 assetId = j + 1;

                StargateFixture memory stargateFixture = stargateFixtures[eid][
                    uint16(assetId)
                ];

                MockTokenVault mockTokenVault = new MockTokenVault();
                address token = IStargate(stargateFixture.stargate).token();

                mockTokenVault.setAsset(token);

                IMaatAddressProvider addressProvider = IMaatAddressProvider(
                    adapter.addressProvider()
                );

                addressProvider.addVault(address(mockTokenVault));
                adapter.setStargate(stargateFixture.stargate);

                mockVaults[eid][token] = address(mockTokenVault);
            }

            for (uint32 chainId = 0; chainId < chainNum; chainId++) {
                uint32 dstEid = chainId + 1;

                if (eid == dstEid) continue;

                adapter.setDstAdapter(dstEid, crosschainAdapters[dstEid]);
            }
        }
    }
}
