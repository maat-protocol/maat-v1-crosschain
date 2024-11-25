// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {StargateBase, IStargate} from "@stargatefinance/stg-evm-v2/src/StargateBase.sol";
import {MessagingBase} from "@stargatefinance/stg-evm-v2/src/messaging/MessagingBase.sol";

import {MessagingFee, OFTReceipt, SendParam, MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStargateAdapter} from "./interfaces/IStargateAdapter.sol";
import {IMaatVaultV1} from "@maat-v1-core/src/interfaces/IMaatVaultV1.sol";
import {AddressProviderKeeper} from "@maat-v1-core/src/core/base/AddressProviderKeeper.sol";

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {ERC165Registry, IERC165} from "./lib/ERC165Registry.sol";

contract StargateAdapter is
    AddressProviderKeeper,
    IStargateAdapter,
    ILayerZeroComposer,
    ERC165Registry,
    Ownable
{
    using SafeERC20 for ERC20;
    using OptionsBuilder for bytes;
    using ERC165Checker for address;

    bytes4 constant StargateAdapterInterfaceId =
        bytes4(keccak256("MAAT.V1.StargateAdapter"));

    error AddressIsNotAStargatePool(address);
    error ZeroAddress(string errorMsg);

    uint32 public srcEid;
    bytes internal lzExtraOptions;
    address public lzEndpoint;

    mapping(uint32 dstEid => address) internal _dstAdapters;
    mapping(address token => address) internal _stargateByToken;

    /* ======== MODIFIERS ======== */
    modifier onlyVaultOrAdmin(address sender) {
        require(
            addressProvider().isVault(sender) || sender == owner(),
            "StargateAdapter: Caller is not vault or admin"
        );
        _;
    }

    modifier onlyStargatePoolAndLzEndpoint(address from, address sender) {
        _validateStargatePool(from);
        require(
            sender == lzEndpoint,
            "StargateAdapter: Caller is not endpoint"
        );
        _;
    }

    modifier onlySupportedToBridge(uint32 dstEid, address token) {
        require(
            isTokenSupportedToBridge(dstEid, token),
            "StargateAdapter: Token is not supported to bridge to dst chain"
        );
        _;
    }

    modifier onlyNotZeroAddress(address receiver) {
        require(
            receiver != address(0),
            "StargateAdapter: receiver is zero address"
        );
        _;
    }

    modifier onlySupportedEid(uint32 dstEid) {
        require(
            isDstAdapterExists(dstEid),
            "StargateAdapter: dstAdapter for eid is not set."
        );
        _;
    }
    /* ======== CONSTRUCTOR ======== */

    constructor(
        address _admin,
        address addressProvider,
        uint32 _srcEid,
        address _lzEndpoint
    ) Ownable() AddressProviderKeeper(addressProvider) {
        srcEid = _srcEid;
        lzEndpoint = _lzEndpoint;

        setLzExtraOptions(0, 300_000, 0);
        _registerInterface(StargateAdapterInterfaceId);
        _registerInterface(type(IERC165).interfaceId);

        transferOwnership(_admin);
    }

    /* ======== SEND TOKENS FUNCTION ======== */

    function sendTokens(
        address _vault,
        uint32 _dstEid,
        address _token,
        uint _amountLD,
        bytes32 _intentionId
    )
        external
        onlyVaultOrAdmin(msg.sender)
        onlySupportedToBridge(_dstEid, _token)
        onlySupportedEid(_dstEid)
        onlyNotZeroAddress(_vault)
    {
        bytes memory composeMsg = abi.encode(
            _vault,
            msg.sender,
            srcEid,
            _intentionId
        );

        (MessagingReceipt memory msgReceipt, ) = _sendTokens(
            _dstEid,
            _token,
            _amountLD,
            composeMsg,
            _dstAdapters[_dstEid]
        );
        emit BridgeTokens(
            msgReceipt.guid,
            msg.sender,
            _intentionId,
            _dstEid,
            _vault,
            _token,
            _amountLD,
            msgReceipt.fee.nativeFee
        );
    }

    function sendTokensToReceiver(
        uint32 _dstEid,
        address _token,
        uint _amountLD,
        address _receiver
    )
        external
        onlyVaultOrAdmin(msg.sender)
        onlySupportedToBridge(_dstEid, _token)
        onlyNotZeroAddress(_receiver)
    {
        (MessagingReceipt memory msgReceipt, ) = _sendTokens(
            _dstEid,
            _token,
            _amountLD,
            "",
            _receiver
        );
        emit BridgeTokensToReceiver(
            msgReceipt.guid,
            msg.sender,
            _dstEid,
            _token,
            _amountLD,
            _receiver
        );
    }

    /* ======== RECEIVE TOKENS FUNCTION ======== */
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable onlyStargatePoolAndLzEndpoint(_from, msg.sender) {
        uint256 receivedAmountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);
        (
            address vault,
            address bridgeIniter,
            uint32 originEid,
            bytes32 intentionId
        ) = abi.decode(_composeMessage, (address, address, uint32, bytes32));

        emit ReceivedOnDestination(
            _guid,
            bridgeIniter,
            receivedAmountLD,
            vault,
            _executor,
            _extraData,
            intentionId
        );

        require(
            addressProvider().isVault(vault),
            "StargateAdapter: received address in not MaatVault"
        );

        _depositOnSrcChain(
            IMaatVaultV1(vault),
            receivedAmountLD,
            originEid,
            intentionId
        );
    }

    /* ======== ADMIN FUNCTIONS ======== */
    // TODO: add event that bridge was finished on scr chain. Need to pass the guid of faileb bridge here as argument
    function depositOnSrcChain(
        address _vault,
        uint _amount,
        bytes32 _intentionId
    ) external onlyVaultOrAdmin(msg.sender) {
        _depositOnSrcChain(IMaatVaultV1(_vault), _amount, srcEid, _intentionId);
    }

    function withdraw(address to, uint amount) external onlyOwner {
        require(
            amount <= address(this).balance,
            "StargateAdapter: Insufficient balance for withdraw."
        );
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "StargateAdapter: withdrawal failed");
    }

    function sweep(address to, address token, uint amount) external onlyOwner {
        require(
            amount <= ERC20(token).balanceOf(address(this)),
            "StargateAdapter: Insufficient token balance for sweep."
        );
        ERC20(token).safeTransfer(to, amount);
    }

    /* ======== SETUP FUNCTIONS ======== */

    function setDstAdapter(
        uint32 _dstEid,
        address _dstAdapterAddress
    ) external onlyOwner {
        _dstAdapters[_dstEid] = _dstAdapterAddress;
        emit SetDstAdapter(_dstEid, _dstAdapterAddress);
    }

    function setStargate(address _stargate) external onlyOwner {
        _validateStargatePool(_stargate);

        address token = _getTokenFromStargate(_stargate);
        _stargateByToken[token] = _stargate;

        emit SetStargate(token, _stargate);
    }

    function setLzExtraOptions(
        uint16 _index,
        uint128 _gas,
        uint128 _value
    ) public onlyOwner {
        lzExtraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(
            _index,
            _gas,
            _value
        );
    }

    /* ======== VIEW FUNCTIONS ======== */
    function isDstAdapterExists(uint32 dstEid) public view returns (bool) {
        return _dstAdapters[dstEid] != address(0);
    }

    function isTokenSupportedToBridge(
        uint32 _dstEid,
        address token
    ) public view returns (bool) {
        StargateBase stargate = StargateBase(_stargateByToken[token]);

        return stargate.paths(_dstEid) > 0;
    }

    function getDstAdapter(uint32 dstEid) external view returns (address) {
        address dstAdapter = _dstAdapters[dstEid];
        if (dstAdapter == address(0)) revert ZeroAddress("dstAdapter");

        return dstAdapter;
    }

    function getStargateByToken(address token) external view returns (address) {
        address stargate = _stargateByToken[token];
        if (stargate == address(0)) revert ZeroAddress("stargate");

        return stargate;
    }

    /* ======== INTERNAL FUNCTIONS ======== */

    function _sendTokens(
        uint32 _dstEid,
        address _token,
        uint _amountLD,
        bytes memory composeMsg,
        address _receiver
    )
        internal
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        )
    {
        require(
            _stargateByToken[_token] != address(0),
            "StargateAdapter: stargate not set for token."
        );

        address stargate = _stargateByToken[_token];
        ERC20 srcERC20 = ERC20(_token);

        require(
            srcERC20.allowance(msg.sender, address(this)) >= _amountLD,
            "StargateAdapter: Insufficient allowance for bridge."
        );
        srcERC20.safeTransferFrom(msg.sender, address(this), _amountLD);
        srcERC20.forceApprove(stargate, _amountLD);

        (
            uint256 valueToSend,
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = _prepareSendParams(
                stargate,
                _dstEid,
                _amountLD,
                _receiver,
                composeMsg
            );

        require(
            address(this).balance >= valueToSend,
            "StargateAdapter: Insufficient balance for bridge."
        );

        (msgReceipt, oftReceipt) = IStargate(stargate).send{value: valueToSend}(
            sendParam,
            messagingFee,
            _receiver
        );
    }

    function _prepareSendParams(
        address _stargate,
        uint32 _dstEid,
        uint _amountLD,
        address _receiver,
        bytes memory _composeMsg
    )
        internal
        view
        returns (
            uint256 valueToSend,
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        )
    {
        IStargate stargate = IStargate(_stargate);
        bytes memory extraOptions = _composeMsg.length > 0
            ? lzExtraOptions
            : bytes("");

        sendParam = SendParam({
            dstEid: _dstEid,
            to: _addressToBytes32(_receiver),
            amountLD: _amountLD,
            minAmountLD: _amountLD,
            extraOptions: extraOptions,
            composeMsg: _composeMsg,
            oftCmd: ""
        });

        (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        messagingFee = stargate.quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;

        if (stargate.token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function _depositOnSrcChain(
        IMaatVaultV1 _vault,
        uint _amount,
        uint32 _originEid,
        bytes32 _intentionId
    ) internal {
        ERC20 token = ERC20(_vault.asset());
        token.forceApprove(address(_vault), _amount);
        _vault.finishBridge(_amount, _originEid, _intentionId);
    }

    function _getTokenFromStargate(
        address _stargate
    ) internal view returns (address token) {
        token = IStargate(_stargate).token();
    }

    function _getLzEndpointFromStargate(
        address _stargate
    ) internal view returns (address endpoint) {
        endpoint = address(StargateBase(_stargate).endpoint());
    }

    /* ======== VALIDATION ======== */

    function _validateStargatePool(address stargate) internal view {
        if (_getLzEndpointFromStargate(stargate) != lzEndpoint)
            revert AddressIsNotAStargatePool(stargate);
    }

    receive() external payable {}
}
