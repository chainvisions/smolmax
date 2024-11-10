// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";

/// @title Vesting Accounting
/// @author Chainvisions
/// @notice Contract for managing vesting data.

library VestingAccounting {
    // @notice Data structure for tracking locked LIME.
    struct Lock {
        uint32 unlockTime;
        uint128 amount;
    }

    struct Layout {
        /// @notice Total amount of LIME locked in vesting.
        uint256 totalLocked;
        /// @notice Total amount of LIME that a user has currently vesting.
        mapping(address => uint128) totalAmountVesting;
        /// @notice LIME locks held by a specific user.
        mapping(address => Lock[]) locks;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("limestone.contracts.storage.EmissionsController.Vesting");

    function _issueLock(address _recipient, uint256 _amount) internal {
        Layout storage l = layout();
        uint128 castedAmount = SafeCastLib.toUint128(_amount);

        // Store new lock and add it to the lock total.
        l.totalLocked += _amount;
        l.locks[_recipient].push(
            Lock({
                unlockTime: SafeCastLib.toUint32((block.timestamp + 90 days)),
                amount: castedAmount
            })
        );
        l.totalAmountVesting[_recipient] += castedAmount;
    }

    function _freeLocks(address _user) internal returns (uint128 imbursement) {
        Layout storage l = layout();
        Lock[] storage _locks = l.locks[_user];

        // Redeem all known expired locks for later imbursement.
        uint256 totalLocks = _locks.length;
        if (_locks[totalLocks - 1].unlockTime <= block.timestamp) {
            imbursement = l.totalAmountVesting[_user];
            delete layout().locks[_user];
        } else {
            for (uint256 i; i < totalLocks; ) {
                Lock memory _lock = _locks[i];
                if (_lock.unlockTime > block.timestamp) break;
                imbursement += _lock.amount;
                delete _locks[i];
                unchecked {
                    ++i;
                } // TODO: Fucking Neovim.
            }
        }
        l.totalLocked -= imbursement;
    }

    function _vestable(address _user) internal view returns (uint256 vestable) {
        Layout storage l = layout();
        Lock[] storage _locks = l.locks[_user];

        // Pretty much the same as `_freeLocks` minus storage mutation.
        uint256 totalLocks = _locks.length;
        if (_locks[totalLocks - 1].unlockTime <= block.timestamp) {
            vestable = l.totalAmountVesting[_user];
        } else {
            for (uint256 i; i < totalLocks; ) {
                Lock memory _lock = _locks[i];
                if (_lock.unlockTime > block.timestamp) break;
                vestable += _lock.amount;
                unchecked {
                    ++i;
                } // TODO: Neovim once again.
            }
        }
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
