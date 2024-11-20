// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

enum PriceSource {
    Chainlink,
    Twap
}

struct TokenPriceSource {
    /// @notice Source for fetching the token price.
    PriceSource source;
    /// @notice Main source for the price. E.g pair or Chainlink.
    address sourceAddress;
}

/// @notice Basic token data for AMM pairs.
struct PairTokenData {
    address token0;
    address token1;
    uint16 token0Decimals;
    uint16 token1Decimals;
}

/// @title Limestone Oracle Storage
/// @author Chainvisions
/// @notice Storage contract for Limestone's oracle.

library OracleStorage {
    struct Layout {
        /// @notice Price source used for a specific token.
        mapping(address token0 => mapping(address token1 => TokenPriceSource)) tokenPriceSource;
        /// @notice Cache for pair data to save on calls.
        mapping(address => PairTokenData) pairDataCache;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("limestone.contracts.storage.LendingPool");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            // We hardcode this slot to use less bytecode
            // and save a small amount of gas not needing an MSTORE.
            l.slot := slot
        }
    }
}
