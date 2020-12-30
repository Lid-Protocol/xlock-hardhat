// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;
// Copyright (C) 2015, 2016, 2017 Dapphub / adapted by udev 2020

import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "./interfaces/IXEth.sol";

contract XETH is IXEth, AccessControlUpgradeSafe {
    string public override name;
    string public override symbol;
    uint8 public override decimals;
    uint256 public override totalSupply;

    bytes32 public constant XETH_LOCKER_ROLE = keccak256("XETH_LOCKER_ROLE");
    bytes32 public immutable PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    mapping(address => uint256) public override balanceOf;
    mapping(address => uint256) public override nonces;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor() public {
        name = "xlock.eth Wrapped Ether";
        symbol = "XETH";
        decimals = 18;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable override {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function grantXethLockerRole(address account) external {
        grantRole(XETH_LOCKER_ROLE, account);
    }

    function revokeXethLockerRole(address account) external {
        revokeRole(XETH_LOCKER_ROLE, account);
    }

    function xlockerMint(uint256 wad, address dst) external override {
        require(
            hasRole(XETH_LOCKER_ROLE, msg.sender),
            "Caller is not xeth locker"
        );
        balanceOf[dst] += wad;
        totalSupply += wad;
        emit Transfer(address(0), dst, wad);
    }

    function withdraw(uint256 wad) external override {
        require(balanceOf[msg.sender] >= wad, "!balance");
        balanceOf[msg.sender] -= wad;
        totalSupply -= wad;
        (bool success, ) = msg.sender.call{value: wad}("");
        require(success, "!withdraw");
        emit Withdrawal(msg.sender, wad);
    }

    function _approve(
        address src,
        address guy,
        uint256 wad
    ) internal {
        allowance[src][guy] = wad;
        emit Approval(src, guy, wad);
    }

    function approve(address guy, uint256 wad)
        external
        override
        returns (bool)
    {
        _approve(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad)
        external
        override
        returns (bool)
    {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) public override returns (bool) {
        require(balanceOf[src] >= wad, "!balance");

        if (src != msg.sender && allowance[src][msg.sender] != uint256(-1)) {
            require(allowance[src][msg.sender] >= wad, "!allowance");
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(block.timestamp <= deadline, "XETH::permit: Expired permit");

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 DOMAIN_SEPARATOR =
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256(bytes("1")),
                    chainId,
                    address(this)
                )
            );

        bytes32 hashStruct =
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    owner,
                    spender,
                    value,
                    nonces[owner]++,
                    deadline
                )
            );

        bytes32 hash =
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hashStruct)
            );

        address signer = ecrecover(hash, v, r, s);
        require(
            signer != address(0) && signer == owner,
            "XETH::permit: invalid permit"
        );

        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}
