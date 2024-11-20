// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title ILimestoneOracle
/// @author Chainvisions
/// @notice A basic interface for Limestone's oracle.

interface ILimestoneOracle {
    /// @notice Fetches the current price of a token pair.
    function getPriceForToken(address, address) external view returns (uint256, uint32);
}
