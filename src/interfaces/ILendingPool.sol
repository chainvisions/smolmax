// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice Lending Pool Interface
/// @author Chainvisions
/// @notice Interface for the Limestone Lending Pool facet.

interface ILendingPool {
    event AddDebt(uint256 indexed id, uint256 debtShare);
    event RemoveDebt(uint256 indexed id, uint256 debtShare);
    event Work(uint256 indexed id, uint256 loan);

    /// @notice Emitted when a position is liquidated.
    /// @param id ID of the position liquidated.
    /// @param killer Address of the liquidator that killed the position.
    /// @param prize Reward awarded to the liquidator for liquidating the position.
    /// @param left Amount of assets left after the liquidation.
    event Kill(uint256 indexed id, address indexed killer, uint256 prize, uint256 left);

    /// @notice Deposits tokens into the lending pool.
    /// @param _poolId ID of the lending pool to deposit into.
    /// @param _amount Amount of tokens to deposit into the lending pool.
    function deposit(uint256 _poolId, uint256 _amount) external;

    /// @notice Withdraws tokens from the lending pool.
    /// @param _poolId Pool ID of the lending pool to withdraw from.
    /// @param _amount Amount of tokens to withdraw from the lending pool.
    function withdraw(uint256 _poolId, uint256 _amount) external;

    /// @notice Used by workers to access any additional approved assets from a specific user. Used for two sided liquidity provision.
    /// @param _user User to request assets from.
    /// @param _token Token to request from user.
    /// @param _requestedAmount Amount requested to transfer from the user.
    function accessUserAssets(address _user, address _token, uint256 _requestedAmount) external;
}
