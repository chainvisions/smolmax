pragma solidity 0.8.13;

import {IFactory} from "./interfaces/IFactory.sol";
import {IBorrowable} from "./interfaces/IBorrowable.sol";
import {ICollateral} from "./interfaces/ICollateral.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {ISimpleUniswapOracle} from "./interfaces/ISimpleUniswapOracle.sol";
import {_require, Errors} from "./libraries/Errors.sol";
import {Borrowable} from "./Borrowable.sol";
import {Collateral} from "./Collateral.sol";

// TODO: Inherit IFactory.
contract Factory {
    address public admin;
    address public pendingAdmin;
    address public reservesAdmin;
    address public reservesPendingAdmin;
    address public reservesManager;

    struct LendingPool {
        bool initialized;
        uint24 lendingPoolId;
        address collateral;
        address borrowable0;
        address borrowable1;
    }
    mapping(address => LendingPool) public getLendingPool; // get by UniswapV2Pair
    address[] public allLendingPools; // address of the UniswapV2Pair

    function allLendingPoolsLength() external view returns (uint) {
        return allLendingPools.length;
    }

    ISimpleUniswapOracle public simpleUniswapOracle;

    event LendingPoolInitialized(
        address indexed uniswapV2Pair,
        address indexed token0,
        address indexed token1,
        address collateral,
        address borrowable0,
        address borrowable1,
        uint256 lendingPoolId
    );
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewReservesPendingAdmin(
        address oldReservesPendingAdmin,
        address newReservesPendingAdmin
    );
    event NewReservesAdmin(address oldReservesAdmin, address newReservesAdmin);
    event NewReservesManager(
        address oldReservesManager,
        address newReservesManager
    );

    constructor(
        address _admin,
        address _reservesAdmin,
        ISimpleUniswapOracle _simpleUniswapOracle
    ) {
        admin = _admin;
        reservesAdmin = _reservesAdmin;
        simpleUniswapOracle = _simpleUniswapOracle;
        emit NewAdmin(address(0), _admin);
        emit NewReservesAdmin(address(0), _reservesAdmin);
    }

    function _getTokens(
        address uniswapV2Pair
    ) private view returns (address token0, address token1) {
        token0 = IUniswapV2Pair(uniswapV2Pair).token0();
        token1 = IUniswapV2Pair(uniswapV2Pair).token1();
    }

    function _createLendingPool(address uniswapV2Pair) private {
        if (getLendingPool[uniswapV2Pair].lendingPoolId != 0) return;
        allLendingPools.push(uniswapV2Pair);
        getLendingPool[uniswapV2Pair] = LendingPool(
            false,
            uint24(allLendingPools.length),
            address(0),
            address(0),
            address(0)
        );
    }

    /// @notice Creates a new lending collateral.
    /// @param uniswapV2Pair Pair used for the collateral.
    /// @return collateral Collateral contract created.
    function createCollateral(
        address uniswapV2Pair
    ) external returns (address collateral) {
        _getTokens(uniswapV2Pair);
        _require(
            getLendingPool[uniswapV2Pair].collateral == address(0),
            Errors.LENDING_COMPONENT_ALREADY_EXISTS
        );

        bytes memory bytecode = type(Collateral).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(address(this), uniswapV2Pair)
        );
        assembly {
            collateral := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        ICollateral(collateral)._setFactory();
        _createLendingPool(uniswapV2Pair);
        getLendingPool[uniswapV2Pair].collateral = collateral;
    }

    function createBorrowable0(
        address uniswapV2Pair
    ) external returns (address borrowable0) {
        _getTokens(uniswapV2Pair);
        _require(
            getLendingPool[uniswapV2Pair].borrowable0 == address(0),
            Errors.LENDING_COMPONENT_ALREADY_EXISTS
        );

        bytes memory bytecode = type(Borrowable).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(address(this), uniswapV2Pair, 0)
        );
        assembly {
            borrowable0 := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IBorrowable(borrowable0)._setFactory();
        _createLendingPool(uniswapV2Pair);
        getLendingPool[uniswapV2Pair].borrowable0 = borrowable0;
    }

    function createBorrowable1(
        address uniswapV2Pair
    ) external returns (address borrowable1) {
        _getTokens(uniswapV2Pair);
        _require(
            getLendingPool[uniswapV2Pair].borrowable1 == address(0),
            Errors.LENDING_COMPONENT_ALREADY_EXISTS
        );

        bytes memory bytecode = type(Borrowable).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(address(this), uniswapV2Pair, 1)
        );
        assembly {
            borrowable1 := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IBorrowable(borrowable1)._setFactory();
        _createLendingPool(uniswapV2Pair);
        getLendingPool[uniswapV2Pair].borrowable1 = borrowable1;
    }

    function initializeLendingPool(address uniswapV2Pair) external {
        (address token0, address token1) = _getTokens(uniswapV2Pair);
        LendingPool memory lPool = getLendingPool[uniswapV2Pair];
        _require(!lPool.initialized, Errors.LENDING_POOL_ALREADY_INITIALIZED);

        _require(lPool.collateral != address(0), Errors.COLLATERAL_NOT_CREATED);
        _require(
            lPool.borrowable0 != address(0),
            Errors.BORROWABLE_ZERO_NOT_CREATED
        );
        _require(
            lPool.borrowable1 != address(0),
            Errors.BORROWABLE_ONE_NOT_CREATED
        );

        (, , , , , bool oracleInitialized) = simpleUniswapOracle.getPair(
            uniswapV2Pair
        );
        if (!oracleInitialized) simpleUniswapOracle.initialize(uniswapV2Pair);

        ICollateral(lPool.collateral)._initialize(
            "Smolmax Collateral",
            "imxC",
            uniswapV2Pair,
            lPool.borrowable0,
            lPool.borrowable1
        );
        IBorrowable(lPool.borrowable0)._initialize(
            "Smolmax Borrowable",
            "imxB",
            token0,
            lPool.collateral
        );
        IBorrowable(lPool.borrowable1)._initialize(
            "Smolmax Borrowable",
            "imxB",
            token1,
            lPool.collateral
        );

        getLendingPool[uniswapV2Pair].initialized = true;
        emit LendingPoolInitialized(
            uniswapV2Pair,
            token0,
            token1,
            lPool.collateral,
            lPool.borrowable0,
            lPool.borrowable1,
            lPool.lendingPoolId
        );
    }

    function setPendingAdmin(address newPendingAdmin) external {
        _require(msg.sender == admin, Errors.UNAUTHORIZED_CALL);
        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = newPendingAdmin;
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    function acceptAdmin() external {
        _require(msg.sender == pendingAdmin, Errors.UNAUTHORIZED_CALL);
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, address(0));
    }

    function setReservesPendingAdmin(address newReservesPendingAdmin) external {
        _require(msg.sender == reservesAdmin, Errors.UNAUTHORIZED_CALL);
        address oldReservesPendingAdmin = reservesPendingAdmin;
        reservesPendingAdmin = newReservesPendingAdmin;
        emit NewReservesPendingAdmin(
            oldReservesPendingAdmin,
            newReservesPendingAdmin
        );
    }

    function acceptReservesAdmin() external {
        _require(msg.sender == reservesPendingAdmin, Errors.UNAUTHORIZED_CALL);
        address oldReservesAdmin = reservesAdmin;
        address oldReservesPendingAdmin = reservesPendingAdmin;
        reservesAdmin = reservesPendingAdmin;
        reservesPendingAdmin = address(0);
        emit NewReservesAdmin(oldReservesAdmin, reservesAdmin);
        emit NewReservesPendingAdmin(oldReservesPendingAdmin, address(0));
    }

    function setReservesManager(address newReservesManager) external {
        _require(msg.sender == reservesAdmin, Errors.UNAUTHORIZED_CALL);
        address oldReservesManager = reservesManager;
        reservesManager = newReservesManager;
        emit NewReservesManager(oldReservesManager, newReservesManager);
    }
}
