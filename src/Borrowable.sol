// // SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {IBorrowable} from "./interfaces/IBorrowable.sol";
import {ICollateral} from "./interfaces/ICollateral.sol";
import {IImpermaxCallee} from "./interfaces/IImpermaxCallee.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IBorrowTracker} from "./interfaces/IBorrowTracker.sol";
import {Math} from "./libraries/Math.sol";
import {_require, Errors} from "./libraries/Errors.sol";
import {PoolLike, PoolLikeStorage} from "./PoolLike.sol";
import {BAllowance} from "./BAllowance.sol";
import {BInterestRateModel} from "./BInterestRateModel.sol";
import {BStorage} from "./BStorage.sol";

/// TODO Reimplement IBorrowable *eventually*.
contract Borrowable is PoolLike, BInterestRateModel, BAllowance {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /// @notice Fee incurred from borrowing.
    uint256 public constant BORROW_FEE = 0;

    /// @notice Borrowable Constructor.
    /// @param _factory Factory contract.
    constructor(address _factory) PoolLike(_factory) {}

    /// @notice Borrowable initializer.
    /// @param _name Name of the Borrowable token.
    /// @param _symbol Symbol of the Borrowable token.
    /// @param _underlying Underlying token of the Borrowable.
    /// @param _collateral Collateral contract of the Borrowable.
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _collateral
    ) external {
        _require(msg.sender == FACTORY, Errors.UNAUTHORIZED_CALL);
        // TODO: Add initializer modifier.
        BStorage.populateStorage();
        _setMetadata(_name, _symbol);
        PoolLikeStorage.layout().underlying = _underlying;
        BStorage.layout().collateral = _collateral;
    }

    /*** PoolToken ***/

    function _update() internal override {
        super._update();
        _calculateBorrowRate();
    }

    function _mintReserves(
        uint256 _exchangeRate,
        uint256 _totalSupply
    ) internal returns (uint256) {
        BStorage.Layout storage l = BStorage.layout();
        uint256 _exchangeRateLast = l.exchangeRateLast;
        if (_exchangeRate > _exchangeRateLast) {
            uint256 _exchangeRateNew = _exchangeRate -
                (((_exchangeRate - _exchangeRateLast) * l.reserveFactor) /
                    1e18);
            uint256 liquidity = ((_totalSupply * _exchangeRate) /
                _exchangeRateNew) - _totalSupply;
            if (liquidity > 0) {
                address reservesManager = IFactory(FACTORY).reservesManager();
                _mint(reservesManager, liquidity);
            }
            l.exchangeRateLast = _exchangeRateNew;
            return _exchangeRateNew;
        } else return _exchangeRate;
    }

    /// @inheritdoc IBorrowable
    function exchangeRate()
        public
        override(PoolLike, IBorrowable)
        accrue
        returns (uint256)
    {
        uint256 _totalSupply = _totalSupply();
        uint256 _actualBalance = PoolLikeStorage.layout().totalBalance +
            BStorage.layout().totalBorrows;
        if (_totalSupply == 0 || _actualBalance == 0) return 1e18;
        uint256 _exchangeRate = (_actualBalance * 1e18) / _totalSupply;
        return _mintReserves(_exchangeRate, _totalSupply);
    }

    /// @inheritdoc IBorrowable
    function sync()
        external
        override(PoolLike, IBorrowable)
        nonReentrant
        accrue
    {
        _update();
    }

    /*** Borrowable ***/
    /// @inheritdoc IBorrowable
    function borrowBalance(address borrower) public view returns (uint256) {
        BStorage.Layout storage l = BStorage.layout();
        BStorage.BorrowSnapshot memory borrowSnapshot = l.borrowBalances[
            borrower
        ];
        if (borrowSnapshot.interestIndex == 0) return 0; // not initialized
        return
            (uint(borrowSnapshot.principal) * l.borrowIndex) /
            borrowSnapshot.interestIndex;
    }

    function _trackBorrow(
        address borrower,
        uint256 accountBorrows,
        uint256 _borrowIndex
    ) internal {
        address _borrowTracker = BStorage.layout().borrowTracker;
        if (_borrowTracker == address(0)) return;
        IBorrowTracker(_borrowTracker).trackBorrow(
            borrower,
            accountBorrows,
            _borrowIndex
        );
    }

    function _updateBorrow(
        address borrower,
        uint256 borrowAmount,
        uint256 repayAmount
    )
        private
        returns (
            uint256 accountBorrowsPrior,
            uint256 accountBorrows,
            uint256 _totalBorrows
        )
    {
        BStorage.Layout storage l = BStorage.layout();
        accountBorrowsPrior = borrowBalance(borrower);
        if (borrowAmount == repayAmount)
            return (accountBorrowsPrior, accountBorrowsPrior, l.totalBorrows);
        uint112 _borrowIndex = l.borrowIndex;
        if (borrowAmount > repayAmount) {
            BStorage.BorrowSnapshot storage borrowSnapshot = l.borrowBalances[
                borrower
            ];
            uint256 increaseAmount = borrowAmount - repayAmount;
            accountBorrows = accountBorrowsPrior + increaseAmount;
            borrowSnapshot.principal = accountBorrows.toUint112();
            borrowSnapshot.interestIndex = _borrowIndex;
            _totalBorrows = uint256(l.totalBorrows) + increaseAmount;
            l.totalBorrows = _totalBorrows.toUint112();
        } else {
            BStorage.BorrowSnapshot storage borrowSnapshot = l.borrowBalances[
                borrower
            ];
            uint256 decreaseAmount = repayAmount - borrowAmount;
            accountBorrows = accountBorrowsPrior > decreaseAmount
                ? accountBorrowsPrior - decreaseAmount
                : 0;
            borrowSnapshot.principal = accountBorrows.toUint112();
            if (accountBorrows == 0) {
                borrowSnapshot.interestIndex = 0;
            } else {
                borrowSnapshot.interestIndex = _borrowIndex;
            }
            uint256 actualDecreaseAmount = accountBorrowsPrior - accountBorrows;
            /// @dev gas savings
            _totalBorrows = l.totalBorrows;
            _totalBorrows = _totalBorrows > actualDecreaseAmount
                ? _totalBorrows - actualDecreaseAmount
                : 0;
            l.totalBorrows = _totalBorrows.toUint112();
        }
        _trackBorrow(borrower, accountBorrows, _borrowIndex);
    }

    /// @inheritdoc IBorrowable
    function borrow(
        address borrower,
        address receiver,
        uint256 borrowAmount,
        bytes calldata data
    ) external nonReentrant accrue {
        PoolLikeStorage.Layout storage l = PoolLikeStorage.layout();
        uint256 _totalBalance = l.totalBalance;
        _require(borrowAmount <= _totalBalance, Errors.INSUFFICIENT_CASH);
        _checkBorrowAllowance(borrower, msg.sender, borrowAmount);

        /// @dev optimistically transfer funds
        if (borrowAmount > 0) l.underlying.safeTransfer(receiver, borrowAmount);
        if (data.length > 0)
            IImpermaxCallee(receiver).impermaxBorrow(
                msg.sender,
                borrower,
                borrowAmount,
                data
            );
        uint256 balance = IERC20(l.underlying).balanceOf(address(this));

        uint256 borrowFee = (borrowAmount * BORROW_FEE) / 1e18;
        uint256 adjustedBorrowAmount = borrowAmount + borrowFee;
        uint256 repayAmount = (balance + borrowAmount) - _totalBalance;
        (
            uint256 accountBorrowsPrior,
            uint256 accountBorrows,
            uint256 _totalBorrows
        ) = _updateBorrow(borrower, adjustedBorrowAmount, repayAmount);

        if (adjustedBorrowAmount > repayAmount)
            _require(
                ICollateral(BStorage.layout().collateral).canBorrow(
                    borrower,
                    address(this),
                    accountBorrows
                ),
                Errors.INSUFFICIENT_LIQUIDITY
            );

        emit Borrow(
            msg.sender,
            borrower,
            receiver,
            borrowAmount,
            repayAmount,
            accountBorrowsPrior,
            accountBorrows,
            _totalBorrows
        );
        _update();
    }

    /// @inheritdoc IBorrowable
    function liquidate(
        address borrower,
        address liquidator
    ) external nonReentrant accrue returns (uint256 seizeTokens) {
        PoolLikeStorage.Layout storage l = PoolLikeStorage.layout();
        uint256 balance = IERC20(l.underlying).balanceOf(address(this));
        uint256 repayAmount = balance - l.totalBalance;

        uint256 actualRepayAmount = Math.min(
            borrowBalance(borrower),
            repayAmount
        );
        seizeTokens = ICollateral(BStorage.layout().collateral).seize(
            liquidator,
            borrower,
            actualRepayAmount
        );
        (
            uint256 accountBorrowsPrior,
            uint256 accountBorrows,
            uint256 _totalBorrows
        ) = _updateBorrow(borrower, 0, repayAmount);

        emit Liquidate(
            msg.sender,
            borrower,
            liquidator,
            seizeTokens,
            repayAmount,
            accountBorrowsPrior,
            accountBorrows,
            _totalBorrows
        );

        _update();
    }

    /// @inheritdoc IBorrowable
    function trackBorrow(address borrower) external {
        _trackBorrow(
            borrower,
            borrowBalance(borrower),
            BStorage.layout().borrowIndex
        );
    }

    /// @inheritdoc IBorrowable
    function setReserveFactor(uint256 _newReserveFactor) external {
        // TODO: Check for permissions.
        BStorage._setReserveFactor(_newReserveFactor);
        emit NewReserveFactor(_newReserveFactor);
    }

    /// @inheritdoc IBorrowable
    function setKinkUtilizationRate(uint256 _newKinkUtilRate) external {
        // TODO: Check for permissions.
        BStorage._setKinkUtilizationRate(_newKinkUtilRate);
        emit NewKinkUtilizationRate(_newKinkUtilRate);
    }

    /// @inheritdoc IBorrowable
    function setAdjustSpeed(uint256 _newAdjustSpeed) external {
        // TODO: Check for permissions.
        BStorage._setAdjustSpeed(_newAdjustSpeed);
        emit NewAdjustSpeed(_newAdjustSpeed);
    }

    // @inheritdoc IBorrowable
    function setBorrowTracker(address _newBorrowTracker) external {
        // TODO: Check for permissions.
        BStorage._setBorrowTracker(_newBorrowTracker);
        emit NewBorrowTracker(_newBorrowTracker);
    }

    modifier accrue() {
        accrueInterest();
        _;
    }
}
