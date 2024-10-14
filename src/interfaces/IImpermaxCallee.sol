pragma solidity >=0.5.0;

interface IImpermaxCallee {
    function impermaxBorrow(address sender, address borrower, uint256 borrowAmount, bytes calldata data) external;
    function impermaxRedeem(address sender, uint256 redeemAmount, bytes calldata data) external;
}