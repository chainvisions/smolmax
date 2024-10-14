// // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/// @title Emissions Controller
/// @author Chainvisions
/// @notice The central contract used for managing token emissions.

contract EmissionsController {
    using SafeCastLib for uint256;

    /// @notice Data structure for storing stats on epoch periods.
    /// @dev Built to be packed into one slot to save on R/W costs.
    struct EpochStatistic {
        /// @notice Total amount of tokens distributed (minus bonuses).
        uint112 totalDistributed;
        /// @notice Timestamp  in which the epoch ended.
        uint32 endedAt;
    }

    /// @notice WETH (or other wrapped native) token contract.
    IERC20 public immutable WETH;

    /// @notice Fixed length that epochs last for.
    uint256 public constant EPOCH_LENGTH = 7 days;

    /// @notice Start time of the latest epoch.
    uint256 public latestEpochAt;

    /// @notice Base rate of tokens per x earned.
    uint256 public baseEmissionRate;

    /// @notice Multiplier (in BPS) used to calculate the bonus.
    uint256 public bonusMultiplier = 20000;

    /// @notice Total bonus tokens distributed every epoch.
    uint256 public totalBonus;

    /// @notice Total bonus weights to distribute every epoch.
    uint256 public totalWeights;

    /// @notice Records of each epoch's stats.
    EpochStatistic[] public records;

    /// @notice Stats of the current epoch.
    EpochStatistic public emissionInfo;

    /// @notice Vaults that are permitted to emit tokens.
    mapping(address => bool) public emmitableVaults;

    /// @notice Amount of weights held by a specific vault.
    mapping(address => uint256) public vaultWeight;

    /// @notice Emissions Controller constructor.
    /// @param _weth WETH token contract. Used for calculating emissions.
    constructor(IERC20 _weth) {
        WETH = _weth;
    }

    /// @notice Collects protocol fees and swaps them into WETH. Minting new tokens to be emitted.
    /// @param _token Token collected to be swappped.
    /// @param _amount Amount of the token to collect.
    /// @return imbursement The amount of new tokens minted to the vault for distribution.
    function realizeProfit(
        address _token,
        uint256 _amount
    ) external returns (uint256 imbursement) {}

    /// @notice Casts a vote to allocate emissions to specific vaults.
    /// @param _vaults Vaults to vote towards.
    /// @param _weights Weights to allocate to the vaults.
    function vote(
        address[] calldata _vaults,
        uint256[] calldata _weights
    ) external {
        // Validate vote.
        uint256 weightSum;
        for (uint256 i; i < _vaults.length; ) {
            weightSum += _weights[i];
            unchecked {
                ++i;
            }
        }
        _require(weightSum == 10000, Errors.MALFORMED_VOTE);

        // ^ So like, it is typically common practice to also check lengths. But uhh...
        // I kinda don't give a fuck and will cheap out here. Why? Well here is my logic on record:
        // 1) If len(_vaults) > len(_weights) then it'll automatically revert due to accessing out of bounds.
        // 2) If len(_weights) > len(_vaults) then well it could *theoretically* end up valid. This would, however,
        // have to mean that all of the weights in those few vaults add up to 10000, which is what we want anyways.
        // It'd also still allocate to whatever specified vaults, there'd just have been some useless weights. Who cares. It's their wasted gas.
        // So all in all, it's a pretty easy saving avoiding all that check bs. 99% of people would use a UI anyways and *not* fuck up.
        // So yeah 👍

        // Calculate weight to allocate and cast vote.
    }

    /// @notice Closes the current epoch and allocates the bonus weights.
    function close() external {
        // Bookkeeping.
        EpochStatistic memory latestStats = emissionInfo;
        latestStats.endedAt = block.timestamp;
        records.push(latestStats);
        delete emissionInfo;

        // Calculate new emissions bonus.
        uint256 targetBonus = ((latestStats.totalDistributed *
            bonusMultiplier) / 10000);
        totalBonus = targetBonus;
    }
}
