// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;
// Copyright (C) udev 2020

import "../ERC20/IERC20.sol";

interface IXEth is IERC20 {
    function deposit() external payable;

    function xlockerMint(uint256 wad, address dst) external;

    function withdraw(uint256 wad) external;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint256);

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event XlockerMint(uint256 wad, address dst);
}
