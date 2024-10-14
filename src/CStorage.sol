// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @title Collateral Storage
/// @author Chainvisions, forked from Impermax
/// @notice State variables stored in the Collateral contract.

contract CStorage {
    address public borrowable0;
    address public borrowable1;
    address public simpleUniswapOracle;
    uint256 public safetyMarginSqrt = 1.58113883e18; //safetyMargin: 250%
    uint256 public liquidationIncentive = 1.02e18; //2%
    uint256 public liquidationFee = 0.02e18; //2%

    function liquidationPenalty() public view returns (uint) {
        return liquidationIncentive + liquidationFee;
    }
}
