// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LendingPoolStorage} from "../LendingPoolStorage.sol";

/// @title Base Lending Pool Mosaic
/// @author Chainvisions
/// @notice Mosaic for Limestone's base lending pool contract.

contract BaseLendingPoolMosaic {
    /// @notice Fetches the info of a specific lending pool.
    /// @param _poolId ID of the lending pool.
    /// @return The stored data of the lending pool.
    function lendingPools(uint256 _poolId) external pure returns (LendingPoolStorage.LendingPool memory) {}

    /// @notice Deposits tokens into a lending pool.
    /// @param _poolId ID of the lending pool to deposit into.
    /// @param _amount Amount of tokens to deposit into the lending pool.
    function deposit(uint256 _poolId, uint256 _amount) external pure {}

    /// @notice Withdraws tokens from a lending pool.
    /// @param _poolId ID of the lending pool to withdraw from.
    /// @param _amount Amount of lending pool shares to burn.
    function withdraw(uint256 _poolId, uint256 _amount) external pure {}

    /// @notice Fetches the amount of underlying tokens held by a lending pool.
    /// @param _poolId ID of the lending pool.
    /// @return The total amount of tokens held by the lending pool.
    function underlyingBalanceForPool(uint256 _poolId) external pure returns (uint256) {}
}
