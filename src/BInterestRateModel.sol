// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {BStorage} from "./BStorage.sol";
import {PoolToken} from "./PoolToken.sol";

/// @title Borrowable Interest Rate Model
/// @author Chainvisions
/// @notice Interest rate model for Borrowable tokens.

contract BInterestRateModel is PoolToken, BStorage {
    /// @dev When utilization is 100% borrowRate is kinkBorrowRate * KINK_MULTIPLIER
    /// @dev kinkBorrowRate relative adjustment per second belongs to [1-adjustSpeed, 1+adjustSpeed*(KINK_MULTIPLIER-1)]
    uint256 public constant KINK_MULTIPLIER = 2;
    uint256 public constant KINK_BORROW_RATE_MAX = 792.744800e9; //2500% per year
    uint256 public constant KINK_BORROW_RATE_MIN = 0.31709792e9; //1% per year

    event AccrueInterest(
        uint256 interestAccumulated,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    event CalculateKinkBorrowRate(uint256 kinkBorrowRate);
    event CalculateBorrowRate(uint256 borrowRate);

    function _calculateBorrowRate() internal {
        uint256 _kinkUtilizationRate = kinkUtilizationRate;
        uint256 _adjustSpeed = adjustSpeed;
        uint256 _borrowRate = borrowRate;
        uint256 _kinkBorrowRate = kinkBorrowRate;
        uint32 _rateUpdateTimestamp = rateUpdateTimestamp;

        /// @dev update kinkBorrowRate using previous borrowRate
        /// @dev underflow is desired
        uint32 timeElapsed = getBlockTimestamp() - _rateUpdateTimestamp;
        if (timeElapsed > 0) {
            rateUpdateTimestamp = getBlockTimestamp();
            uint256 adjustFactor;

            if (_borrowRate < _kinkBorrowRate) {
                /// @dev never overflows, _kinkBorrowRate is never 0
                uint256 tmp = ((((_kinkBorrowRate - _borrowRate) * 1e18) /
                    _kinkBorrowRate) *
                    _adjustSpeed *
                    timeElapsed) / 1e18;
                adjustFactor = tmp > 1e18 ? 0 : 1e18 - tmp;
            } else {
                /// @dev never overflows, _kinkBorrowRate is never 0
                uint256 tmp = ((((_borrowRate - _kinkBorrowRate) * 1e18) /
                    _kinkBorrowRate) *
                    _adjustSpeed *
                    timeElapsed) / 1e18;
                adjustFactor = tmp + 1e18;
            }

            /// @dev never overflows
            _kinkBorrowRate = (_kinkBorrowRate * adjustFactor) / 1e18;
            if (_kinkBorrowRate > KINK_BORROW_RATE_MAX)
                _kinkBorrowRate = KINK_BORROW_RATE_MAX;
            if (_kinkBorrowRate < KINK_BORROW_RATE_MIN)
                _kinkBorrowRate = KINK_BORROW_RATE_MIN;

            kinkBorrowRate = uint48(_kinkBorrowRate);
            emit CalculateKinkBorrowRate(_kinkBorrowRate);
        }

        uint256 _utilizationRate;
        {
            /// @dev avoid stack to deep
            uint256 _totalBorrows = totalBorrows; // gas savings
            uint256 _actualBalance = totalBalance + _totalBorrows;
            _utilizationRate = (_actualBalance == 0)
                ? 0
                : (_totalBorrows * 1e18) / _actualBalance;
        }

        /// @dev update borrowRate using the new kinkBorrowRate
        if (_utilizationRate <= _kinkUtilizationRate) {
            /// @dev never overflows, _kinkUtilizationRate is never 0
            _borrowRate =
                (_kinkBorrowRate * _utilizationRate) /
                _kinkUtilizationRate;
        } else {
            /// @dev never overflows, _kinkUtilizationRate is always < 1e18
            uint256 overUtilization = ((_utilizationRate -
                _kinkUtilizationRate) * 1e18) / (1e18 - _kinkUtilizationRate);
            /// @dev never overflows
            _borrowRate =
                (((KINK_MULTIPLIER - 1) * overUtilization + 1e18) *
                    _kinkBorrowRate) /
                1e18;
        }
        borrowRate = uint48(_borrowRate);
        emit CalculateBorrowRate(_borrowRate);
    }

    /// @notice applies accrued interest to total borrows and reserves
    function accrueInterest() public {
        uint256 _borrowIndex = borrowIndex;
        uint256 _totalBorrows = totalBorrows;
        uint32 _accrualTimestamp = accrualTimestamp;

        uint32 blockTimestamp = getBlockTimestamp();
        /// @dev if same timestamp, terminate
        if (_accrualTimestamp == blockTimestamp) return;
        /// @dev underflow is desired
        uint32 timeElapsed = blockTimestamp - _accrualTimestamp;
        accrualTimestamp = blockTimestamp;

        uint256 interestFactor = uint256(borrowRate) * timeElapsed;
        uint256 interestAccumulated = (interestFactor * _totalBorrows) / 1e18;
        _totalBorrows = _totalBorrows + interestAccumulated;
        _borrowIndex = _borrowIndex + ((interestFactor * _borrowIndex) / 1e18);

        borrowIndex = safe112(_borrowIndex);
        totalBorrows = safe112(_totalBorrows);
        emit AccrueInterest(interestAccumulated, _borrowIndex, _totalBorrows);
    }

    function getBlockTimestamp() public view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }
}
