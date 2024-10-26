// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {_require, Errors} from "./libraries/Errors.sol";

/// @title Borrowable Storage
/// @author Chainvisions
/// @notice Contract used for storing state variables for the Borrowable contract.

library BStorage {
    /// @notice Max reserve factor. Hard coded at 20%.
    uint256 public constant RESERVE_FACTOR_MAX = 0.20e18;

    /// @notice Minimum kink utilization rate. Hard coded at 50%.
    uint256 public constant KINK_UR_MIN = 0.50e18;

    /// @notice Maximum kink utilization rate. Hard coded at 99%.
    uint256 public constant KINK_UR_MAX = 0.99e18;

    /// @notice Minimum adjustment speed. Hard coded at 0.5% per day.
    uint256 public constant ADJUST_SPEED_MIN = 0.05787037e12;

    /// @notice Maximum adjustment speed. Hard coded at 500% per day.
    uint256 public constant ADJUST_SPEED_MAX = 57.87037e12;

    /// @notice Data structure used to track existing borrows.
    struct BorrowSnapshot {
        /// @notice Amount of underlying since the last update.
        uint112 principal;
        /// @notice Latest borrow index.
        uint112 interestIndex;
    }

    struct Layout {
        /// @notice Collateral contract.
        address collateral;
        /// @notice Current borrow index.
        uint112 borrowIndex;
        /// @notice Total borrows.
        uint112 totalBorrows;
        /// @notice Timestamp since the last accrual.
        uint32 accrualTimestamp;
        /// @notice Latest exchange rate of the Borrowable.
        uint256 exchangeRateLast;
        /// @notice Current borrow rate.
        uint48 borrowRate;
        /// @notice Current kink borrow rate.
        uint48 kinkBorrowRate;
        /// @notice Timestamp since the last rate update.
        uint32 rateUpdateTimestamp;
        /// @notice Reserve factor of the Borrowable.
        uint256 reserveFactor;
        /// @notice Current kink utilization rate of the Borrowable.
        uint256 kinkUtilizationRate;
        /// @notice Current adjustment speed of the Borrowable.
        uint256 adjustSpeed;
        /// @notice Current borrow tracker contract.
        address borrowTracker;
        /// @notice Allowances of the Borrowable.
        mapping(address => mapping(address => uint256)) borrowAllowances;
        mapping(address => BorrowSnapshot) borrowBalances;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("limestone.contracts.storage.Borrowable");

    /// @dev Internal function used to initialize the storage values. Should be called on initialize.
    function populateStorage() internal {
        Layout storage l = layout();
        l.borrowIndex = 1e18;
        l.accrualTimestamp = uint32(block.timestamp % 2 ** 32);
        l.kinkBorrowRate = 6.3419584e9;
        l.rateUpdateTimestamp = uint32(block.timestamp % 2 ** 32);
        l.reserveFactor = 0.10e18;
        l.kinkUtilizationRate = 0.75e18;
        l.adjustSpeed = 5.787037e12;
    }

    function _setReserveFactor(uint256 _newReserveFactor) internal {
        _validate(_newReserveFactor, 0, RESERVE_FACTOR_MAX);
        layout().reserveFactor = _newReserveFactor;
    }

    function _setKinkUtilizationRate(uint256 _newKinkUtilRate) internal {
        _validate(_newKinkUtilRate, KINK_UR_MIN, KINK_UR_MAX);
        layout().kinkUtilizationRate = _newKinkUtilRate;
    }

    function _setAdjustSpeed(uint256 _newAdjustSpeed) internal {
        _validate(_newAdjustSpeed, ADJUST_SPEED_MIN, ADJUST_SPEED_MAX);
        layout().adjustSpeed = _newAdjustSpeed;
    }

    function _setBorrowTracker(address _newBorrowTracker) internal {
        layout().borrowTracker = _newBorrowTracker;
    }

    /// @dev Used to validate new settings that are restricted to a specific min/max range.
    /// @param _parameter Setting value to validate.
    /// @param _min Expected minimum.
    /// @param _max Expected maximum.
    function _validate(
        uint256 _parameter,
        uint256 _min,
        uint256 _max
    ) internal pure {
        _require(_parameter >= _min, Errors.INVALID_SETTING);
        _require(_parameter <= _max, Errors.INVALID_SETTING);
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
