// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

enum OperationKind {
    AddLiquidityOneSided,
    AddLiquidityTwoSided,
    RemoveLiquidity
}

struct WorkerOperation {
    OperationKind kind;
    bytes data;
}

struct RewardToken {
    /// @notice Stored rewards per bToken for a specific reward token.
    uint256 rewardPerTokenStored;
    /// @notice Rate at which reward tokens are distributed.
    uint256 rewardRate;
    /// @notice Whether or not a reward token is vested.
    bool lockable;
    /// @notice Reward duration for a specific reward token.
    uint32 duration;
    /// @notice Time when rewards for a specific reward token ends.
    uint32 periodFinish;
    /// @notice The last time reward variables updated for a specific reward token.
    uint32 lastUpdateTime;
}

/// @title Base Worker Storage
/// @author Chainvisions
/// @notice Diamond storage contract for Limestone workers.

library BaseWorkerStorage {
    struct Layout {
        /// @notice Address of the next implementation contract.
        address nextImplementation;
        /// @notice Timestamp when the nextImplementation can be set.
        uint32 nextImplementationTimestamp;
        /// @notice Underlying token employed by the strategy.
        IERC20 strategyUnderlying;
        /// @notice Reward pool contract address.
        address rewardPool;
        /// @notice Total amount of shares in the strategy.
        uint256 totalShares;
        /// @notice Shares in the strategy held by a user.
        mapping(uint256 => uint256) sharesOf;
        /// @notice Reward tokens earned by the strategy.
        address[] strategyRewards;
        /// @notice Reward tokens emitted from the contract.
        IERC20[] rewardTokens;
        /// @notice Addresses permitted to distribute rewards.
        mapping(address => bool) rewardDistribution;
        /// @notice Data for reward tokens.
        mapping(IERC20 => RewardToken) rewardTokenData;
        /// @notice The amount of rewards per bToken of a specific reward token paid to the user.
        mapping(IERC20 => mapping(uint256 => uint256)) userRewardPerTokenPaidForToken;
        /// @notice The pending reward tokens for a user.
        mapping(IERC20 => mapping(uint256 => uint256)) rewardsForToken;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("limestone.contracts.storage.lyf.BaseWorker");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
