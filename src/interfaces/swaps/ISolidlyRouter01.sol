// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ISolidlyRouter01 {
    // A standard Solidly route used for routing through pairs.
    struct Route {
        address from;
        address to;
        bool stable;
    }

    // Adds liquidity to a pair on Solidly
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountA,
        uint256 amountB,
        uint256 aMin,
        uint256 bMin,
        address to,
        uint256 deadline
    ) external returns (uint256);
    // Swaps tokens on Solidly via a specific route.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
    // Swaps tokens on Solidly from A to B through only one pair.
    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);

    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256, uint256, uint256);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);
    function factory() external view returns (address);
}
