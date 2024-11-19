// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Lending Pool Oracle Mosaic
/// @author Chainvisions
/// @notice Mosaic for Limestone's lending pool oracle.

contract LendingPoolOracleMosaic {
    /// @notice Fetches the price for a specific token.
    /// @param _token Token to fetch price data for.
    /// @return price Price of the token.
    /// @return lastUpdateTimestamp Timestamp of the latest price update.
    function getPriceForToken(address _token) external pure returns (uint256 price, uint32 lastUpdateTimestamp) {}

    /// @notice Sets the price source for a token.
    /// @param _token Token to set the price source for.
    /// @param _source Target price source of the token.
    /// @param _sourceAddress Address where the price source is at.
    function setTokenPriceSource(address _token, uint256 _source, address _sourceAddress) external pure {}
}
