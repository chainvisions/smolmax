// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Metadata} from "@solidstate/token/ERC20/metadata/IERC20Metadata.sol";
import {ISolidlyRouter01} from "../../interfaces/swaps/ISolidlyRouter01.sol";
import {ISolidlyV1Factory} from "../../interfaces/swaps/ISolidlyV1Factory.sol";
import {IUniswapV2Pair} from "../../interfaces/swaps/IUniswapV2Pair.sol";
import {ILimestoneOracle} from "../../interfaces/ILimestoneOracle.sol";
import {SwapUtils} from "../../libraries/SwapUtils.sol";
import {
    BaseWorker,
    BaseWorkerStorage,
    WorkerOperation,
    OperationKind,
    IERC20,
    ILendingPool,
    IMinter,
    Math,
    Errors,
    _require,
    SafeTransferLib
} from "../BaseWorker.sol";
import {IRamsesLegacyGauge} from "./interfaces/IRamsesLegacyGauge.sol";

/// @title Kingdom Worker Contract.
/// @author Chainvisions
/// @notice Limestone worker for Kingdom Legacy LPs.

contract KingdomWorker is BaseWorker {
    using SafeTransferLib for IERC20;

    // Structure for pairs, used to evade stack too deep errors. (-_-)
    struct Pair {
        address token0;
        address token1;
        uint256 toToken0;
        uint256 toToken1;
    }

    // Structure for storing token liquidation routes.
    struct SwapConfiguration {
        bool swapLess;
        bool singlePair;
        bool stableswap;
    }

    /// @notice Whether or not the underlying LP is a stableswap pool.
    bool public immutable STABLE;

    /// @notice Router contract for Solidly.
    ISolidlyRouter01 public immutable SOLIDLY_ROUTER = ISolidlyRouter01(0xAAA45c8F5ef92a000a121d102F4e89278a711Faa);

    /// @notice Configuration for a specific Solidly swap.
    mapping(address => mapping(address => SwapConfiguration)) public swapConfig;

    /// @notice Routes for liquidation on Solidly.
    mapping(address => mapping(address => ISolidlyRouter01.Route[])) public routes;

    /// @notice Worker constructor.
    /// @param _poolId ID of the associated lending pool.
    /// @param _collateral Collateral token contract.
    /// @param _lendingPool Lending pool contract.
    /// @param _strategyUnderlying Underlying token of the strategy.
    /// @param _limeToken Limestone token contract.
    /// @param _minter Minter contract.
    /// @param _stable Whether or not the pool is a stableswap pool.
    /// @param _router Kingdom router contract.
    constructor(
        uint256 _poolId,
        IERC20 _collateral,
        ILendingPool _lendingPool,
        IERC20 _strategyUnderlying,
        IERC20 _limeToken,
        IMinter _minter,
        bool _stable,
        address _router,
        address _kingdomToken
    ) BaseWorker(_poolId, _collateral, _lendingPool, _strategyUnderlying, _limeToken, _minter) {
        STABLE = _stable;
        SOLIDLY_ROUTER = _router;
    }

    /// @notice Initializes the worker contract.
    /// @param _storage Storage contract for access control.
    /// @param _rewardPool Reward pool contract.
    /// @param _rewards Reward tokens farmed by the worker.
    function __Strategy_init(address _storage, address _rewardPool, address[] memory _rewards) public initializer {
        BaseWorker.initialize(_storage, _rewardPool, _rewards);
        STRATEGY_UNDERLYING.safeApprove(address(_rewardPool), type(uint256).max);
    }

    /// @notice Work on the given position. Must be called by the operator.
    /// @param _id The position ID to work on.
    /// @param _user The original user that is interacting with the operator.
    /// @param _debt The amount of user debt to help the strategy make decisions.
    /// @param _data The encoded data, consisting of strategy address and calldata.
    function work(uint256 _id, address _user, uint256 _debt, bytes calldata _data)
        external
        override
        onlyLendingPool
        nonReentrant
    {
        uint256 removed = _removeShare(_id);
        (WorkerOperation op) = abi.decode(_data, (WorkerOperation));
        if (op.kind == OperationKind.AddLiquidityOneSided) {
            (uint256 minLiquidity) = abi.decode(op.data, (uint256));
            _addLiquidityOneSided(minLiquidity);
        } else if (op.kind == OperationKind.AddLiquidityTwoSided) {
            (uint256 otherIn, uint256 minLiquidity) = abi.decode(op.data, (uint256, uint256));
            _addLiquidityTwoSided(otherIn, minLiquidity);
        } else if (op.kind == OperationKind.RemoveLiquidity) {
            _removeLiquidity(removed, _user, _debt);
        } else {
            revert();
        }
        _addShare(_id);
        COLLATERAL.safeTransfer(address(COLLATERAL_WARCHEST), COLLATERAL.balanceOf(address(this)));
    }

    /// @notice Liquidates a position and converts it back into the underlying collateral.
    /// @param _id ID of the position to liquidate.
    function liquidate(uint256 _id) external override onlyLendingPool nonReentrant {
        uint256 balance = _removeShare(_id);
        address token0 = IUniswapV2Pair(address(STRATEGY_UNDERLYING)).token0();
        address token1 = IUniswapV2Pair(address(STRATEGY_UNDERLYING)).token1();

        IERC20(token0).safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        IERC20(token1).safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        STRATEGY_UNDERLYING.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);

        // Break LP tokens.
        (uint256 amountA, uint256 amountB) =
            SOLIDLY_ROUTER.removeLiquidity(token0, token1, STABLE, balance, 0, 0, address(this), block.timestamp);

        // Convert LP amounts into `COLLATERAL`.
        SwapConfiguration memory token0Route = swapConfig[token0][address(COLLATERAL)];
        SwapConfiguration memory token1Route = swapConfig[token0][address(COLLATERAL)];
        if (!token0Route.swapLess) {
            if (token0Route.singlePair) {
                SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
                    amountA, 0, token0, address(COLLATERAL), token0Route.stableswap, address(this), block.timestamp
                );
            } else {
                SOLIDLY_ROUTER.swapExactTokensForTokens(
                    amountA, 0, routes[token0][address(COLLATERAL)], address(this), block.timestamp
                );
            }
        }

        if (!token1Route.swapLess) {
            if (token1Route.singlePair) {
                SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
                    amountB, 0, token1, address(COLLATERAL), token1Route.stableswap, address(this), block.timestamp
                );
            } else {
                SOLIDLY_ROUTER.swapExactTokensForTokens(
                    amountB, 0, routes[token1][address(COLLATERAL)], address(this), block.timestamp
                );
            }
        }

        IERC20(token0).safeApprove(address(SOLIDLY_ROUTER), 0);
        IERC20(token1).safeApprove(address(SOLIDLY_ROUTER), 0);
        STRATEGY_UNDERLYING.safeApprove(address(SOLIDLY_ROUTER), 0);

        // Send gained collateral to the Warchest.
        uint256 liquidated = COLLATERAL.balanceOf(address(this));
        COLLATERAL.safeTransfer(address(COLLATERAL_WARCHEST), liquidated);
        emit Liquidate(_id, liquidated);
    }

    /// @notice Harvests and reinvests yields into more tokens.
    function reinvest() external override defense nonReentrant {
        IRamsesLegacyGauge(BaseWorkerStorage.layout().rewardPool).getReward(
            address(this), BaseWorkerStorage.layout().strategyRewards
        );
        _liquidateReward();
        _investAllUnderlying();
    }

    /// @notice Gauges the current health of the worker to ensure no manipulation is happening.
    /// @return Whether or not the underlying pool is healthy and able to accept debt.
    function healthcheck() external view override returns (bool) {
        (address token0, address token1) = IUniswapV2Pair(STRATEGY_UNDERLYING).tokens();
        (uint8 token0Decimals, uint8 token1Decimals) = (IERC20Metadata(token0).decimals(), IERC20Metadata(token1).decimals());
        (uint256 oraclePrice, uint32 oracleUpdatedAt) = ILimestoneOracle(address(LENDING_POOL)).getPriceForToken(token0, token1);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(address(STRATEGY_UNDERLYING)).getReserves();
        _require((token0.balanceOf(address(STRATEGY_UNDERLYING)) * 100) <= (reserve0 * 101), Errors.TOKEN_0_POTENTIAL_MANIPULATION);
        _require((token1.balanceOf(address(STRATEGY_UNDERLYING)) * 100) <= (reserve1 * 101), Errors.TOKEN_1_POTENTIAL_MANIPULATION);
        _require(
            oracleUpdatedAt >= block.timestamp - 1 days,
            Errors.ORACLE_PRICE_STALE
        );
        uint256 spotPrice = ((((reserve1 * 1e18) * (10 ** (18 - token1Decimals))) / reserve0) / (10 ** (18 - token0Decimals));
        _require(spotPrice * 10000 <= oraclePrice * 50500, Errors.SPOT_TOO_HIGH); // TODO: Max diff.
        _require(spotPrice * 60606060 >= oraclePrice * 10000, Errors.SPOT_TOO_LOW); // TODO: Max diff.

        return true;
    }

    /// @notice Calculates the liquidateable amount for a position.
    /// @param _id ID of the position to calculate using.
    /// @return How many tokens can be liquidated from the position.
    function health(uint256 _id) external view override returns (uint256) {
        IUniswapV2Pair _underlying = IUniswapV2Pair(address(STRATEGY_UNDERLYING));
        IERC20 token0 = IERC20(_underlying.token0());
        IERC20 token1 = IERC20(_underlying.token1());

        uint256 userLiquidity = shareToBalance(BaseWorkerStorage.layout().sharesOf[_id]);
        uint256 totalLiquidity = _underlying.totalSupply();
        uint256 reserve0 = _underlying.reserve0();
        uint256 reserve1 = _underlying.reserve1();

        uint256 userCollatValue = (userLiquidity * (token0 == COLLATERAL ? reserve0 : reserve1)) / totalLiquidity;
        uint256 userAlternateValue = (userLiquidity * (token0 == COLLATERAL ? reserve1 : reserve0)) / totalLiquidity;

        uint256 output =
            _underlying.getAmountOut(userAlternateValue, COLLATERAL == token0 ? address(token1) : address(token0));
        return output + userCollatValue;
    }

    /// @notice Calculates how many tokens `_shares` is worth.
    /// @param _shares The amount of shares to calculate the value of.
    /// @return Token value of `_shares`.
    function shareToBalance(uint256 _shares) public view override returns (uint256) {
        uint256 _totalShares = BaseWorkerStorage.layout().totalShares;
        if (_totalShares == 0) return _shares;
        uint256 staked = IRamsesLegacyGauge(BaseWorkerStorage.layout().rewardPool).balanceOf(address(this));
        return (_shares * staked) / _totalShares;
    }

    /// @notice Calculates how many shares an amount of tokens are worth.
    /// @param _balance Token balance to convert into shares.
    /// @return Total amount of shares `_balance` is worth.
    function balanceToShare(uint256 _balance) public view override returns (uint256) {
        uint256 _totalShares = BaseWorkerStorage.layout().totalShares;
        if (_totalShares == 0) return _balance;
        uint256 staked = IRamsesLegacyGauge(BaseWorkerStorage.layout().rewardPool).balanceOf(address(this));
        return (_balance * _totalShares) / staked;
    }

    /// @notice Checks whether or not a token can be salvaged from the strategy.
    /// @param _token Token to check for salvagability.
    /// @return Whether or not the token can be salvaged.
    function unsalvagableTokens(address _token) public pure override returns (bool) {
        return (_token == address(0)); // The contract shouldn't store any toknes.
    }

    function _investAllUnderlying() internal {
        IRamsesLegacyGauge stakingRewards = IRamsesLegacyGauge(BaseWorkerStorage.layout().rewardPool);
        uint256 underlyingBalance = STRATEGY_UNDERLYING.balanceOf(address(this));
        if (underlyingBalance > 0) {
            STRATEGY_UNDERLYING.safeApprove(address(stakingRewards), 0);
            STRATEGY_UNDERLYING.safeApprove(address(stakingRewards), underlyingBalance);
            stakingRewards.deposit(underlyingBalance, 0);
        }
    }

    function _handleLiquidation(uint256[] memory _balances) internal override {
        Pair memory pair = Pair(
            IUniswapV2Pair(address(STRATEGY_UNDERLYING)).token0(),
            IUniswapV2Pair(address(STRATEGY_UNDERLYING)).token1(),
            1,
            1
        );

        address[] memory rewards = BaseWorkerStorage.layout().strategyRewards;
        for (uint256 i; i < rewards.length;) {
            address reward = rewards[i];

            // Collect locking fee.
            uint256 rewardBalance = _balances[i];

            pair.toToken0 = rewardBalance / 2;
            pair.toToken1 = rewardBalance - pair.toToken0;

            uint256 token0Amount;
            uint256 token1Amount;

            SwapConfiguration memory token0Route = swapConfig[reward][pair.token0];
            SwapConfiguration memory token1Route = swapConfig[reward][pair.token1];

            IERC20(reward).safeApprove(address(SOLIDLY_ROUTER), 0);
            IERC20(reward).safeApprove(address(SOLIDLY_ROUTER), rewardBalance);

            if (!token0Route.swapLess) {
                if (token0Route.singlePair) {
                    uint256[] memory amounts = SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
                        pair.toToken0,
                        0,
                        reward,
                        pair.token0,
                        token0Route.stableswap,
                        address(this),
                        block.timestamp + 600
                    );
                    token0Amount = amounts[amounts.length - 1];
                } else {
                    uint256[] memory amounts = SOLIDLY_ROUTER.swapExactTokensForTokens(
                        pair.toToken0, 0, routes[reward][pair.token0], address(this), block.timestamp + 600
                    );
                    token0Amount = amounts[amounts.length - 1];
                }
            } else {
                token0Amount = pair.toToken0;
            }

            if (!token1Route.swapLess) {
                if (token1Route.singlePair) {
                    uint256[] memory amounts = SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
                        pair.toToken1,
                        0,
                        reward,
                        pair.token1,
                        token1Route.stableswap,
                        address(this),
                        block.timestamp + 600
                    );
                    token1Amount = amounts[amounts.length - 1];
                } else {
                    uint256[] memory amounts = SOLIDLY_ROUTER.swapExactTokensForTokens(
                        pair.toToken1, 0, routes[reward][pair.token1], address(this), block.timestamp + 600
                    );
                    token1Amount = amounts[amounts.length - 1];
                }
            } else {
                token1Amount = pair.toToken1;
            }

            IERC20(pair.token0).safeApprove(address(SOLIDLY_ROUTER), 0);
            IERC20(pair.token0).safeApprove(address(SOLIDLY_ROUTER), token0Amount);

            IERC20(pair.token1).safeApprove(address(SOLIDLY_ROUTER), 0);
            IERC20(pair.token1).safeApprove(address(SOLIDLY_ROUTER), token1Amount);

            SOLIDLY_ROUTER.addLiquidity(
                pair.token0, pair.token1, STABLE, token0Amount, token1Amount, 0, 0, address(this), block.timestamp + 600
            );

            // Clean up allowances.
            if (reward != pair.token0 && reward != pair.token1) reward.safeApprove(address(SOLIDLY_ROUTER), 0);
            pair.token0.safeApprove(address(SOLIDLY_ROUTER), 0);
            pair.token1.safeApprove(address(SOLIDLY_ROUTER), 0);

            // forgefmt: disable-next-line
            unchecked { ++i; }
        }
    }

    function _addShare(uint256 _id) internal {
        _updateRewards(_id);
        uint256 balance = STRATEGY_UNDERLYING.balanceOf(address(this));
        if (balance > 0) {
            uint256 share = balanceToShare(balance);
            IRamsesLegacyGauge(BaseWorkerStorage.layout().rewardPool).deposit(0, balance);
            BaseWorkerStorage.layout().sharesOf[_id] = (BaseWorkerStorage.layout().sharesOf[_id] + share);
            BaseWorkerStorage.layout().totalShares = (BaseWorkerStorage.layout().totalShares + share);
            emit AddShare(_id, share);
        }
    }

    function _removeShare(uint256 _id) internal returns (uint256 balance) {
        _updateRewards(_id);
        uint256 share = BaseWorkerStorage.layout().sharesOf[_id];
        if (share > 0) {
            balance = shareToBalance(share);
            IRamsesLegacyGauge(BaseWorkerStorage.layout().rewardPool).withdraw(balance);
            BaseWorkerStorage.layout().totalShares = (BaseWorkerStorage.layout().totalShares - share);
            BaseWorkerStorage.layout().sharesOf[_id] = 0;
            emit RemoveShare(_id, share);
        }
    }

    function _addLiquidityOneSided(uint256 _minLiquidity) internal returns (uint256) {
        IUniswapV2Pair _underlying = IUniswapV2Pair(address(STRATEGY_UNDERLYING));
        IERC20 token0 = IERC20(_underlying.token0());
        IERC20 token1 = IERC20(_underlying.token1());
        uint256 reserve0 = _underlying.reserve0();
        uint256 reserve1 = _underlying.reserve1();
        uint256 collatHeld = COLLATERAL.balanceOf(address(this));

        token0.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        token1.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);

        uint256 cRes = token0 == COLLATERAL ? reserve0 : reserve1;
        uint256 optimalSwapAmount =
            SwapUtils._optimalAmountIn(ISolidlyV1Factory(SOLIDLY_ROUTER.factory()).getFee(), cRes, collatHeld);
        uint256[] memory amounts = SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
            optimalSwapAmount,
            0,
            address(COLLATERAL),
            token0 == COLLATERAL ? address(token1) : address(token0),
            STABLE,
            address(this),
            block.timestamp
        );

        // We reuse these variables to save on stack usage.
        reserve0 = token0 == COLLATERAL ? collatHeld - optimalSwapAmount : amounts[amounts.length - 1];
        reserve1 = token1 == COLLATERAL ? collatHeld - optimalSwapAmount : amounts[amounts.length - 1];

        uint256 minted = SOLIDLY_ROUTER.addLiquidity(
            address(token0), address(token1), STABLE, reserve0, reserve1, 0, 0, address(this), block.timestamp
        );
        require(minted >= _minLiquidity, "FUCKING SLIPPAGE DAWG!!!!"); // TODO: Create an actual error for this.
        token0.safeApprove(address(SOLIDLY_ROUTER), 0);
        token1.safeApprove(address(SOLIDLY_ROUTER), 0);
        return minted;
    }

    function _addLiquidityTwoSided(uint256 _otherIn, uint256 _minLiquidity) internal {
        IUniswapV2Pair _underlying = IUniswapV2Pair(address(STRATEGY_UNDERLYING));
        IERC20 token0 = IERC20(_underlying.token0());
        IERC20 token1 = IERC20(_underlying.token1());
        uint256 reserve0 = _underlying.reserve0();
        uint256 reserve1 = _underlying.reserve1();
        uint256 collatHeld = COLLATERAL.balanceOf(address(this));

        token0.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        token1.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);

        (uint256 cRes, uint256 oRes) = token0 == COLLATERAL ? (reserve0, reserve1) : (reserve1, reserve0);
        (uint256 toSwap, bool reversed) = SwapUtils._optimalZapAmountIn(collatHeld, _otherIn, cRes, oRes);
        if (toSwap > 0) {
            address otherToken = token0 == COLLATERAL ? token1 : token0;
            SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
                toSwap,
                0,
                reversed ? otherToken : COLLATERAL,
                reversed ? COLLATERAL : otherToken,
                STABLE,
                address(this),
                block.timestamp
            );
        }

        uint256 minted = SOLIDLY_ROUTER.addLiquidity(
            address(token0),
            address(token1),
            STABLE,
            token0.balanceOf(),
            token1.balanceOf(),
            0,
            0,
            address(this),
            block.timestamp
        );
        require(minted >= _minLiquidity, "FUFUCUCKC SLIPPAGE!!!!"); // TODO: Create an actual error for this.

        token0.safeApprove(address(SOLIDLY_ROUTER), 0);
        token1.safeApprove(address(SOLIDLY_ROUTER), 0);
    }

    function _removeLiquidity(uint256 _toRemove, address _user, uint256 _debt) internal {
        address token0 = IUniswapV2Pair(address(STRATEGY_UNDERLYING)).token0();
        address token1 = IUniswapV2Pair(address(STRATEGY_UNDERLYING)).token1();

        // Create allowances.
        token0.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        token1.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        STRATEGY_UNDERLYING.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);

        // Break LP tokens.
        (uint256 amountA, uint256 amountB) =
            SOLIDLY_ROUTER.removeLiquidity(token0, token1, STABLE, _toRemove, 0, 0, address(this), block.timestamp);

        // Convert LP amounts into `COLLATERAL`.
        SwapConfiguration memory token0Route = swapConfig[token0][address(COLLATERAL)];
        SwapConfiguration memory token1Route = swapConfig[token0][address(COLLATERAL)];
        if (!token0Route.swapLess) {
            if (token0Route.singlePair) {
                SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
                    amountA, 0, token0, address(COLLATERAL), token0Route.stableswap, address(this), block.timestamp
                );
            } else {
                SOLIDLY_ROUTER.swapExactTokensForTokens(
                    amountA, 0, routes[token0][address(COLLATERAL)], address(this), block.timestamp
                );
            }
        }

        if (!token1Route.swapLess) {
            if (token1Route.singlePair) {
                SOLIDLY_ROUTER.swapExactTokensForTokensSimple(
                    amountB, 0, token1, address(COLLATERAL), token1Route.stableswap, address(this), block.timestamp
                );
            } else {
                SOLIDLY_ROUTER.swapExactTokensForTokens(
                    amountB, 0, routes[token1][address(COLLATERAL)], address(this), block.timestamp
                );
            }
        }

        // Transfer collateral to the user and clear allowances.
        COLLATERAL.safeTransfer(_user, (COLLATERAL.balanceOf(address(this)) - _debt));
        token0.safeApprove(address(SOLIDLY_ROUTER), 0);
        token1.safeApprove(address(SOLIDLY_ROUTER), 0);
        STRATEGY_UNDERLYING.safeApprove(address(SOLIDLY_ROUTER), 0);
    }
}