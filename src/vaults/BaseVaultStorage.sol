// // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/// @title Base Vault Storage
/// @author Chainvisions
/// @notice Base storage for Limestone LYF vaults.

library BaseVaultStorage {
    struct Layout {
        /// @notice Underlying token of the vault.
        IERC20 underlying;
        /// @notice Reward pool farmed by the vault.
        address rewardPool;
        /// @notice Total amount of `underlying` tokens accounted in the vault.
        uint256 totalUnderlyingHeld;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("limestone.contracts.storage.BaseVaultStorage");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
