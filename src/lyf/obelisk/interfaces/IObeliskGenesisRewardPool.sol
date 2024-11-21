// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IObeliskGenesisRewardPool {
    function deposit(uint256, uint256) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
    function userInfo(uint256, address) external view returns (uint256, uint256);
}
