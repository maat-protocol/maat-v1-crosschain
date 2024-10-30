// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IStargateAdapter {
    event BridgeTokens(
        bytes32 guid,
        address bridgeIniter,
        bytes32 intentionId,
        uint32 dstEid,
        address _vault,
        address token,
        uint256 amountIn,
        uint256 lzFee
    );

    event BridgeTokensToReceiver(
        bytes32 guid,
        address sender,
        uint32 dstEid,
        address token,
        uint256 amountIn,
        address receiver
    );

    event ReceivedOnDestination(
        bytes32 guid,
        address bridgeIniter,
        uint256 receivedAmountLD,
        address vault,
        address executor,
        bytes extraData,
        bytes32 intentionId
    );

    event DepositedOnDestination(bool success);

    event SetDstAdapter(uint32 dstEid, address dstAdapter);

    event SetStargate(address token, address stargate);

    /// @notice sends token to StargateAdapter on destination chain
    function sendTokens(
        address vault,
        uint32 dstEid, // endpoint ID on destination chain
        address srcToken, // token address on source chain
        uint amountLD, // amount in in Local Decimals
        bytes32 intentionId // encoded data for the Vault on destination chain
    ) external;

    function sendTokensToReceiver(
        uint32 dstEid, // endpoint ID on destination chain
        address srcToken, // token address on source chain
        uint amountLD, // amount in in Local Decimals
        address receiver // receiver address on destination chain
    ) external;

    function depositOnSrcChain(
        address _vault,
        uint _amount,
        bytes32 _intentionId
    ) external;

    function setDstAdapter(uint32 _dstEid, address _dstAdapterAddress) external;

    function setStargate(address _stargate) external;

    function setLzExtraOptions(
        uint16 _index,
        uint128 _gas,
        uint128 _value
    ) external;

    function isDstAdapterExists(uint32 dstEid) external view returns (bool);

    function getDstAdapter(uint32 dstEid) external view returns (address);

    function getStargateByToken(address token) external view returns (address);

    function withdraw(address to, uint amount) external;

    function sweep(address to, address token, uint amount) external;
}
