// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ISolidlyV1Pair {
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);

    function reserve0CumulativeLast() external view returns (uint256);

    function reserve1CumulativeLast() external view returns (uint256);

    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp);

    function stable() external view returns (bool);

    function observationLength() external view returns (uint256);

    function observations(uint256)
        external
        view
        returns (uint256 timestamp, uint256 reserve0Cumulative, uint256 reserve1Cumulative);

    function getAmountOut(uint256, address) external view returns (uint256);

    function token0() external view returns (address);
    function token1() external view returns (address);

    function tokens() external view returns (address, address);

    function totalSupply() external view returns (uint256);
}
