pragma solidity >=0.5.0;

interface IBorrowable {
    /*** Smolmax ERC20 ***/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /*** Pool Token ***/

    event Mint(
        address indexed sender,
        address indexed minter,
        uint256 mintAmount,
        uint256 mintTokens
    );
    event Redeem(
        address indexed sender,
        address indexed redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    );
    event Sync(uint256 totalBalance);

    function underlying() external view returns (address);
    function factory() external view returns (address);
    function totalBalance() external view returns (uint);
    function MINIMUM_LIQUIDITY() external pure returns (uint);

    /// @notice returns the exchangeRate of the borrowable
    /// @return _r rate
    function exchangeRate() external returns (uint256 _r);
    function mint(address minter) external returns (uint256 mintTokens);
    function redeem(address redeemer) external returns (uint256 redeemAmount);
    function skim(address to) external;
    /// @notice forces totalBalance to match real balance
    function sync() external;

    function _setFactory() external;

    /*** Borrowable ***/

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

    function BORROW_FEE() external pure returns (uint);
    function collateral() external view returns (address);
    function reserveFactor() external view returns (uint);
    function exchangeRateLast() external view returns (uint);
    function borrowIndex() external view returns (uint);
    function totalBorrows() external view returns (uint);
    function borrowAllowance(
        address owner,
        address spender
    ) external view returns (uint);
    /// @notice this is the stored borrow balance; the current borrow balance may be slightly higher
    function borrowBalance(address borrower) external view returns (uint);
    function borrowTracker() external view returns (address);

    function BORROW_PERMIT_TYPEHASH() external pure returns (bytes32);
    function borrowApprove(
        address spender,
        uint256 value
    ) external returns (bool);
    function borrowPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    /// @notice this low-level function should be called from another contract
    function borrow(
        address borrower,
        address receiver,
        uint256 borrowAmount,
        bytes calldata data
    ) external;
    /// @notice this low-level function should be called from another contract
    function liquidate(
        address borrower,
        address liquidator
    ) external returns (uint256 seizeTokens);
    function trackBorrow(address borrower) external;

    /*** Borrowable Interest Rate Model ***/

    event AccrueInterest(
        uint256 interestAccumulated,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    event CalculateKink(uint256 kinkRate);
    event CalculateBorrowRate(uint256 borrowRate);

    function KINK_BORROW_RATE_MAX() external pure returns (uint);
    function KINK_BORROW_RATE_MIN() external pure returns (uint);
    function KINK_MULTIPLIER() external pure returns (uint);
    function borrowRate() external view returns (uint);
    function kinkBorrowRate() external view returns (uint);
    function kinkUtilizationRate() external view returns (uint);
    function adjustSpeed() external view returns (uint);
    function rateUpdateTimestamp() external view returns (uint32);
    function accrualTimestamp() external view returns (uint32);

    function accrueInterest() external;

    /*** Borrowable Setter ***/

    event NewReserveFactor(uint256 newReserveFactor);
    event NewKinkUtilizationRate(uint256 newKinkUtilizationRate);
    event NewAdjustSpeed(uint256 newAdjustSpeed);
    event NewBorrowTracker(address newBorrowTracker);

    function RESERVE_FACTOR_MAX() external pure returns (uint);
    function KINK_UR_MIN() external pure returns (uint);
    function KINK_UR_MAX() external pure returns (uint);
    function ADJUST_SPEED_MIN() external pure returns (uint);
    function ADJUST_SPEED_MAX() external pure returns (uint);

    function _initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _collateral
    ) external;
    function _setReserveFactor(uint256 newReserveFactor) external;
    function _setKinkUtilizationRate(uint256 newKinkUtilizationRate) external;
    function _setAdjustSpeed(uint256 newAdjustSpeed) external;
    function _setBorrowTracker(address newBorrowTracker) external;
}
