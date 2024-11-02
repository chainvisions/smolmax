pragma solidity ^0.8.20;

import "../../src/interfaces/IUniswapV2Pair.sol";

contract Recipient {
    function empty(address uniswapV2Pair, address to) public {
        uint256 balance = IUniswapV2Pair(uniswapV2Pair).balanceOf(
            address(this)
        );
        IUniswapV2Pair(uniswapV2Pair).transfer(to, balance);
    }
}

