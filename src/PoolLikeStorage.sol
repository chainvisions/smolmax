// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title PoolLike Storage
/// @author Chainvisions
/// @notice Storage for Pool-like contracts.

library PoolLikeStorage {
    /// @dev Minimum amount of liquidity that can be held.
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;

    struct Layout {
        /// @notice Underlying token held by the pool.
        address underlying;
        /// @notice Total amount of `underlying` tokens held by the pool.
        uint256 totalBalance;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("limestone.contracts.storage.PoolLike");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
