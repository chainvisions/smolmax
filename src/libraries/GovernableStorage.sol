// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Storage} from "./Storage.sol";

library GovernableStorage {
    struct Layout {
        Storage store;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("limestone.contracts.storage.lib.Governable");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
