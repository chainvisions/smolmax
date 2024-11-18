// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {Storage, GovernableStorage} from "./GovernableStorage.sol";

/// @title GovernableNoInit
/// @author Chainvisions
/// @notice Contract for access control that utilizes diamond storage instead.

contract GovernableNoInit {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("limestone.contracts.storage.lib.Governable");

    modifier onlyGovernance() {
        require(
            GovernableStorage.layout().store.isGovernance(msg.sender),
            "Governable: Not governance"
        );
        _;
    }

    function _setStore(address _store) internal {
        GovernableStorage.layout().store = Storage(_store);
    }

    function setStorage(address _store) public onlyGovernance {
        require(
            _store != address(0),
            "Governable: New storage shouldn't be empty"
        );
        GovernableStorage.layout().store = Storage(_store);
    }

    function governance() public view returns (address) {
        return address(GovernableStorage.layout().store);
    }
}
