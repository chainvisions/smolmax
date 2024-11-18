// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMinter {
    function realizeProfit(address, uint256) external returns (uint256);
}
