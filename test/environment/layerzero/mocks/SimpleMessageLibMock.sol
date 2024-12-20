// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SimpleMessageLib} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/SimpleMessageLib.sol";

import {LzTestHelper} from "../LzTestHelper.sol";

contract SimpleMessageLibMock is SimpleMessageLib {
    // offchain packets schedule
    LzTestHelper public testHelper;

    constructor(
        address payable _verifyHelper,
        address _endpoint
    ) SimpleMessageLib(_endpoint, address(0x0)) {
        testHelper = LzTestHelper(_verifyHelper);
    }

    function _handleMessagingParamsHook(
        bytes memory _encodedPacket,
        bytes memory _options
    ) internal override {
        testHelper.schedulePacket(_encodedPacket, _options);
    }
}
