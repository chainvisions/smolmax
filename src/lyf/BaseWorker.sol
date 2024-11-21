// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Math} from "@solidstate/utils/Math.sol";
import {ReentrancyGuard} from "@solidstate/security/reentrancy_guard/ReentrancyGuard.sol";
import {Initializable} from "@solidstate/security/initializable/Initializable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {ControllableNoInit} from "../libraries//ControllableNoInit.sol";
import {Errors, _require} from "../libraries//Errors.sol";
import {Cast} from "../libraries/Cast.sol";
import {IController} from "../interfaces/IController.sol";
import {Position, ILendingPool} from "../interfaces/ILendingPool.sol";
import {IWarchest} from "../interfaces/IWarchest.sol";
import {IMinter} from "../interfaces/IMinter.sol";
import {IWorker} from "../interfaces/IWorker.sol";
import {IERC20, BaseWorkerStorage, WorkerOperation, OperationKind, RewardToken} from "./BaseWorkerStorage.sol";

/// @title Limestone Base Worker
/// @author Chainvisions
/// @notice Base worker contract for Limestone positions.

abstract contract BaseWorker is ControllableNoInit, Initializable, ReentrancyGuard, IWorker {
    using Cast for uint256;
    using SafeTransferLib for address;

    /// @notice Collateral token contract.
    IERC20 public immutable COLLATERAL;

    /// @notice Underlying token held by the worker strategy.
    IERC20 public immutable STRATEGY_UNDERLYING;

    /// @notice Lending pool contract.
    ILendingPool public immutable LENDING_POOL;

    /// @notice Warchest contract used to store collateral.
    IWarchest public immutable COLLATERAL_WARCHEST;

    /// @notice Limestone token contract.
    IERC20 public immutable LIME_TOKEN;

    /// @notice Limestone minter contract.
    IMinter public immutable MINTER;

    /// @notice Modifier for restricting calls to lending pool.
    modifier onlyLendingPool() {
        _require(msg.sender == address(LENDING_POOL), Errors.CALLER_NOT_LENDING_POOL);
        _;
    }

    /// @notice Prevents smart contracts from interacting if they are not whitelisted.
    /// This system is part of our security model as a method of preventing flashloan exploits.
    modifier defense() {
        _require(msg.sender == tx.origin, Errors.CALLER_NOT_EOA);
        _;
    }

    /// @notice Base Worker constructor.
    /// @param _poolId ID of the worker's lending pool.
    /// @param _collateral Collateral token contract.
    /// @param _lendingPool Lending pool contract.
    /// @param _strategyUnderlying Underlying token of the strategy.
    /// @param _limeToken Limestone token contract.
    /// @param _minter Minter contract.
    constructor(
        uint256 _poolId,
        IERC20 _collateral,
        ILendingPool _lendingPool,
        IERC20 _strategyUnderlying,
        IERC20 _limeToken,
        IMinter _minter
    ) {
        _poolId; // TODO: Fetch warchest
        COLLATERAL = _collateral;
        LENDING_POOL = _lendingPool;
        COLLATERAL_WARCHEST = IWarchest(address(0));
        STRATEGY_UNDERLYING = _strategyUnderlying;
        LIME_TOKEN = _limeToken;
        MINTER = _minter;
    }

    /// @notice Initializes the Worker proxy.
    /// @param _store Storage contract for access control.
    /// @param _rewardPool Reward pool contract used for farming.
    function initialize(address _store, address _rewardPool, address[] memory _strategyRewards) public initializer {
        _setStore(_store);
        BaseWorkerStorage.layout().rewardPool = _rewardPool;
        BaseWorkerStorage.layout().strategyRewards = _strategyRewards;
    }

    /// @notice Work on the given position. Must be called by the operator.
    /// @param _id The position ID to work on.
    /// @param _user The original user that is interacting with the operator.
    /// @param _debt The amount of user debt to help the strategy make decisions.
    /// @param _data The encoded data, consisting of strategy address and calldata.
    function work(uint256 _id, address _user, uint256 _debt, bytes calldata _data) external virtual;

    /// @notice Liquidates a position and converts it back into the underlying collateral.
    /// @param _id ID of the position to liquidate.
    function liquidate(uint256 _id) external virtual;

    /// @notice Collects all earned rewards from the vault for the user.
    /// @param _positionId ID of the position to claim rewards for.
    function getReward(uint256 _positionId) external defense {
        IERC20[] memory rewardTokens = BaseWorkerStorage.layout().rewardTokens;
        _updateRewards(_positionId);
        uint256 nTokens = rewardTokens.length;
        Position memory pos = LENDING_POOL.positions(_positionId);
        for (uint256 i; i < nTokens;) {
            _getReward(_positionId, pos.owner, rewardTokens[i]);
            // forgefmt: disable-next-line
            unchecked { ++i; }
        }
    }

    /// @notice Collects the user's rewards of the specified reward token.
    /// @param _positionId ID of the position to claim rewards for.
    /// @param _rewardToken Reward token to claim.
    function getRewardByToken(uint256 _positionId, IERC20 _rewardToken) external defense {
        _updateReward(_positionId, _rewardToken);
        Position memory pos = LENDING_POOL.positions(_positionId);
        _getReward(_positionId, pos.owner, _rewardToken);
    }

    /// @notice Salvages tokens from the strategy contract. One thing that should be noted
    /// is that the only tokens that are possible to be salvaged from this contract are ones
    /// that are not part of `unsalvagableTokens()`, preventing a malicious owner from stealing tokens.
    /// @param _recipient Recipient of the tokens salvaged.
    /// @param _token Token to salvage.
    /// @param _amount Amount of `_token` to salvage from the strategy.
    function salvage(address _recipient, address _token, uint256 _amount) external onlyGovernance {
        _require(!unsalvagableTokens(_token), Errors.UNSALVAGABLE_TOKEN);
        IERC20(_token).transfer(_recipient, _amount);
    }

    /// @notice Gauges the current health of the worker to ensure no manipulation is happening.
    /// @return Whether or not the underlying pool is healthy and able to accept debt.
    function healthcheck() external view virtual returns (bool);

    /// @notice Calculates the liquidateable amount for a position.
    /// @param _id ID of the position to calculate using.
    /// @return How many tokens can be liquidated from the position.
    function health(uint256 _id) external view virtual returns (uint256);

    /// @notice Determines if the proxy can be upgraded.
    /// @return If an upgrade is possible and the address of the new implementation
    function shouldUpgrade() external view returns (bool, address) {
        address nextImplementation = BaseWorkerStorage.layout().nextImplementation;
        uint256 nextImplementationTimestamp = BaseWorkerStorage.layout().nextImplementationTimestamp;

        return (
            nextImplementationTimestamp != 0 && block.timestamp > nextImplementationTimestamp
                && nextImplementation != address(0),
            nextImplementation
        );
    }

    /// @notice Injects rewards into the vault.
    /// @param _rewardToken Token to reward, must be in the rewardTokens array.
    /// @param _amount Amount of `_rewardToken` to inject.
    function notifyRewardAmount(IERC20 _rewardToken, uint256 _amount) public {
        _require(
            msg.sender == governance() || BaseWorkerStorage.layout().rewardDistribution[msg.sender],
            Errors.CALL_RESTRICTED
        );
        _notifyRewards(_rewardToken, _amount);
    }

    /// @notice Gives the specified address the ability to inject rewards.
    /// @param _rewardDistribution Address to get reward distribution privileges
    function addRewardDistribution(address _rewardDistribution) public onlyGovernance {
        BaseWorkerStorage.layout().rewardDistribution[_rewardDistribution] = true;
    }

    /// @notice Removes the specified address' ability to inject rewards.
    /// @param _rewardDistribution Address to lose reward distribution privileges
    function removeRewardDistribution(address _rewardDistribution) public onlyGovernance {
        BaseWorkerStorage.layout().rewardDistribution[_rewardDistribution] = false;
    }

    /// @notice Adds a reward token to the vault.
    /// @param _rewardToken Reward token to add.
    /// @param _duration Duration for distributing the token.
    /// @param _lockable Whether or not it should be locked when claimed.
    function addRewardToken(IERC20 _rewardToken, uint256 _duration, bool _lockable) public onlyGovernance {
        _require(rewardTokenIndex(_rewardToken) == type(uint256).max, Errors.REWARD_TOKEN_ALREADY_EXIST);
        _require(_duration > 0, Errors.DURATION_CANNOT_BE_ZERO);
        BaseWorkerStorage.layout().rewardTokens.push(_rewardToken);
        RewardToken memory rewardData;
        rewardData.duration = _duration.u32();
        rewardData.lockable = _lockable;
        BaseWorkerStorage.layout().rewardTokenData[_rewardToken] = rewardData;
    }

    /// @notice Removes a reward token from the vault.
    /// @param _rewardToken Reward token to remove from the vault.
    function removeRewardToken(IERC20 _rewardToken) public onlyGovernance {
        IERC20[] storage rewardTokens = BaseWorkerStorage.layout().rewardTokens;
        RewardToken memory rewardData = BaseWorkerStorage.layout().rewardTokenData[_rewardToken];
        uint256 rewardIndex = rewardTokenIndex(_rewardToken);

        _require(rewardIndex != type(uint256).max, Errors.REWARD_TOKEN_DOES_NOT_EXIST);
        _require(rewardData.periodFinish < block.timestamp, Errors.REWARD_PERIOD_HAS_NOT_ENDED);
        _require(rewardTokens.length > 1, Errors.CANNOT_REMOVE_LAST_REWARD_TOKEN);
        uint256 lastIndex = rewardTokens.length - 1;

        rewardTokens[rewardIndex] = rewardTokens[lastIndex];

        delete BaseWorkerStorage.layout().rewardTokenData[_rewardToken];
        rewardTokens.pop();
    }

    /// @notice Sets the reward distribution duration for `_rewardToken`.
    /// @param _rewardToken Reward token to set the duration of.
    function setDurationForToken(IERC20 _rewardToken, uint256 _duration) public onlyGovernance {
        RewardToken memory rewardData = BaseWorkerStorage.layout().rewardTokenData[_rewardToken];
        uint256 i = rewardTokenIndex(_rewardToken);
        _require(i != type(uint256).max, Errors.REWARD_TOKEN_DOES_NOT_EXIST);
        _require(rewardData.periodFinish < block.timestamp, Errors.REWARD_PERIOD_HAS_NOT_ENDED);
        _require(_duration > 0, Errors.DURATION_CANNOT_BE_ZERO);
        rewardData.duration = _duration.u32();
        BaseWorkerStorage.layout().rewardTokenData[_rewardToken] = rewardData;
    }

    /// @notice Harvests and reinvests yields into more tokens.
    function reinvest() external virtual;

    /// @notice Calculates how many tokens `_shares` is worth.
    /// @param _shares The amount of shares to calculate the value of.
    /// @return Token value of `_shares`.
    function shareToBalance(uint256 _shares) public view virtual returns (uint256);

    /// @notice Calculates how many shares an amount of tokens are worth.
    /// @param _balance Token balance to convert into shares.
    /// @return Total amount of shares `_balance` is worth.
    function balanceToShare(uint256 _balance) public view virtual returns (uint256);

    /// @notice Checks whether or not a token can be salvaged from the strategy.
    /// @param _token Token to check for salvagability.
    /// @return Whether or not the token can be salvaged.
    function unsalvagableTokens(address _token) public view virtual returns (bool);

    /// @notice Gets the index of `_rewardToken` in the `rewardTokens` array.
    /// @param _rewardToken Reward token to get the index of.
    /// @return The index of the reward token, it will return the max uint256 if it does not exist.
    function rewardTokenIndex(IERC20 _rewardToken) public view returns (uint256) {
        IERC20[] memory rewardTokens = BaseWorkerStorage.layout().rewardTokens;
        for (uint256 i; i < rewardTokens.length;) {
            if (rewardTokens[i] == _rewardToken) {
                return i;
            }

            // forgefmt: disable-next-line
            unchecked { ++i; }
        }
        return type(uint256).max;
    }

    /// @notice Calculates the last time rewards were applicable for a specific token.
    /// @param _rewardToken Reward token to calculate the time of.
    /// @return The last time rewards were applicable for `_rewardToken`.
    function lastTimeRewardApplicable(IERC20 _rewardToken) public view returns (uint256) {
        return Math.min(block.timestamp, BaseWorkerStorage.layout().rewardTokenData[IERC20(_rewardToken)].periodFinish);
    }

    /// @notice Gets the amount of rewards per bToken for a specified reward token.
    /// @param _rewardToken Reward token to get the amount of rewards for.
    /// @return Amount of `_rewardToken` per bToken.
    function rewardPerToken(IERC20 _rewardToken) public view returns (uint256) {
        uint256 _totalShares = BaseWorkerStorage.layout().totalShares;
        RewardToken memory rewardData = BaseWorkerStorage.layout().rewardTokenData[IERC20(_rewardToken)];
        if (_totalShares == 0) {
            return rewardData.rewardPerTokenStored;
        }
        return (
            rewardData.rewardPerTokenStored
                + (
                    (((lastTimeRewardApplicable(_rewardToken) - rewardData.lastUpdateTime) * rewardData.rewardRate) * 1e18)
                        / _totalShares
                )
        );
    }

    /// @notice Gets the user's earnings by reward token address.
    /// @param _rewardToken Reward token to get earnings from.
    /// @param _positionId ID of the position to get the earnings of.
    function earned(IERC20 _rewardToken, uint256 _positionId) public view returns (uint256) {
        return (
            (
                BaseWorkerStorage.layout().sharesOf[_positionId]
                    * (
                        rewardPerToken(_rewardToken)
                            - BaseWorkerStorage.layout().userRewardPerTokenPaidForToken[_rewardToken][_positionId]
                    )
            ) / 1e18
        ) + BaseWorkerStorage.layout().rewardsForToken[_rewardToken][_positionId];
    }

    function _finalizeUpgrade() internal {
        BaseWorkerStorage.layout().nextImplementation = address(0);
        BaseWorkerStorage.layout().nextImplementationTimestamp = 0;
    }

    /// @notice Collects protocol fees and sends them to the Controller.
    /// @param _reward Reward token to collect fees from.
    /// @param _rewardBalance The amount of rewards generated that is to have fees taken from.
    function _notifyProfitInRewardToken(IERC20 _reward, uint256 _rewardBalance) internal {
        // Avoid additional SLOAD costs by reading the Controller from memory.
        IController _controller = IController(controller());

        if (_rewardBalance > 0) {
            uint256 feeAmount =
                (_rewardBalance * _controller.profitSharingNumerator()) / _controller.profitSharingDenominator();
            address(_reward).safeApprove(address(MINTER), 0);
            address(_reward).safeApprove(address(MINTER), feeAmount);

            uint256 toMint = MINTER.realizeProfit(address(_reward), feeAmount);
            _notifyRewards(LIME_TOKEN, toMint);
        }
    }

    function _liquidateReward() internal {
        address[] memory rewards = BaseWorkerStorage.layout().strategyRewards;
        uint256 nIndices = rewards.length;
        uint256[] memory rewardBalances = new uint256[](nIndices);
        for (uint256 i; i < nIndices;) {
            IERC20 reward = IERC20(rewards[i]);
            uint256 rewardBalance = reward.balanceOf(address(this));

            // Check if the reward is enough for liquidation.
            if (rewardBalance < 1e2) {
                return;
            }

            // Notify performance fees.
            _notifyProfitInRewardToken(reward, rewardBalance);

            // Push the balance after notifying fees.
            rewardBalances[i] = reward.balanceOf(address(this));

            // forgefmt: disable-next-line
            unchecked { ++i; }
        }

        _handleLiquidation(rewardBalances);
    }

    function _handleLiquidation(uint256[] memory _balances) internal virtual;

    function _notifyRewards(IERC20 _rewardToken, uint256 _amount) internal {
        _updateRewards(0);
        _require(_amount < type(uint256).max / 1e18, Errors.NOTIF_AMOUNT_INVOKES_OVERFLOW);

        RewardToken memory rewardData = BaseWorkerStorage.layout().rewardTokenData[_rewardToken];

        uint256 i = rewardTokenIndex(_rewardToken);
        _require(i != type(uint256).max, Errors.REWARD_INDICE_NOT_FOUND);

        if (block.timestamp >= rewardData.periodFinish) {
            rewardData.rewardRate = _amount / rewardData.duration;
        } else {
            uint256 remaining = rewardData.periodFinish - block.timestamp;
            uint256 leftover = (remaining * rewardData.rewardRate);
            rewardData.rewardRate = (_amount + leftover) / rewardData.duration;
        }
        rewardData.lastUpdateTime = block.timestamp.u32();
        rewardData.periodFinish = block.timestamp.u32() + rewardData.duration;
    }

    function _updateRewards(uint256 _positionId) internal {
        IERC20[] memory rewardTokens = BaseWorkerStorage.layout().rewardTokens;
        for (uint256 i; i < rewardTokens.length;) {
            IERC20 rewardToken = rewardTokens[i];
            RewardToken memory rewardData = BaseWorkerStorage.layout().rewardTokenData[rewardToken];
            rewardData.rewardPerTokenStored = rewardPerToken(rewardToken);
            rewardData.lastUpdateTime = lastTimeRewardApplicable(rewardToken).u32();
            if (_positionId != 0) {
                BaseWorkerStorage.layout().rewardsForToken[rewardToken][_positionId] = earned(rewardToken, _positionId);
                BaseWorkerStorage.layout().userRewardPerTokenPaidForToken[rewardToken][_positionId] =
                    rewardData.rewardPerTokenStored;
            }

            // Vital: Update storage data. Not doing this causes a possible exploit.
            BaseWorkerStorage.layout().rewardTokenData[rewardToken] = rewardData;
            // forgefmt: disable-next-line
            unchecked { ++i; }
        }
    }

    function _updateReward(uint256 _positionId, IERC20 _rewardToken) internal {
        RewardToken memory rewardData = BaseWorkerStorage.layout().rewardTokenData[_rewardToken];
        rewardData.rewardPerTokenStored = rewardPerToken(_rewardToken);
        rewardData.lastUpdateTime = lastTimeRewardApplicable(_rewardToken).u32();
        if (_positionId != 0) {
            BaseWorkerStorage.layout().rewardsForToken[_rewardToken][_positionId] = earned(_rewardToken, _positionId);
            BaseWorkerStorage.layout().userRewardPerTokenPaidForToken[_rewardToken][_positionId] =
                rewardData.rewardPerTokenStored;
        }

        // Vital: Update storage data. Not doing this causes a possible exploit.
        BaseWorkerStorage.layout().rewardTokenData[_rewardToken] = rewardData;
    }

    function _getReward(uint256 _positionId, address _positionOwner, IERC20 _rewardToken) internal {
        uint256 rewards = earned(_rewardToken, _positionId);
        if (rewards > 0) {
            BaseWorkerStorage.layout().rewardsForToken[_rewardToken][_positionId] = 0;
            if (BaseWorkerStorage.layout().rewardTokenData[_rewardToken].lockable) {
                IController(controller()).mintTokens(_positionOwner, rewards);
            } else {
                address(_rewardToken).safeTransfer(_positionOwner, rewards);
            }
            emit RewardPaid(_positionOwner, address(_rewardToken), rewards);
        }
    }
}
