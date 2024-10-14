// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {_require, Errors} from "./libraries/Errors.sol";

/// @title Borrowable Storage
/// @author Chainvisions, forked from Impermax
/// @notice Contract used for storing state variables for the Borrowable contract.

contract BStorage {
    /// @notice Collateral contract.
    address public collateral;

    /// @notice Allowances of the Borrowable.
    mapping(address => mapping(address => uint256)) public borrowAllowance;

    struct BorrowSnapshot {
        /// @notice Amount of underlying since the last update.
        uint112 principal; // amount in underlying when the borrow was last updated
        /// @notice Latest borrow index.
        uint112 interestIndex; // borrow index when borrow was last updated
    }

    mapping(address => BorrowSnapshot) internal borrowBalances;

    /// @notice Current borrow index.
    uint112 public borrowIndex = 1e18;

    /// @notice Total borrows.
    uint112 public totalBorrows;

    /// @notice TImestamp since the last accrual.
    uint32 public accrualTimestamp = uint32(block.timestamp % 2 ** 32);

    /// @notice Latest exchange rate of the Borrowable.
    uint256 public exchangeRateLast;

    /// @notice Current borrow rate.
    uint48 public borrowRate;

    /// @notice Current kink borrow rate.
    uint48 public kinkBorrowRate = 6.3419584e9;

    /// @notice Timestamp since the last rate update.
    uint32 public rateUpdateTimestamp = uint32(block.timestamp % 2 ** 32);

    /// @notice Reserve factor of the Borrowable.
    uint256 public reserveFactor = 0.10e18;

    /// @notice Current kink utilization rate of the Borrowable.
    uint256 public kinkUtilizationRate = 0.75e18;

    /// @notice Current adjustment speed of the Borrowable.
    uint256 public adjustSpeed = 5.787037e12;

    /// @notice Current borrow tracker contract.
    address public borrowTracker;
}
