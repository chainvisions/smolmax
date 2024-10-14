// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IPoolToken} from "./interfaces/IPoolToken.sol";
import {_require, Errors} from "./libraries/Errors.sol";
import {ImpermaxERC20} from "./ImpermaxERC20.sol";

// TODO: Inherit IPoolToken
contract PoolToken is IPoolToken, ImpermaxERC20, ReentrancyGuard {
    uint256 internal constant initialExchangeRate = 1e18;
    address public override underlying;
    address public override factory;
    uint256 public override totalBalance;
    uint256 public constant override MINIMUM_LIQUIDITY = 1000;

    event Mint(
        address indexed sender,
        address indexed minter,
        uint256 mintAmount,
        uint256 mintTokens
    );
    event Redeem(
        address indexed sender,
        address indexed redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    );
    event Sync(uint256 totalBalance);

    /*** Initialize ***/

    // called once by the factory
    function _setFactory() external override {
        _require(factory == address(0), Errors.FACTORY_ALREADY_SET);
        factory = msg.sender;
    }

    /*** PoolToken ***/

    function _update() internal {
        totalBalance = IERC20(underlying).balanceOf(address(this));
        emit Sync(totalBalance);
    }

    function exchangeRate() public override returns (uint) {
        uint256 _totalSupply = totalSupply; // gas savings
        uint256 _totalBalance = totalBalance; // gas savings
        if (_totalSupply == 0 || _totalBalance == 0) return initialExchangeRate;
        return (_totalBalance * 1e18) / _totalSupply;
    }

    /// @notice Mints new pool tokens using `underlying` tokens.
    /// @dev This is a low level function that is ideally called via the periphery contracts.
    /// @param _minter Address to mint tokens to.
    /// @return mintTokens Amount of tokens minted.
    function mint(
        address _minter
    ) external override nonReentrant update returns (uint256 mintTokens) {
        uint256 balance = IERC20(underlying).balanceOf(address(this));
        uint256 mintAmount = balance - totalBalance;
        mintTokens = (mintAmount * 1e18) / exchangeRate();

        if (totalSupply == 0) {
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            mintTokens = mintTokens - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        _require(mintTokens > 0, Errors.MINT_AMOUNT_ZERO);
        _mint(_minter, mintTokens);
        emit Mint(msg.sender, _minter, mintAmount, mintTokens);
    }

    /// @notice Redeems the pool token for the underlying asset held.
    /// @dev This is a low level function that is ideally called via the periphery contracts.
    /// @param _redeemer Address to send redeemed tokens to.
    /// @return redeemAmount Amount of `underlying` redeemed.
    function redeem(
        address _redeemer
    ) external override nonReentrant update returns (uint256 redeemAmount) {
        uint256 redeemTokens = balanceOf[address(this)];
        redeemAmount = (redeemTokens * exchangeRate()) / 1e18;

        _require(redeemAmount > 0, Errors.REDEEM_AMOUNT_ZERO);
        _require(redeemAmount <= totalBalance, Errors.INSUFFICIENT_CASH);
        _burn(address(this), redeemTokens);
        _safeTransfer(_redeemer, redeemAmount);
        emit Redeem(msg.sender, _redeemer, redeemAmount, redeemTokens);
    }

    /// @notice Skims off extra held tokens that are not accounted for.
    /// @param _to Address to send skimmed tokens to.
    function skim(address _to) external override nonReentrant {
        _safeTransfer(
            _to,
            IERC20(underlying).balanceOf(address(this)) - totalBalance
        );
    }

    /// @notice Assimilates extra held tokens into the pool's `totalBalance`.
    function sync() external nonReentrant update {}

    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = underlying.call(
            abi.encodeWithSelector(SELECTOR, to, amount)
        );
        _require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            Errors.TRANSFER_FAILED
        );
    }

    // update totalBalance with current balance
    modifier update() {
        _;
        _update();
    }
}
