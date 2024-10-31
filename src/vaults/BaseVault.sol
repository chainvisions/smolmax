// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseVaultStorage} from "./BaseVaultStorage.sol";

/// @title Base Vault
/// @author Chainvisions
/// @notice Base contract for Limestone LYF vaults.

abstract contract BaseVault {
    /// @notice Tokens farmed by the vault.
    address[] public rewardTokens;

    /// @notice Mints new vault shares.
    /// @param _minter Address minting the new shares.
    function mint(address _minter) external {}

    /// @notice Redeems vault shares for `underlying`.
    /// @param _redeemer Recipient of the redeemed value.
    function redeem(address _redeemer) external {}

    /// @notice Harvests pending yield and reinvests into the vault.
    function reinvest() external virtual;

    /// @notice Calculates the value in `underlying` of shares in the vault.
    /// @return The current vault share price.
    function getPricePerFullShare() external virtual returns (uint256);

    /// @notice Pure method to distinguish that the contract is a vault.
    /// @return `true`
    function isVault() external pure returns (bool) {
        return true;
    }

    function _notifyPerformanceFees(
        address _tokenIn,
        uint256 _amount
    ) internal {}

    function _investAssets(uint256 _amountToInvest) internal virtual;

    function _redeemAssets(uint256 _amountToRedeem) internal virtual;
}
