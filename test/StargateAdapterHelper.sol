//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {StargateFixture, StargateTestHelper} from "./environment/StargateTestHelper.sol";
import {StargateAdapter} from "../src/StargateAdapter.sol";

import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {MessagingFee, OFTReceipt, SendParam, MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MockTokenVault} from "../src/mocks/MockTokenVault.sol";

contract StargateAdapterHarness is StargateAdapter {
    constructor(
        address _admin,
        address _addressProvider,
        uint32 _eid,
        address _lzEndpoint
    ) StargateAdapter(_admin, _addressProvider, _eid, _lzEndpoint) {}

    function prepareSendParams(
        address _stargate,
        uint32 _dstEid,
        uint _amountLD,
        address _receiver,
        bytes memory _composeMsg
    )
        public
        view
        returns (
            uint256 valueToSend,
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        )
    {
        (valueToSend, sendParam, messagingFee) = super._prepareSendParams(
            _stargate,
            _dstEid,
            _amountLD,
            _receiver,
            _composeMsg
        );
    }

    function getTokenByStargate(
        address _stargate
    ) public view returns (address) {
        return super._getTokenFromStargate(_stargate);
    }

    function getStargateAdapterInterfaceId() public pure returns (bytes4) {
        return StargateAdapterInterfaceId;
    }

    function dstAdapters(uint32 dstEid) external view returns (address) {
        return _dstAdapters[dstEid];
    }

    function stargateByToken(address token) external view returns (address) {
        return _stargateByToken[token];
    }
}

contract AdapterHelper {}
