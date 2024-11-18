// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {GovernableNoInit, GovernableStorage, Storage} from "./GovernableNoInit.sol";

/// @title ControllableNoInit
/// @author Chainvisions
/// @notice Contract for access control that utilizes diamond storage instead.

contract ControllableNoInit is GovernableNoInit {
    modifier onlyController() {
        require(
            GovernableStorage.layout().store.isController(msg.sender),
            "Controllable: Not a controller"
        );
        _;
    }

    modifier onlyControllerOrGovernance() {
        Storage store = GovernableStorage.layout().store;
        require(
            (store.isController(msg.sender) || store.isGovernance(msg.sender)),
            "Controllable: The caller must be controller or governance"
        );
        _;
    }

    function controller() public view returns (address) {
        return GovernableStorage.layout().store.controller();
    }
}
