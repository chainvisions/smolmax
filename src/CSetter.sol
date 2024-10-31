pragma solidity 0.8.28;

import "./CStorage.sol";
import "./PoolToken.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ISimpleUniswapOracle.sol";
import "./libraries/Errors.sol";

contract CSetter is PoolToken, CStorage {
    uint256 public constant SAFETY_MARGIN_SQRT_MIN = 1.00e18; //safetyMargin: 100%
    uint256 public constant SAFETY_MARGIN_SQRT_MAX = 1.58113884e18; //safetyMargin: 250%
    uint256 public constant LIQUIDATION_INCENTIVE_MIN = 1.00e18; //100%
    uint256 public constant LIQUIDATION_INCENTIVE_MAX = 1.05e18; //105%
    uint256 public constant LIQUIDATION_FEE_MAX = 0.08e18; //8%

    event NewSafetyMargin(uint256 newSafetyMarginSqrt);
    event NewLiquidationIncentive(uint256 newLiquidationIncentive);
    event NewLiquidationFee(uint256 newLiquidationFee);

    // called once by the factory at the time of deployment
    function _initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _borrowable0,
        address _borrowable1
    ) external {
        _require(msg.sender == factory, Errors.UNAUTHORIZED_CALL); // sufficient check
        _setName(_name, _symbol);
        underlying = _underlying;
        borrowable0 = _borrowable0;
        borrowable1 = _borrowable1;
        simpleUniswapOracle = IFactory(factory).simpleUniswapOracle();
    }

    function _setSafetyMarginSqrt(
        uint256 newSafetyMarginSqrt
    ) external nonReentrant {
        _checkSetting(
            newSafetyMarginSqrt,
            SAFETY_MARGIN_SQRT_MIN,
            SAFETY_MARGIN_SQRT_MAX
        );
        safetyMarginSqrt = newSafetyMarginSqrt;
        emit NewSafetyMargin(newSafetyMarginSqrt);
    }

    function _setLiquidationIncentive(
        uint256 newLiquidationIncentive
    ) external nonReentrant {
        _checkSetting(
            newLiquidationIncentive,
            LIQUIDATION_INCENTIVE_MIN,
            LIQUIDATION_INCENTIVE_MAX
        );
        liquidationIncentive = newLiquidationIncentive;
        emit NewLiquidationIncentive(newLiquidationIncentive);
    }

    function _setLiquidationFee(
        uint256 newLiquidationFee
    ) external nonReentrant {
        _checkSetting(newLiquidationFee, 0, LIQUIDATION_FEE_MAX);
        liquidationFee = newLiquidationFee;
        emit NewLiquidationFee(newLiquidationFee);
    }

    function _checkSetting(
        uint256 parameter,
        uint256 min,
        uint256 max
    ) internal view {
        _checkAdmin();
        _require(parameter >= min, Errors.INVALID_SETTING);
        _require(parameter <= max, Errors.INVALID_SETTING);
    }

    function _checkAdmin() internal view {
        _require(
            msg.sender == IFactory(factory).admin(),
            Errors.UNAUTHORIZED_CALL
        );
    }
}
