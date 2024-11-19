// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseLendingPoolMosaic} from "./BaseLendingPoolMosaic.sol";
import {LendingPoolOracleMosaic} from "./LendingPoolOracleMosaic.sol";
import {LendingPoolLensMosaic} from "./LendingPoolLensMosaic.sol";

/// @title Lending Pool Mosaic
/// @author Chainvisions
/// @notice Complete mosaic for Limestone's lending pool diamond.

contract LendingPoolMosaic is BaseLendingPoolMosaic, LendingPoolOracleMosaic, LendingPoolLensMosaic {}
