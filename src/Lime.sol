// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {_require, Errors} from "./libraries/Errors.sol";

/// @title Limestone Token
/// @author Chainvisions
/// @notice Limestone token contract.

contract Lime is ERC20("Limestone.fi", "LIME") {
    /// @notice Context enum for minter updates.
    enum MinterUpdate {
        Add,
        Remove
    }

    /// @notice Owner of the LIME token contract.
    address public governance;

    /// @notice Addresses permitted to mint LIME tokens.
    mapping(address => bool) public minters;

    /// @notice Emitted when a new minter is added.
    /// @param minter Minter added to contract.
    event MinterAdded(address minter);

    /// @notice Emitted when a minter is removed.
    /// @param minter Minter removed from the contract.
    event MinterRemoved(address minter);

    /// @notice Constructor for the LIME tokens contract.
    constructor() {
        governance = msg.sender;
    }

    modifier onlyGovernance() {
        //_require(msg.sender == governance, Errors.CALLER_NOT_GOV_OR_REWARD_DIST);
        _;
    }

    /// @notice Makes an update to the minters list.
    /// @param _ctx Context for the update (Add / Remove).
    /// @param _minter Minter to update.
    function updateMinters(
        MinterUpdate _ctx,
        address _minter
    ) external onlyGovernance {
        if (_ctx == MinterUpdate.Add) {
            minters[_minter] = true;
            emit MinterAdded(_minter);
        } else {
            minters[_minter] = false;
            emit MinterRemoved(_minter);
        }
    }

    /// @notice Updates the governance address.
    /// @param _newGovernance New governance address.
    function updateGovernance(address _newGovernance) external onlyGovernance {
        governance = _newGovernance;
    }

    /// @notice Mints new LIME tokens.
    /// @param _to Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount) external {
        _require(minters[msg.sender], Errors.UNAUTHORIZED_CALL);
        _mint(_to, _amount);
    }

    /// @notice Burns LIME tokens.
    /// @param _amount Amount of tokens to burn.
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    /// @notice Burns tokens approved from the owner.
    /// @param _from The owner of the tokens to burn from.
    /// @param _amount Amount of tokens to burn.
    function burnFrom(address _from, uint256 _amount) external {
        _require(
            allowance(_from, msg.sender) >= _amount,
            Errors.TOKENS_NOT_APPROVED
        );
        _spendAllowance(_from, msg.sender, _amount);
        _burn(_from, _amount);
    }
}
