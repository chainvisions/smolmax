// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IRamsesLegacyGauge {
    function deposit(uint256, uint256) external;
    function withdraw(uint256) external;
    function withdrawAll() external;
    function getReward(address, address[] memory) external;
    function balanceOf(address) external view returns (uint256);
}
