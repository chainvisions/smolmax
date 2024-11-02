// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Voter Accounting
/// @author Chainvisions
/// @notice Contract for managing voter data, bribes, etc.

library VoterAccounting {
    /// @notice Data structure used for tracking bribe reward data.
    struct Bribe {
        uint256 nlll;
    }

    struct Layout {
        uint256 nll;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("limestone.contracts.storage.EmissionsController");

    /// @dev Method used for registering votes for bribe rewards on a specific vault.
    /// @param _vault Vault to register votes towards.
    /// @param _voteTotal Total amount of voting power allocated to the vault. Used for reward calculation.
    /// @param _veId ID of the veNFT used to cast the vote.
    function account(
        address _vault,
        uint256 _voteTotal,
        uint256 _veId
    ) internal {}

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
