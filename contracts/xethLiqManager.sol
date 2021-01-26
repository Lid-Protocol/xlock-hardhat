// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;

import "./interfaces/IXEth.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/libraries/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

contract XethLiqManager is Initializable, OwnableUpgradeSafe {
    IXEth private _xeth;
    IUniswapV2Router02 private _router;
    uint256 private _maxBP;
    IUniswapV2Pair private _pair;
    IUniswapV2Factory private _factory;
    bool private isPairInitialized;

    using SafeMath for uint256;

    function initialize(
        IXEth xeth_,
        IUniswapV2Router02 router_,
        IUniswapV2Factory factory_,
        uint256 maxBP_
    ) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        _xeth = xeth_;
        _router = router_;
        _factory = factory_;
        _maxBP = maxBP_;
    }

    function setMaxBP(uint256 maxBP_) external onlyOwner {
        require(maxBP_ < 10000, "maxBP too large");
        _maxBP = maxBP_;
    }

    function initializePair() external {
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
        rebalance();

        //Increase/Decrease liq
        uint256 currentLockedXeth =
            _xeth.balanceOf(address(_pair)).mul(
                _pair.balanceOf(address(this))
            ) / _pair.totalSupply();
        uint256 expectedLockedXeth =
            currentLockedXeth.add(address(_xeth).balance) / 2;

        if (currentLockedXeth > expectedLockedXeth) {
            uint256 delta = currentLockedXeth.sub(expectedLockedXeth);
            _router.removeLiquidityETH(
                address(_xeth),
                _xeth.balanceOf(address(_pair)).mul(delta) /
                    _pair.totalSupply(),
                delta.sub(1000),
                delta.sub(1000),
                address(this),
                now
            );
            _xeth.deposit{value: address(this).balance}();
            _xeth.transfer(address(0x0), _xeth.balanceOf(address(this)));
        } else if (currentLockedXeth < expectedLockedXeth) {
            uint256 delta = expectedLockedXeth.sub(currentLockedXeth);
            _xeth.xlockerMint(delta.mul(2), address(this));
            _xeth.withdraw(delta);
            _router.addLiquidityETH{value: delta}(
                address(_xeth),
                delta,
                delta,
                delta,
                address(this),
                now
            );
        }
    }

    function rebalance() public onlyOwner {
        uint256 xethReserves = _xeth.balanceOf(address(_pair));
        uint256 wethReserves = IERC20(_router.WETH()).balanceOf(address(_pair));

        address[] memory path = new address[](2);
        if (xethReserves > wethReserves) {
            path[0] = _router.WETH();
            path[1] = address(_xeth);
            uint256 wadDif = xethReserves.sub(wethReserves) / 2;
            _xeth.xlockerMint(wadDif, address(this));
            _xeth.withdraw(wadDif);
            _router.swapExactETHForTokens{value: wadDif}(
                wadDif.sub(1000),
                path,
                address(0x0),
                now
            );
            _xeth.transfer(address(0x0), _xeth.balanceOf(address(this)));
        } else if (xethReserves < wethReserves) {
            path[0] = address(_xeth);
            path[1] = _router.WETH();
            uint256 wadDif = uint256(wethReserves - xethReserves) / 2;
            _xeth.xlockerMint(wadDif, address(this));
            _xeth.withdraw(wadDif);
            _router.swapExactTokensForETH(
                wadDif,
                wadDif.sub(1000),
                path,
                address(this),
                now
            );
            _xeth.deposit{value: address(this).balance}();
            _xeth.transfer(address(0x0), _xeth.balanceOf(address(this)));
        }
    }
}
