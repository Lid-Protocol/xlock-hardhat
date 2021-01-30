// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;

// Copyright (C) udev 2020
interface IXLocker {
    function launchERC20(
        string calldata name,
        string calldata symbol,
        uint256 wadToken,
        uint256 wadXeth
    ) external returns (address token_, address pair_);

    function launchERC20TransferTax(
        string calldata name,
        string calldata symbol,
        uint256 wadToken,
        uint256 wadXeth,
        uint256 taxBips,
        address taxMan
    ) external returns (address token_, address pair_);

    function launchERC20TransferBlacklistCheckpointWhitelist(
        string calldata name,
        string calldata symbol,
        uint256 wadToken,
        uint256 wadXeth,
        address blacklistManager,
        address whitelistManager
    ) external returns (address token_, address pair_);

    function setBlacklistUniswapBuys(
        address pair,
        address token,
        bool isBlacklisted
    ) external;
}
