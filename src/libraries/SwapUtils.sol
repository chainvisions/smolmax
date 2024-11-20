// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

/// @title Swap Utils
/// @author Chainvisions
/// @notice A utility contract for calculating optimal swaps.

library SwapUtils {
    function _optimalAmountIn(uint256 _swapFee, uint256 _reserveIn, uint256 _balanceOf)
        internal
        pure
        returns (uint256)
    {
        uint256 a = (10000 * 2) - _swapFee;
        uint256 b = (((10000 - _swapFee) * 4) * 10000);
        uint256 c = a ** 2;
        return (
            (FixedPointMathLib.sqrt((_reserveIn * ((_balanceOf * b) + (_reserveIn * c)))) - _reserveIn * a)
                / ((10000 - _swapFee) * 2)
        );
    }

    function _optimalZapAmountIn(
        uint256 _amountA,
        uint256 _amountB,
        uint256 _reserveA,
        uint256 _reserveB,
        uint256 _swapFee
    ) internal pure returns (uint256 toSwap, bool reversed) {
        // Determine if we need to swap A -> B or B -> A.
        if (_amountA * _reserveB >= _amountB * _reserveA) {
            toSwap = _calculateOptimalDeposit(_amountA, _amountB, _reserveA, _reserveB, _swapFee);
            reversed = false;
        } else {
            toSwap = _calculateOptimalDeposit(_amountB, _amountA, _reserveB, _reserveA, _swapFee);
            reversed = true;
        }
    }

    function _calculateOptimalDeposit(
        uint256 _amountA,
        uint256 _amountB,
        uint256 _reserveA,
        uint256 _reserveB,
        uint256 _swapFee
    ) internal pure returns (uint256) {
        uint256 a = 10000 - _swapFee;
        uint256 b = (20000 - _swapFee) * _reserveA;
        uint256 _c = ((_amountA * _reserveB) - (_amountB * _reserveA));
        uint256 c = (((_c * 10000) / (_amountB + _reserveB)) * _reserveA);

        uint256 d = (a * c) * 4;
        uint256 e = FixedPointMathLib.sqrt(((b * b) + d));
        return ((e - b) / (a * 2));
    }
}
