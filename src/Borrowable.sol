pragma solidity 0.8.13;

import {PoolToken} from "./PoolToken.sol";
import {BAllowance} from "./BAllowance.sol";
import {BInterestRateModel} from "./BInterestRateModel.sol";
import {BSetter} from "./BSetter.sol";
import {BStorage} from "./BStorage.sol";
import {IBorrowable} from "./interfaces/IBorrowable.sol";
import {ICollateral} from "./interfaces/ICollateral.sol";
import {IImpermaxCallee} from "./interfaces/IImpermaxCallee.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IBorrowTracker} from "./interfaces/IBorrowTracker.sol";
import {Math} from "./libraries/Math.sol";
import {_require, Errors} from "./libraries/Errors.sol";

// TODO: Inherit IBorrowable
contract Borrowable is
    IBorrowable,
    PoolToken,
    BStorage,
    BSetter,
    BInterestRateModel,
    BAllowance
{
    uint256 public constant BORROW_FEE;

    event Borrow(
        address indexed sender,
        address indexed borrower,
        address indexed receiver,
        uint256 borrowAmount,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event Liquidate(
        address indexed sender,
        address indexed borrower,
        address indexed liquidator,
        uint256 seizeTokens,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );

    /*** PoolToken ***/

    function _update() internal override {
        super._update();
        _calculateBorrowRate();
    }

    function _mintReserves(
        uint256 _exchangeRate,
        uint256 _totalSupply
    ) internal returns (uint) {
        uint256 _exchangeRateLast = exchangeRateLast;
        if (_exchangeRate > _exchangeRateLast) {
            uint256 _exchangeRateNew = _exchangeRate -
                (((_exchangeRate - _exchangeRateLast) * reserveFactor) / 1e18);
            uint256 liquidity = ((_totalSupply * _exchangeRate) /
                _exchangeRateNew) - _totalSupply;
            if (liquidity > 0) {
                address reservesManager = IFactory(factory).reservesManager();
                _mint(reservesManager, liquidity);
            }
            exchangeRateLast = _exchangeRateNew;
            return _exchangeRateNew;
        } else return _exchangeRate;
    }
    /// @inheritdoc IBorrowable
    function exchangeRate() public override accrue returns (uint256) {
        uint256 _totalSupply = totalSupply;
        uint256 _actualBalance = totalBalance + totalBorrows;
        if (_totalSupply == 0 || _actualBalance == 0)
            return initialExchangeRate;
        uint256 _exchangeRate = (_actualBalance * 1e18) / _totalSupply;
        return _mintReserves(_exchangeRate, _totalSupply);
    }
    /// @inheritdoc IBorrowable
    function sync() external override nonReentrant update accrue {}

    /*** Borrowable ***/
    /// @inheritdoc IBorrowable
    function borrowBalance(address borrower) public view returns (uint) {
        BorrowSnapshot memory borrowSnapshot = borrowBalances[borrower];
        if (borrowSnapshot.interestIndex == 0) return 0; // not initialized
        return
            (uint(borrowSnapshot.principal) * borrowIndex) /
            borrowSnapshot.interestIndex;
    }

    function _trackBorrow(
        address borrower,
        uint256 accountBorrows,
        uint256 _borrowIndex
    ) internal {
        address _borrowTracker = borrowTracker;
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
        accountBorrowsPrior = borrowBalance(borrower);
        if (borrowAmount == repayAmount)
            return (accountBorrowsPrior, accountBorrowsPrior, totalBorrows);
        uint112 _borrowIndex = borrowIndex;
        if (borrowAmount > repayAmount) {
            BorrowSnapshot storage borrowSnapshot = borrowBalances[borrower];
            uint256 increaseAmount = borrowAmount - repayAmount;
            accountBorrows = accountBorrowsPrior + increaseAmount;
            borrowSnapshot.principal = safe112(accountBorrows);
            borrowSnapshot.interestIndex = _borrowIndex;
            _totalBorrows = uint(totalBorrows) + increaseAmount;
            totalBorrows = safe112(_totalBorrows);
        } else {
            BorrowSnapshot storage borrowSnapshot = borrowBalances[borrower];
            uint256 decreaseAmount = repayAmount - borrowAmount;
            accountBorrows = accountBorrowsPrior > decreaseAmount
                ? accountBorrowsPrior - decreaseAmount
                : 0;
            borrowSnapshot.principal = safe112(accountBorrows);
            if (accountBorrows == 0) {
                borrowSnapshot.interestIndex = 0;
            } else {
                borrowSnapshot.interestIndex = _borrowIndex;
            }
            uint256 actualDecreaseAmount = accountBorrowsPrior - accountBorrows;
            /// @dev gas savings
            _totalBorrows = totalBorrows;
            _totalBorrows = _totalBorrows > actualDecreaseAmount
                ? _totalBorrows - actualDecreaseAmount
                : 0;
            totalBorrows = safe112(_totalBorrows);
        }
        _trackBorrow(borrower, accountBorrows, _borrowIndex);
    }

    /// @inheritdoc IBorrowable
    function borrow(
        address borrower,
        address receiver,
        uint256 borrowAmount,
        bytes calldata data
    ) external nonReentrant update accrue {
        uint256 _totalBalance = totalBalance;
        _require(borrowAmount <= _totalBalance, Errors.INSUFFICIENT_CASH);
        _checkBorrowAllowance(borrower, msg.sender, borrowAmount);

        /// @dev optimistically transfer funds
        if (borrowAmount > 0) _safeTransfer(receiver, borrowAmount);
        if (data.length > 0)
            IImpermaxCallee(receiver).impermaxBorrow(
                msg.sender,
                borrower,
                borrowAmount,
                data
            );
        uint256 balance = IERC20(underlying).balanceOf(address(this));

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
                ICollateral(collateral).canBorrow(
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
    }

    /// @inheritdoc IBorrowable
    function liquidate(
        address borrower,
        address liquidator
    ) external nonReentrant update accrue returns (uint256 seizeTokens) {
        uint256 balance = IERC20(underlying).balanceOf(address(this));
        uint256 repayAmount = balance - totalBalance;

        uint256 actualRepayAmount = Math.min(
            borrowBalance(borrower),
            repayAmount
        );
        seizeTokens = ICollateral(collateral).seize(
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
    }

    /// @inheritdoc IBorrowable
    function trackBorrow(address borrower) external {
        _trackBorrow(borrower, borrowBalance(borrower), borrowIndex);
    }

    modifier accrue() {
        accrueInterest();
        _;
    }
}
