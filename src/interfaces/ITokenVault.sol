// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
// import {ITokenVault} from "lib/maat-v1-core/src/interfaces/ITokenVault.sol";

//TODO change to Import from submodule

interface IMaatVaultV1 is IERC4626 {
    event DepositedInStrategy(
        bytes32 strategyId,
        address asset,
        uint256 amount,
        bytes32 indexed intentionId
    );

    event WithdrewFromStrategy(
        bytes32 strategyId,
        address asset,
        uint256 amount,
        bytes32 indexed intentionId
    );

    event Bridged(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes32 indexed intentionId
    );

    event BridgeFinished(uint amount, bytes32 intentionId);

    event WithdrawalRequested(
        address token,
        uint256 shares,
        address owner,
        bytes32 indexed intentionId,
        uint32 dstEid
    );

    event RebalanceRequested(bytes32 intentionId);

    event WithdrawRequestFulfilled(
        address token,
        uint256 assets,
        address owner,
        address receiver,
        bytes32 indexed intentionId
    );

    event WithdrawRequestCancelled(bytes32 indexed intentionId);

    event StrategyAdded(bytes32 strategyId);
    event StrategyRemoved(bytes32 strategyId);
    event StrategyToggled(bytes32 strategyId, bool isActive);

    ///@dev Used to Deposit/Withdraw from strategy, Bridge assets between Vault, Fulfill Requests
    enum ActionType {
        DEPOSIT,
        WITHDRAW,
        BRIDGE,
        FULFILL_WITHDRAW_REQUEST
    }

    enum RequestType {
        WITHDRAW,
        REBALANCE
    }

    ///@notice Not all fields are required for all actions
    struct ActionInput {
        uint32 dstEid;
        bytes32 strategyId;
        uint256 amount;
        bytes32 intentionId;
    }

    struct WithdrawRequestInfo {
        address owner;
        address receiver;
        address token;
        uint32 dstEid;
        uint32 creationTime;
        uint256 shares;
    }

    struct RebalanceRequestInfo {
        uint32 lastRebalanceTime;
        bytes32 intentionId;
    }

    struct Strategy {
        address strategyAddress;
        bool isActive;
    }

    function deposit(uint _assets, address _receiver) external returns (uint);

    function requestWithdraw(
        uint shares,
        uint32 dstEid,
        address receiver,
        address owner
    ) external returns (bytes32);

    function requestRebalance() external returns (bytes32 intentionId);

    function execute(
        ActionType[] calldata actionType,
        ActionInput[] calldata inputs
    ) external returns (bool);

    function finishBridge(uint256 amountBridged, bytes32 intentionId) external;

    function getSupportedDstEidToWithdraw(
        uint32 _dstEid
    ) external view returns (bool);

    function getWithdrawRequest(
        bytes32 intentionId
    ) external view returns (WithdrawRequestInfo memory);

    function getStrategyById(
        bytes32 _strategyId
    ) external view returns (address, bool);

    function getStrategyByAddress(
        address _strategy
    ) external view returns (bytes32, bool);

    /// @notice Adds a new strategy to the list of valid strategies in the contract.
    /// @dev This function requires that the caller is an administrator or has appropriate access rights.
    function addStrategy(address strategy) external;

    /// @notice Delete a strategy from the list of valid strategies in the contract.
    /// @dev Requires that the caller is an administrator or has appropriate access rights.
    function removeStrategy(bytes32 _strategyId) external;

    ///@notice Deactivate a strategy in the contract. Deactivated strategies will not be able to perform any actions.
    function disableStrategy(bytes32 _strategyId) external;

    ///@notice Turn on a strategy
    function enableStrategy(bytes32 _strategyId) external;

    ///@notice Set the global PPS oracle address for the contract.
    ///@dev Requires that the caller is an administrator or has appropriate access rights.
    function setOracle(address _oracle) external;

    function setStargateAdapter(address _stargateAdapter) external;

    function setCommander(address _commander) external;

    function setMinAmount(uint amount) external;

    function addChainToWithdraw(uint32 _dstEid) external;

    function removeChainToWithdraw(uint32 _dstEid) external;
}
