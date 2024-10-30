// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {ERC165Registry} from "../lib/ERC165Registry.sol";
import {IMaatVaultV1} from "@maat-v1-core/src/interfaces/IMaatVaultV1.sol";

contract MockTokenVault is ERC165Registry {
    using SafeERC20 for ERC20;

    bytes4 constant TokenVaultInterfaceId = bytes4(keccak256("MAAT.V1.Vault"));

    address public asset;

    event BridgeFinished(uint256 amountBridged, bytes32 intentionId);

    constructor() {
        _registerInterface(TokenVaultInterfaceId);
    }

    function deposit(
        address token,
        uint256 amount,
        address receiver,
        uint32 dstEid
    ) external payable {}

    function finishBridge(
        uint256 amountBridged,
        uint32 originEid,
        bytes32 intentionId
    ) external {
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amountBridged);

        emit BridgeFinished(amountBridged, intentionId);
    }

    function setAsset(address _asset) external {
        asset = _asset;
    }
}
