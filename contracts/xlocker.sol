// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.6;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "./ERC20/SafeMath.sol";
import "./ERC20/ERC20.sol";
import "./ERC20/ERC20TransferTax.sol";
import "./Uniswap/IUniswapV2Pair.sol";
import "./Uniswap/IUniswapV2Router02.sol";
import "./Uniswap/UniswapV2Library.sol";
import "./interfaces/IXeth.sol";
import "./interfaces/IXlocker.sol";

contract XLOCKER is Initializable, IXlocker, OwnableUpgradeSafe {

    using SafeMath for uint;

    IUniswapV2Router02 private _uniswapRouter;
    IXeth private _xeth;
    address private _uniswapFactory;
    
    address private xdev1;
    address private xdev2;
    address private xdev3;

    mapping(address => uint) public pairSwept;
    mapping(address => bool) public pairRegistered;
    address[] public allRegisteredPairs;
    uint public totalRegisteredPairs;

    function initialize(IXeth xeth_) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        _uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        _xeth = xeth_;
    
        xdev1 = 0x73A07158324782a39D2DCd5b8d9160B8E3018B7D;
        xdev2 = 0xd1ccC07177c0c27aB78cF991bA6C4eb4EdC68F31;
        xdev3 = 0xcc2Faea967B5b51151b7B070f6288Ad06f96bA42;
    }
    
    function launchERC20(string calldata name, string calldata symbol, uint wadToken, uint wadXeth) external override returns (address token_, address pair_) {
        //Checks
        _preLaunchChecks(wadToken, wadXeth);

        //Launch new token
        token_ = address(new ERC20(name, symbol, wadToken));

        //Lock symbol/ueth liquidity
        pair_ = _lockLiquidity(wadToken, wadXeth, token_);

        //Register pair for sweeping
        _registerPair(pair_);
        
        return (token_, pair_);
    }
    
    function launchERC20TransferTax(string calldata name, string calldata symbol, uint wadToken, uint wadXeth, uint taxBips, address taxMan) external override returns (address token_, address pair_) {
        //Checks
        _preLaunchChecks(wadToken, wadXeth);
        require(taxBips <= 1000, "taxBips>1000");

        //Launch new token
        ERC20TransferTax token = new ERC20TransferTax(name, symbol, wadToken, address(this), taxBips);
        token.setIsTaxed(address(this), false);
        token.transferTaxman(taxMan);
        token_ = address(token);

        //Lock symbol/ueth liquidity
        pair_ = _lockLiquidity(wadToken, wadXeth, token_);

        //Register pair for sweeping
        _registerPair(pair_);
        
        return (token_, pair_);
    }

    //Sweeps liquidity provider fees for xdev
    function sweep(IUniswapV2Pair[] calldata pairs) external {
        require(pairs.length < 256, "pairs.length>=256");
        uint8 i;
        for(i = 0; i < pairs.length; i++) {
            IUniswapV2Pair pair = pairs[i];

            uint availableToSweep = sweepAmountAvailable(pair);
            if(availableToSweep != 0){
                pairSwept[address(pair)] += availableToSweep;
                uint sweepPerXdev = availableToSweep/4;
                _xeth.xlockerMint(sweepPerXdev, xdev1);
                _xeth.xlockerMint(sweepPerXdev*2, xdev2);
                _xeth.xlockerMint(sweepPerXdev, xdev3);
            }

        }
    }

    //Checks pair for sweep amount available
    function sweepAmountAvailable(IUniswapV2Pair pair) public view returns (uint amountAvailable) {
        require(pairRegistered[address(pair)], "!pairRegistered[pair]");
        
        bool xethIsToken0 = false;
        IERC20 token;
        if(pair.token0() == address(_xeth)) {
            xethIsToken0 = true;
            token = IERC20(pair.token1());
        } else {
            require(pair.token1() == address(_xeth), "!pair.tokenX==address(_xeth)");
            token = IERC20(pair.token0());
        }

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();

        uint burnedLP = pair.balanceOf(address(0));
        uint totalLP = pair.totalSupply();

        uint reserveLockedXeth = uint(xethIsToken0 ? reserve0 : reserve1).mul(burnedLP).div(totalLP);
        uint reserveLockedToken = uint(xethIsToken0 ? reserve1 : reserve0).mul(burnedLP).div(totalLP);

        uint burnedXeth;
        if(reserveLockedToken == token.totalSupply()) {
            burnedXeth = reserveLockedXeth;
        }else{
            burnedXeth = reserveLockedXeth.sub(
                UniswapV2Library.getAmountOut(
                    //Circulating supply, max that could ever be sold (amountIn)
                    token.totalSupply().sub(reserveLockedToken),
                    //Burned token in Uniswap reserves (reserveIn)
                    reserveLockedToken,
                    //Burned uEth in Uniswap reserves (reserveOut)
                    reserveLockedXeth
                )
            );
        }

        return burnedXeth.sub(pairSwept[address(pair)]);
    }

    function _preLaunchChecks(uint wadToken, uint wadXeth) internal pure {
        require(wadToken <= 2 ** 100, "wadToken>2**100");
        require(wadXeth <= 2 ** 100, "wadXeth>2**100");
    }

    function _lockLiquidity(uint wadToken, uint wadXeth, address token) internal returns (address pair) {
        _xeth.xlockerMint(wadXeth, address(this));

        IERC20(token).approve(address(_uniswapRouter), wadToken);
        _xeth.approve(address(_uniswapRouter), wadXeth);

        _uniswapRouter.addLiquidity(
            token,
            address(_xeth),
            wadToken,
            wadXeth,
            wadToken,
            wadXeth,
            address(0),
            now
        );

        pair = UniswapV2Library.pairFor(_uniswapFactory, token, address(_xeth));
        pairSwept[pair] = wadXeth;
        return pair;
    }

    function _registerPair(address pair) internal {
        pairRegistered[pair] = true;
        allRegisteredPairs.push(pair);
        totalRegisteredPairs = totalRegisteredPairs.add(1);
    }
}