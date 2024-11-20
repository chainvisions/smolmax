// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {PairTokenData} from "../OracleStorage.sol";

/// @title Lending Pool Oracle Mosaic
/// @author Chainvisions
/// @notice Mosaic for Limestone's lending pool oracle.

contract LendingPoolOracleMosaic {
    /// @notice Fetches the price for a specific token using a pair.
    /// @param _token0 Token0 of the pair.
    /// @param _token1 Token1 of the pair.
    /// @return price Price of the token in the form of how much token1 a unit of token0 is worth.
    /// @return lastUpdateTimestamp Timestamp of the latest price update.
    function getPriceForToken(address _token0, address _token1)
        external
        pure
        returns (uint256 price, uint32 lastUpdateTimestamp)
    {}

    /// @notice Fetches pair token data from storage.
    /// @param _pair Pair to fetcht he token data for.
    /// @return The token data for `_pair`.
    function pairTokenData(address _pair) external pure returns (PairTokenData memory) {}

    /// @notice Sets the price source for a token pair.
    /// @param _token0 Token0 of the pair.
    /// @param _token1 Token1 of the pair.
    /// @param _source Target price source of the token.
    /// @param _sourceAddress Address where the price source is at.
    function setTokenPriceSource(address _token0, address _token1, uint256 _source, address _sourceAddress)
        external
        pure
    {}

    /// @notice Indexes token data for Solidly-like pairs.
    /// @param _pairs Pairs to index token data for.
    function indexSolidlyLikePairs(address[] calldata _pairs) external pure {}
}
