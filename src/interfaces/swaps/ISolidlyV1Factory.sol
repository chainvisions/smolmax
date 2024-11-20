// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ISolidlyV1Factory {
    function getFee(bool _stable) external view returns (uint256);
}
