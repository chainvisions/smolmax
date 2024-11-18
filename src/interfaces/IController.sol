// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IERC20Extended} from "./IERC20Extended.sol";

interface IController {
    function whitelist(address) external view returns (bool);
    function feeExemptAddresses(address) external view returns (bool);
    function keepers(address) external view returns (bool);
    function referralCode(string memory) external view returns (address);
    function referrer(address) external view returns (address);
    function referralInfo(address) external view returns (address, string memory);

    function doHardWork(address) external;
    function batchDoHardWork(address[] memory) external;

    function salvage(address, uint256) external;
    function salvageStrategy(address, address, uint256) external;

    function mintTokens(address, uint256) external;
    function createReferralCode(bytes32, string memory) external payable;
    function registerReferral(string memory, address) external;

    function limeToken() external view returns (IERC20Extended);
    function profitSharingNumerator() external view returns (uint256);
    function profitSharingDenominator() external view returns (uint256);
}
