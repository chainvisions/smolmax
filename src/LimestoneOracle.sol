// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Metadata} from "@solidstate/token/ERC20/metadata/IERC20Metadata.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {ISolidlyV1Pair} from "./interfaces/swaps/ISolidlyV1Pair.sol";
import {ILimestoneOracle} from "./interfaces/ILimestoneOracle.sol";
import {GovernableNoInit} from "./libraries/GovernableNoInit.sol";
import {Cast} from "./libraries/Cast.sol";
import {OracleStorage, TokenPriceSource, PriceSource, PairTokenData} from "./OracleStorage.sol";

/// @title Limestone Oracle Facet
/// @author Chainvisions
/// @notice Oracle facet for Limestone token prices.

contract LimestoneOracle is ILimestoneOracle, GovernableNoInit {
    using Cast for uint256;

    /// @notice Fetches the price for a specific token using a pair.
    /// @param _token0 Token0 of the pair.
    /// @param _token1 Token1 of the pair.
    /// @return price Price of the token in the form of how much token1 a unit of token0 is worth.
    /// @return lastUpdateTimestamp Timestamp of the latest price update.
    function getPriceForToken(address _token0, address _token1)
        external
        view
        override
        returns (uint256 price, uint32 lastUpdateTimestamp)
    {
        (price, lastUpdateTimestamp) = _getPrice(_token0, _token1);
    }

    /// @notice Sets the price source for a token pair.
    /// @param _token0 Token0 of the pair.
    /// @param _token1 Token1 of the pair.
    /// @param _source Target price source of the token.
    /// @param _sourceAddress Address where the price source is at.
    function setTokenPriceSource(address _token0, address _token1, PriceSource _source, address _sourceAddress)
        external
        onlyGovernance
    {
        OracleStorage.layout().tokenPriceSource[_token0][_token1] =
            TokenPriceSource({source: _source, sourceAddress: _sourceAddress});
    }

    /// @notice Indexes token data for Solidly-like pairs.
    /// @param _pairs Pairs to index token data for.
    function indexSolidlyLikePairs(address[] calldata _pairs) external {
        for (uint256 i; i < _pairs.length;) {
            address pair = _pairs[i];
            OracleStorage.layout().pairDataCache[pair] = _getTokenPairData(pair);
            // forgefmt: disable-next-line
            unchecked { ++i; }
        }
    }

    /// @notice Fetches pair token data from storage.
    /// @param _pair Pair to fetcht he token data for.
    /// @return The token data for `_pair`.
    function pairTokenData(address _pair) external view returns (PairTokenData memory) {
        return OracleStorage.layout().pairDataCache[_pair];
    }

    function _getPrice(address _token0, address _token1) internal view returns (uint256, uint32) {
        TokenPriceSource memory source = OracleStorage.layout().tokenPriceSource[_token0][_token1];
        if (source.source == PriceSource.Chainlink) {
            // Handle fetching prices via Chainlink.
            (, int256 price,, uint256 updatedTimestamp,) = IAggregatorV3(source.sourceAddress).latestRoundData();
            uint256 decimals = IAggregatorV3(source.sourceAddress).decimals();
            return (((uint256(price) * 1e18) / (10 ** decimals)), updatedTimestamp.u32());
        } else if (source.source == PriceSource.Twap) {
            // Handle fetching prices via TWAP.
            ISolidlyV1Pair pair = ISolidlyV1Pair(source.sourceAddress);
            PairTokenData memory pairData = OracleStorage.layout().pairDataCache[address(pair)];
            (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestampCurrent) =
                pair.currentCumulativePrices();
            uint256 observations = pair.observationLength();
            (uint256 blockTimestampLast, uint256 reserve0CumulativeLast, uint256 reserve1CumulativeLast) =
                pair.observations(observations - 1);
            if ((blockTimestampCurrent - blockTimestampLast) < 900) {
                (blockTimestampLast, reserve0CumulativeLast, reserve1CumulativeLast) =
                    pair.observations(observations - 2);
            }
            uint256 ts;
            unchecked {
                ts = (blockTimestampCurrent - blockTimestampLast).u32();
            }

            // Calculate reserves using the cumulative prices.
            uint112 reserve0;
            uint112 reserve1;
            unchecked {
                reserve0 = ((reserve0Cumulative - reserve0CumulativeLast) / ts).u112();
                reserve1 = ((reserve1Cumulative - reserve1CumulativeLast) / ts).u112();
            }

            uint256 price = (
                (((reserve1 * 1e18) * (10 ** (18 - pairData.token1Decimals))) / reserve0)
                    / (10 ** (18 - pairData.token0Decimals))
            );
            return (price, ts.u32());
        } else {
            // Theoretically, this line will always be unreachable.
            return (1e18, block.timestamp.u32());
        }
    }

    function _getTokenPairData(address _pair) internal view returns (PairTokenData memory) {
        PairTokenData memory cachedPairData = OracleStorage.layout().pairDataCache[_pair];
        if (cachedPairData.token0 != address(0)) {
            return cachedPairData;
        } else {
            (address token0, address token1) = ISolidlyV1Pair(_pair).tokens();
            uint8 token0Decimals = IERC20Metadata(token0).decimals();
            uint8 token1Decimals = IERC20Metadata(token1).decimals();
            return PairTokenData({
                token0: token0,
                token1: token1,
                token0Decimals: token0Decimals,
                token1Decimals: token1Decimals
            });
        }
    }
}
