pragma solidity ^0.8.20;

import "../../src/BAllowance.sol";

contract BAllowanceHarness is BAllowance {
    constructor(
        string memory _name,
        string memory _symbol
    ) public ImpermaxERC20() {
        _setName(_name, _symbol);
    }

    function checkBorrowAllowance(
        address owner,
        address spender,
        uint256 amount
    ) external {
        super._checkBorrowAllowance(owner, spender, amount);
    }
}

