// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "./ERC20/ERC20Blacklist.sol";
import "./ERC20/ERC20TransferTax.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IXEth.sol";
import "./interfaces/IXLocker.sol";

contract XLOCKER is Initializable, IXLocker, OwnableUpgradeSafe {
    using SafeMath for uint256;

    IUniswapV2Router02 private _uniswapRouter;
    IXEth private _xeth;
    address private _uniswapFactory;

    address public _sweepReceiver;
    uint256 public _maxXEthWad;
    uint256 public _maxTokenWad;

    mapping(address => uint256) public pairSwept;
    mapping(address => bool) public pairRegistered;
    address[] public allRegisteredPairs;
    uint256 public totalRegisteredPairs;

    mapping(address => address) public pairBlacklistManager;

    function initialize(
        IXEth xeth_,
        address sweepReceiver_,
        uint256 maxXEthWad_,
        uint256 maxTokenWad_,
        IUniswapV2Router02 uniswapRouter_,
        address uniswapFactory_
    ) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        _uniswapRouter = uniswapRouter_;
        _uniswapFactory = uniswapFactory_;
        _xeth = xeth_;
        _sweepReceiver = sweepReceiver_;
        _maxXEthWad = maxXEthWad_;
        _maxTokenWad = maxTokenWad_;
    }

    function setSweepReceiver(address sweepReceiver_) external onlyOwner {
        _sweepReceiver = sweepReceiver_;
    }

    function setMaxXEthWad(uint256 maxXEthWad_) external onlyOwner {
        _maxXEthWad = maxXEthWad_;
    }

    function setMaxTokenWad(uint256 maxTokenWad_) external onlyOwner {
        _maxTokenWad = maxTokenWad_;
    }

    function setUniswapRouter(IUniswapV2Router02 uniswapRouter_)
        external
        onlyOwner
    {
        _uniswapRouter = uniswapRouter_;
    }

    function setUniswapFactory(address uniswapFactory_) external onlyOwner {
        _uniswapFactory = uniswapFactory_;
    }

    function launchERC20(
        string calldata name,
        string calldata symbol,
        uint256 wadToken,
        uint256 wadXeth
    ) external override returns (address token_, address pair_) {
        //Checks
        _preLaunchChecks(wadToken, wadXeth);

        //Launch new token
        token_ = address(
            new ERC20Blacklist(name, symbol, wadToken, address(this))
        );

        //Lock symbol/xeth liquidity
        pair_ = _lockLiquidity(wadToken, wadXeth, token_);

        //Register pair for sweeping
        _registerPair(pair_);

        return (token_, pair_);
    }

    function launchERC20Blacklist(
        string calldata name,
        string calldata symbol,
        uint256 wadToken,
        uint256 wadXeth,
        address blacklistManager
    ) external override returns (address token_, address pair_) {
        //Checks
        _preLaunchChecks(wadToken, wadXeth);

        //Launch new token
        token_ = address(
            new ERC20Blacklist(name, symbol, wadToken, address(this))
        );

        //Lock symbol/xeth liquidity
        pair_ = _lockLiquidity(wadToken, wadXeth, token_);

        //Register pair for sweeping
        _registerPair(pair_);

        pairBlacklistManager[pair_] = blacklistManager;

        return (token_, pair_);
    }

    function launchERC20TransferTax(
        string calldata name,
        string calldata symbol,
        uint256 wadToken,
        uint256 wadXeth,
        uint256 taxBips,
        address taxMan
    ) external override returns (address token_, address pair_) {
        //Checks
        _preLaunchChecks(wadToken, wadXeth);
        require(taxBips <= 1000, "taxBips>1000");

        //Launch new token
        ERC20TransferTax token =
            new ERC20TransferTax(
                name,
                symbol,
                wadToken,
                address(this),
                taxBips
            );
        token.setIsTaxed(address(this), false);
        token.transferTaxman(taxMan);
        token_ = address(token);

        //Lock symbol/xeth liquidity
        pair_ = _lockLiquidity(wadToken, wadXeth, token_);

        //Register pair for sweeping
        _registerPair(pair_);

        return (token_, pair_);
    }

    function setBlacklistUniswapBuys(
        address pair,
        address token,
        bool isBlacklisted
    ) external override {
        require(
            msg.sender == pairBlacklistManager[pair],
            "xlocker: sender not blacklist manager for pair."
        );
        ERC20Blacklist(token).setSendBlacklist(pair, isBlacklisted);
    }

    //Sweeps liquidity provider fees for _sweepReceiver
    function sweep(IUniswapV2Pair[] calldata pairs) external {
        require(pairs.length < 256, "pairs.length>=256");
        uint8 i;
        for (i = 0; i < pairs.length; i++) {
            IUniswapV2Pair pair = pairs[i];

            uint256 availableToSweep = sweepAmountAvailable(pair);
            if (availableToSweep != 0) {
                pairSwept[address(pair)] += availableToSweep;
                _xeth.xlockerMint(availableToSweep, _sweepReceiver);
            }
        }
    }

    //Checks pair for sweep amount available
    function sweepAmountAvailable(IUniswapV2Pair pair)
        public
        view
        returns (uint256 amountAvailable)
    {
        require(pairRegistered[address(pair)], "!pairRegistered[pair]");

        bool xethIsToken0 = false;
        IERC20 token;
        if (pair.token0() == address(_xeth)) {
            xethIsToken0 = true;
            token = IERC20(pair.token1());
        } else {
            require(
                pair.token1() == address(_xeth),
                "!pair.tokenX==address(_xeth)"
            );
            token = IERC20(pair.token0());
        }

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) =
            pair.getReserves();

        uint256 burnedLP = pair.balanceOf(address(0));
        uint256 totalLP = pair.totalSupply();

        uint256 reserveLockedXeth =
            uint256(xethIsToken0 ? reserve0 : reserve1).mul(burnedLP) / totalLP;
        uint256 reserveLockedToken =
            uint256(xethIsToken0 ? reserve1 : reserve0).mul(burnedLP) / totalLP;

        uint256 burnedXeth;
        if (reserveLockedToken == token.totalSupply()) {
            burnedXeth = reserveLockedXeth;
        } else {
            burnedXeth = reserveLockedXeth.sub(
                UniswapV2Library.getAmountOut(
                    //Circulating supply, max that could ever be sold (amountIn)
                    token.totalSupply().sub(reserveLockedToken),
                    //Burned token in Uniswap reserves (reserveIn)
                    reserveLockedToken,
                    //Burned xEth in Uniswap reserves (reserveOut)
                    reserveLockedXeth
                )
            );
        }

        return burnedXeth.sub(pairSwept[address(pair)]);
    }

    function _preLaunchChecks(uint256 wadToken, uint256 wadXeth) internal view {
        require(wadToken <= _maxTokenWad, "wadToken>_maxTokenWad");
        require(wadXeth <= _maxXEthWad, "wadXeth>_maxXEthWad");
    }

    function _lockLiquidity(
        uint256 wadToken,
        uint256 wadXeth,
        address token
    ) internal returns (address pair) {
        _xeth.xlockerMint(wadXeth, address(this));

        IERC20(token).approve(address(_uniswapRouter), wadToken);
        _xeth.approve(address(_uniswapRouter), wadXeth);

        pair = _addLiquidity(IERC20(token), IERC20(_xeth), wadToken, wadXeth);

        pairSwept[pair] = wadXeth;
        return pair;
    }

    function _registerPair(address pair) internal {
        pairRegistered[pair] = true;
        allRegisteredPairs.push(pair);
        totalRegisteredPairs = totalRegisteredPairs.add(1);
    }

    function _addLiquidity(
        IERC20 token,
        IERC20 xeth,
        uint256 wadToken,
        uint256 wadXeth
    ) internal returns (address pair) {
        pair = IUniswapV2Factory(_uniswapFactory).createPair(
            address(xeth),
            address(token)
        );
        (uint256 reserve0, uint256 reserve1, ) =
            IUniswapV2Pair(pair).getReserves();
        require(reserve0 == 0 && reserve1 == 0, "Pair already has reserves");

        require(token.transfer(pair, wadToken), "Transfer Failed");
        require(xeth.transfer(pair, wadXeth), "Transfer Failed");
        IUniswapV2Pair(pair).mint(address(0x0));
    }
}
