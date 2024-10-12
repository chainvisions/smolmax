// SPDX-License-Identifier: MIT

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint) external;
}
