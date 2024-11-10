// // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Panic} from "@openzeppelin/utils/Panic.sol";
import {IERC20Extended} from "./interfaces/IERC20Extended.sol";
import {_require, Errors} from "./libraries/Errors.sol";
import {VoterAccounting} from "./VoterAccounting.sol";
import {VestingAccounting} from "./VestingAccounting.sol";

/// @title Emissions Controller
/// @author Chainvisions
/// @notice The central contract used for managing token emissions.

contract EmissionsController {
    using Panic for uint256;
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

    /// @notice LIME token contract.
    IERC20Extended public immutable LIME;

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

    /// @notice Emitted when LIME rewards are issued.
    /// @param vault Vault that issued the LIME tokens.
    /// @param recipient Recipient of the LIME rewards.
    /// @param rewardAmount Amount of LIME tokens rewarded.
    /// @param penalty Whether or not the recipient opted for the 50% penalty.
    event RewardsIssued(
        address indexed vault,
        address indexed recipient,
        uint256 rewardAmount,
        bool penalty
    );

    /// @notice Emitted when a new LIME rewards vest is created.
    /// @param recipient User that received the LIME vest.
    /// @param amountLocked Amount of LIME tokens locked.
    /// @param unlockTime Timestamp in which the tokens will be unlocked at.
    event LockCreated(
        address indexed recipient,
        uint256 amountLocked,
        uint256 unlockTime
    );

    /// @notice Emitted when vested LIME rewards are vested.
    /// @param recipient Recipient of the LIME tokens.
    /// @param amount Amount of LIME tokens unlocked.
    event RewardsVested(address indexed recipient, uint256 amount);

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

    /// @notice Issues LIME rewards to a specified recipient. This is called by vaults on reward claim.
    /// @param _recipient Recipient of the LIME rewards.
    /// @param _amount Amount of LIME tokens rewarded to the recipient.
    /// @param _penalty Whether or not the recipient has opted into instant rewards or vesting.
    function issueRewards(
        address _recipient,
        uint256 _amount,
        bool _penalty
    ) external {
        _require(emmitableVaults[msg.sender], Errors.VAULT_NOT_EMITTABLE);

        // Mint devshare and distribute LIME tokens.
        LIME.mint(address(0), ((_amount * 500) / 10000)); // TODO: Devshare address + calcs
        if (_penalty) {
            // Distribute rewards at a 50% haircut.
            LIME.mint(_recipient, _amount / 2);
            LIME.mint(address(this), _amount / 2);
            // TODO: Distribute the other half to veLIME.
        } else {
            // Create LIME vest.
            LIME.mint(address(this), _amount);
            VestingAccounting._issueLock(_recipient, _amount);
            emit LockCreated(_recipient, _amount, block.timestamp + 90 days);
        }

        emit RewardsIssued(msg.sender, _recipient, _amount, _penalty);
    }

    /// @notice Claims vested LIME rewards from the user's finished locks.
    function unlockVestedRewards() external {
        uint256 unlocked = uint256(VestingAccounting._freeLocks(msg.sender));
        LIME.transfer(msg.sender, unlocked);
        emit RewardsVested(msg.sender, unlocked);
    }

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
        latestStats.endedAt = block.timestamp.toUint32();
        records.push(latestStats);
        delete emissionInfo;

        // Calculate new emissions bonus.
        uint256 targetBonus = ((latestStats.totalDistributed *
            bonusMultiplier) / 10000);
        totalBonus = targetBonus;
    }

    /// @dev LIME transfer method that enforces an invariant to ensure that locked LIME doesn't get sent.
    /// If an excessive amount of tokens are transferred, ever, this will panic.
    function _secureTransfer(address _to, uint256 _amount) internal {
        uint256 limeBalance = LIME.balanceOf(address(this));
        uint256 vestingLime = VestingAccounting.layout().totalLocked;
        if (
            _amount >= vestingLime &&
            (limeBalance < vestingLime || limeBalance - _amount < vestingLime)
        ) {
            Panic.GENERIC.panic();
        }
        LIME.transfer(_to, _amount);
    }
}
