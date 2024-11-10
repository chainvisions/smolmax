// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IInterestRateModel {
    function accrueInterest() external;

    function getBlockTimestamp() external view returns (uint32);
}

interface IBorrowable is IInterestRateModel {
    /** Borrowable Related **/
    function borrow(
        address borrower,
        address receiver,
        uint256 borrowAmount,
        bytes calldata data
    ) external;

    function liquidate(
        address borrower,
        address liquidator
    ) external returns (uint256);

    function trackBorrow(address) external;

    function setReserveFactor(uint256) external;

    function setKinkUtilizationRate(uint256) external;

    function setAdjustSpeed(uint256) external;

    function setBorrowTracker(address) external;

    /** Allowance Related **/
    function borrowApprove(address, uint256) external returns (bool);

    /** Events **/

    event BorrowApproval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event Borrow(
        address indexed sender,
        address indexed borrower,
        address indexed receiver,
        uint256 borrowAmount,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event Liquidate(
        address indexed sender,
        address indexed borrower,
        address indexed liquidator,
        uint256 seizeTokens,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );

    event AccrueInterest(
        uint256 interestAccumulated,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    event CalculateKink(uint256 kinkRate);
    event CalculateBorrowRate(uint256 borrowRate);

    event NewReserveFactor(uint256 newReserveFactor);
    event NewKinkUtilizationRate(uint256 newKinkUtilizationRate);
    event NewAdjustSpeed(uint256 newAdjustSpeed);
    event NewBorrowTracker(address newBorrowTracker);
}
