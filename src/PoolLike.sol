// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SolidStateERC20} from "@solidstate-contracts/token/ERC20/SolidStateERC20.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {_require, Errors} from "./libraries/Errors.sol";
import {PoolLikeStorage} from "./PoolLikeStorage.sol";

/// @title Pool-Like
/// @author Chainvisions
/// @notice A contract used as a base for barebones, exchange rate based pools.

contract PoolLike is SolidStateERC20, ReentrancyGuard {
    using SafeTransferLib for address;

    /// @notice Enum for differentiating mutations.
    enum MutationKind {
        Inflow,
        Outflow
    }

    /// @notice Factory contract. Used mostly for access control.
    address public immutable FACTORY;

    /// @notice Emitted when new pool tokens are minted.
    /// @param sender Caller of the mint method. Typically periphery.
    /// @param minter Address receiving the newly minted tokens.
    /// @param mintAmount Amount of `underlying` tokens deposited to mint.
    /// @param mintTokens Amount of pool tokens minted.
    event Mint(
        address indexed sender,
        address indexed minter,
        uint256 mintAmount,
        uint256 mintTokens
    );

    /// @notice Emitted when pool tokens are redeemed for `underlying`.
    /// @param sender Caller of the redeem method. Typically periphery.
    /// @param redeemer Address receiving the newly redempt tokens.
    /// @param redeemAmount Amount of `underlying` tokens redeemed.
    /// @param redeemTokens Amount of pool tokens burnt on the redemption.
    event Redeem(
        address indexed sender,
        address indexed redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    );

    /// @notice Emitted when reserves are synced with the pool.
    /// @param newBalance Latest balance of the pool post-sync.
    event Sync(uint256 newBalance);

    /// @notice PoolLike Constructor.
    /// @param _factory Factory contract address.
    constructor(address _factory) {
        FACTORY = _factory;
    }

    /// @notice Main entrypoint for investment/divestment actions on the pool contract.
    /// @dev This is a low level method that should be called via periphery contracts.
    /// @param _kind Type of action to perform. Inflow is used for deposits, while Outflow is used for redeems.
    /// @param _recv Address receiving the output assets as a result of the mutation.
    /// @return output Depending on the mutation, this may either be the amount of tokens minted, or the value tokens were redeemed for.
    function mutate(
        MutationKind _kind,
        address _recv
    ) external nonReentrant returns (uint256 output) {
        PoolLikeStorage.Layout storage l = PoolLikeStorage.layout();
        if (_kind == MutationKind.Inflow) {
            // Mint new pool tokens.
            uint256 totalHeld = IERC20(l.underlying).balanceOf(address(this));
            uint256 mintable = totalHeld - l.totalBalance;
            output = (mintable * 1e18) / exchangeRate();

            if (_totalSupply() == 0) {
                // Reserve the minimum amount of liquidity required.
                output = output - PoolLikeStorage.MINIMUM_LIQUIDITY;
                _mint(address(0), PoolLikeStorage.MINIMUM_LIQUIDITY);
            }
            _require(output > 0, Errors.MINT_AMOUNT_ZERO);
            _mint(_recv, output);
            emit Mint(msg.sender, _recv, mintable, output);
        } else {
            // Redeem the pool tokens.
            uint256 toRedeem = _balanceOf(address(this));
            output = (toRedeem * exchangeRate()) / 1e18;

            _require(toRedeem > 0, Errors.REDEEM_AMOUNT_ZERO);
            _require(toRedeem <= l.totalBalance, Errors.INSUFFICIENT_CASH);
            _burn(address(this), toRedeem);
            emit Redeem(msg.sender, _recv, output, toRedeem);
        }
        _update();
    }

    /// @notice Mints new pool shares from the current balance.
    /// @dev This is a low level method that should be called via periphery contracts.
    /// @param _minter Address receiving the newly minted pool tokens.
    /// @return mintTokens Total amount of tokens minted.
    function mint(
        address _minter
    ) external nonReentrant returns (uint256 mintTokens) {
        PoolLikeStorage.Layout storage l = PoolLikeStorage.layout();
        uint256 balance = IERC20(l.underlying).balanceOf(address(this));
        uint256 mintAmount = balance - l.totalBalance;
        mintTokens = (mintAmount * 1e18) / exchangeRate();

        if (_totalSupply() == 0) {
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            mintTokens = mintTokens - PoolLikeStorage.MINIMUM_LIQUIDITY;
            _mint(address(0), PoolLikeStorage.MINIMUM_LIQUIDITY);
        }
        _require(mintTokens > 0, Errors.MINT_AMOUNT_ZERO);
        _mint(_minter, mintTokens);
        emit Mint(msg.sender, _minter, mintAmount, mintTokens);
        _update();
    }

    /// @notice Redeems pool shares for `underlying` tokens.
    /// @dev This is a low level method that should be called via periphery contracts.
    /// @param _redeemer Address receiving the redempt tokens.
    /// @return redeemAmount Amount of tokens redeemed for burning the shares.
    function redeem(
        address _redeemer
    ) external nonReentrant returns (uint256 redeemAmount) {
        PoolLikeStorage.Layout storage l = PoolLikeStorage.layout();
        uint256 redeemTokens = _balanceOf(address(this));
        redeemAmount = (redeemTokens * exchangeRate()) / 1e18;

        _require(redeemAmount > 0, Errors.REDEEM_AMOUNT_ZERO);
        _require(redeemAmount <= l.totalBalance, Errors.INSUFFICIENT_CASH);
        _burn(address(this), redeemTokens);
        l.underlying.safeTransfer(_redeemer, redeemAmount);
        emit Redeem(msg.sender, _redeemer, redeemAmount, redeemTokens);
        _update();
    }

    /// @notice Skims excess unaccounted tokens from the pool.
    /// @param _to Address receiving the skimmed tokens.
    function skim(address _to) external nonReentrant {
        PoolLikeStorage.Layout storage l = PoolLikeStorage.layout();
        address _underlying = l.underlying;
        _underlying.safeTransfer(
            _to,
            IERC20(_underlying).balanceOf(address(this)) - l.totalBalance
        );
    }

    /// @notice Syncs the pool's balance with its current token balance.
    function sync() external nonReentrant {
        _update();
    }

    /// @notice Calculates the exchange rate of pool tokens to redeemable `underlying`.
    /// @return The amount of `underlying` per token.
    function exchangeRate() public returns (uint256) {
        PoolLikeStorage.Layout storage l = PoolLikeStorage.layout();
        uint256 _totalSupply = _totalSupply();
        uint256 _totalBalance = l.totalBalance;
        if (_totalSupply == 0 || _totalBalance == 0) return 1e18;
        return (_totalBalance * 1e18) / _totalSupply;
    }

    function _update() internal {
        PoolLikeStorage.layout().totalBalance = IERC20(
            PoolLikeStorage.layout().underlying
        ).balanceOf(address(this));
        emit Sync(PoolLikeStorage.layout().totalBalance);
    }

    function _setMetadata(string memory _name, string memory _symbol) internal {
        _setName(_name);
        _setSymbol(_symbol);
        _setDecimals(18);
    }
}
