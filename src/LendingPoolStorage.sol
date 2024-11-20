// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IWarchest} from "./interfaces/IWarchest.sol";

/// @notice Interest rate models to calculate from.
enum InterestRateModel {
    TripleSlope
}

/// @title Lending Pool Storage
/// @author Chainvisions
/// @notice Diamond storage contract for the Limestone Lending Pool.

library LendingPoolStorage {
    /// @notice Lending pool configuration.
    struct LendingPool {
        address underlying;
        uint32 lastAccrueTime;
        uint128 minDebtSize;
        uint16 reservePoolBps;
        uint16 liquidateBps;
        InterestRateModel interestRateModel;
        IWarchest warchest;
        uint112 totalShares;
        uint256 globalDebtValue;
        uint256 globalDebtShare;
        uint256 reservePool;
    }

    /// @notice Leveraged yield farming position.
    struct Position {
        address worker;
        address owner;
        uint256 poolId;
        uint256 debtShare;
    }

    struct Layout {
        /// @notice All lending pools for the protocol.
        LendingPool[] lendingPools;
        /// @notice Leveraged yield farming positions.
        mapping(uint256 => Position) positions;
        /// @notice ID for the next LYF position.
        uint256 nextPositionID;
        /// @notice Total amount of lending pools.
        uint256 totalLendingPools;
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
