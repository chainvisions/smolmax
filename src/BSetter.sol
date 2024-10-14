// // SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IFactory} from "./interfaces/IFactory.sol";
import {_require, Errors} from "./libraries/Errors.sol";
import {BStorage} from "./BStorage.sol";
import {PoolToken} from "./PoolToken.sol";

/// @title Borrowable Setter
/// @author Chainvisions, forked from Impermax
/// @notice Contract for setting borrowable parameters.

contract BSetter is PoolToken, BStorage {
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

    /// @notice Emitted when a new reserve factor is set.
    /// @param newReserveFactory The new reserve factor.
    event NewReserveFactor(uint256 newReserveFactor);

    /// @notice Emitted when a new kink utilization rate is set.
    /// @param NewKinkUtilizationRate The new kink utilization rate.
    event NewKinkUtilizationRate(uint256 newKinkUtilizationRate);

    /// @notice Emitted when a new adjustment speed is set.
    /// @param newAdjustSpeed The new adjustment speed.
    event NewAdjustSpeed(uint256 newAdjustSpeed);

    /// @notice Emitted when a new borrow tracker contract is set.
    /// @param newBorrowTracker New borrow tracker contract.
    event NewBorrowTracker(address newBorrowTracker);

    /// @notice called once by the factory at time of deployment
    function _initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _collateral
    ) external {
        /// @dev sufficient check
        _require(msg.sender == factory, Errors.UNAUTHORIZED_CALL);
        _setName(_name, _symbol);
        underlying = _underlying;
        collateral = _collateral;
        exchangeRateLast = initialExchangeRate;
    }

    function setReserveFactor(uint256 newReserveFactor) external nonReentrant {
        _checkSetting(newReserveFactor, 0, RESERVE_FACTOR_MAX);
        reserveFactor = newReserveFactor;
        emit NewReserveFactor(newReserveFactor);
    }

    function setKinkUtilizationRate(
        uint256 newKinkUtilizationRate
    ) external nonReentrant {
        _checkSetting(newKinkUtilizationRate, KINK_UR_MIN, KINK_UR_MAX);
        kinkUtilizationRate = newKinkUtilizationRate;
        emit NewKinkUtilizationRate(newKinkUtilizationRate);
    }

    function setAdjustSpeed(uint256 newAdjustSpeed) external nonReentrant {
        _checkSetting(newAdjustSpeed, ADJUST_SPEED_MIN, ADJUST_SPEED_MAX);
        adjustSpeed = newAdjustSpeed;
        emit NewAdjustSpeed(newAdjustSpeed);
    }

    function setBorrowTracker(address newBorrowTracker) external nonReentrant {
        _checkAdmin();
        borrowTracker = newBorrowTracker;
        emit NewBorrowTracker(newBorrowTracker);
    }

    function _checkSetting(
        uint256 parameter,
        uint256 min,
        uint256 max
    ) internal view {
        _checkAdmin();
        _require(parameter >= min, Errors.INVALID_SETTING);
        _require(parameter <= max, Errors.INVALID_SETTING);
    }

    function _checkAdmin() internal view {
        _require(
            msg.sender == IFactory(factory).admin(),
            Errors.UNAUTHORIZED_CALL
        );
    }
}
