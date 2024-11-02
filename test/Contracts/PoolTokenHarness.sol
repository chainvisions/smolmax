pragma solidity ^0.8.20;

import "../../src/PoolToken.sol";

contract PoolTokenHarness is PoolToken {
    function setUnderlying(address _underlying) public {
        underlying = _underlying;
    }
}

