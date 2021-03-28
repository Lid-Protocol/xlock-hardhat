// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;

import "./interfaces/IXEth.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/libraries/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

contract XethLiqManager is Initializable, OwnableUpgradeSafe {
    IXEth private _xeth;
    IUniswapV2Router02 private _router;
    IUniswapV2Pair private _pair;
    IUniswapV2Factory private _factory;
    uint256 private _maxBP;
    uint256 private _maxLiq;
    bool private isPairInitialized;

    using SafeMath for uint256;

    function initialize(
        IXEth xeth_,
        IUniswapV2Router02 router_,
        IUniswapV2Factory factory_,
        uint256 maxBP_,
        uint256 maxLiq_
    ) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        _xeth = xeth_;
        _router = router_;
        _factory = factory_;
        _maxBP = maxBP_;
        _maxLiq = maxLiq_;
    }

    receive() external payable {}

    function setMaxBP(uint256 maxBP_) external onlyOwner {
        require(maxBP_ < 10000, "maxBP too large");
        _maxBP = maxBP_;
    }

    function setMaxLiq(uint256 maxLiq_) external onlyOwner {
        _maxLiq = maxLiq_;
    }

    function initializePair() external onlyOwner {
        require(!isPairInitialized, "weth/xeth pair already initialized");
        isPairInitialized = true;
        uint256 wadXeth = address(_xeth).balance.mul(_maxBP) / 10000;
        _xeth.xlockerMint(wadXeth.mul(2), address(this));
        _xeth.withdraw(wadXeth);

        _xeth.approve(address(_router), uint256(-1));
        _router.addLiquidityETH{value: wadXeth}(
            address(_xeth),
            wadXeth,
            wadXeth,
            wadXeth,
            address(this),
            now
        );

        _pair = IUniswapV2Pair(
            _factory.getPair(address(_xeth), _router.WETH())
        );
    }

    function updatePair() external onlyOwner {
        require(address(_xeth).balance < 150 ether, "xeth has too much ETH");
        rebalance();

        uint256 currentLockedXeth =
            _xeth.balanceOf(address(_pair)).mul(
                _pair.balanceOf(address(this))
            ) / _pair.totalSupply();

        uint256 delta;
        if (currentLockedXeth > 150 ether) {
            delta = 150 ether - address(_xeth).balance;
        } else {
            delta = currentLockedXeth / 2;
        }

        _router.removeLiquidityETH(
            address(_xeth),
            _pair.totalSupply().mul(delta) / _xeth.balanceOf(address(_pair)),
            delta.sub(0.1 ether),
            delta.sub(0.1 ether),
            address(this),
            now
        );
        _xeth.deposit{value: address(this).balance}();
        _xeth.transfer(address(0x0), _xeth.balanceOf(address(this)));
    }

    function rebalance() public onlyOwner {
        uint256 xethReserves = _xeth.balanceOf(address(_pair));
        uint256 wethReserves = IERC20(_router.WETH()).balanceOf(address(_pair));

        address[] memory path = new address[](2);
        if (xethReserves.sub(0.01 ether) > wethReserves) {
            path[0] = _router.WETH();
            path[1] = address(_xeth);
            uint256 wadDif =
                Babylonian.sqrt(xethReserves.mul(wethReserves)).sub(
                    wethReserves
                );
            _xeth.xlockerMint(wadDif, address(this));
            _xeth.withdraw(wadDif);
            _router.swapExactETHForTokens{value: wadDif}(
                wadDif.sub(0.01 ether),
                path,
                address(0x0),
                now
            );
            _xeth.transfer(address(0x0), _xeth.balanceOf(address(this)));
        } else if (xethReserves.add(0.01 ether) < wethReserves) {
            path[0] = address(_xeth);
            path[1] = _router.WETH();
            uint256 wadDif =
                Babylonian.sqrt(xethReserves.mul(wethReserves)).sub(
                    xethReserves
                );
            _xeth.xlockerMint(wadDif, address(this));
            _router.swapExactTokensForETH(
                wadDif,
                wadDif.sub(0.01 ether),
                path,
                address(this),
                now
            );
            _xeth.deposit{value: address(this).balance}();
            _xeth.transfer(address(0x0), _xeth.balanceOf(address(this)));
        }
    }
}
