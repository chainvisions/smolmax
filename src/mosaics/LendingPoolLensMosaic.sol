// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Lending Pool Lens Mosaic
/// @author Chainvisions
/// @notice Mosaic for Limestone's lending pool lens.

contract LendingPoolLensMosaic {
    /// @notice Fetches all leveraged positions held by the user.
    /// @dev May consume excessive amounts of gas and revert.
    /// @param _user User to fetch the positions of.
    /// @return All known leverage positions from the user.
    function leveragedPositionsOf(address _user) external pure returns (uint256[] memory) {}
}
