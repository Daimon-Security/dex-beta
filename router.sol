// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*───────────────────────────────────────────────────────────────
███╗   ██╗ ██████╗ ██╗   ██╗ █████╗ 
████╗  ██║██╔═══██╗██║   ██║██╔══██╗
██╔██╗ ██║██║   ██║██║   ██║███████║
██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══██║
██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║
╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝
           CHAINOVA DEX – Router (V2 style)
───────────────────────────────────────────────────────────────*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/* ────────────────  Interfaces mínimas  ──────────────── */
interface IWrappedNative {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address, uint256) external returns (bool);
}

interface IChainovaFactory {
    function getPair(address, address) external view returns (address);
    function createPair(address, address) external returns (address);
}

interface IChainovaPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function mint(address) external returns (uint);
    function burn(address) external returns (uint amount0, uint amount1);
    function swap(uint, uint, address, bytes calldata) external;
}

/* ────────────────  Router  ──────────────── */
contract ChainovaRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable WNATIVE;

    constructor(address _factory, address _wnative) {
        require(_factory != address(0) && _wnative != address(0), "ZERO_ADDR");
        factory  = _factory;
        WNATIVE  = _wnative;
    }

    /*────────────────────── Helpers ─────────────────────*/
    function _sort(address a, address b) internal pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }

    function _pairFor(address a, address b) internal view returns (address) {
        (address t0, address t1) = _sort(a, b);
        return IChainovaFactory(factory).getPair(t0, t1);
    }

    function _reserves(address a, address b) internal view returns (uint112 rA, uint112 rB) {
        address pair = _pairFor(a, b);
        (address t0,) = _sort(a, b);
        (uint112 r0, uint112 r1,) = IChainovaPair(pair).getReserves();
        (rA, rB) = a == t0 ? (r0, r1) : (r1, r0);
    }

    function _quote(uint amtA, uint112 resA, uint112 resB) internal pure returns (uint) {
        require(amtA > 0 && resA > 0 && resB > 0, "QUOTE_ERR");
        return (amtA * resB) / resA;
    }

    function _getAmountOut(uint amtIn, uint112 resIn, uint112 resOut) internal pure returns (uint) {
        uint amtInWithFee = amtIn * 997;
        return (amtInWithFee * resOut) / (resIn * 1000 + amtInWithFee);
    }

    /*────────────────  Liquidez internals  ───────────────*/
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amtADes,
        uint amtBDes
    ) internal returns (uint amtA, uint amtB, address pair) {
        pair = _pairFor(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IChainovaFactory(factory).createPair(tokenA, tokenB);
        }
        (uint112 resA, uint112 resB) = _reserves(tokenA, tokenB);
        if (resA == 0 && resB == 0) {
            (amtA, amtB) = (amtADes, amtBDes);
        } else {
            uint amtBOptimal = _quote(amtADes, resA, resB);
            if (amtBOptimal <= amtBDes) {
                (amtA, amtB) = (amtADes, amtBOptimal);
            } else {
                uint amtAOptimal = _quote(amtBDes, resB, resA);
                (amtA, amtB) = (amtAOptimal, amtBDes);
            }
        }
    }

    /*────────────────────── Liquidez ─────────────────────*/
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amtADes,
        uint amtBDes
    ) external nonReentrant returns (uint amtA, uint amtB, uint liquidity) {
        address pair;
        (amtA, amtB, pair) = _addLiquidity(tokenA, tokenB, amtADes, amtBDes);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amtA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amtB);
        liquidity = IChainovaPair(pair).mint(msg.sender);
    }

    function addLiquidityETH(
        address token,
        uint amtTokenDesired
    ) external payable nonReentrant returns (uint amtToken, uint amtETH, uint liquidity) {
        (amtToken, amtETH,) = _addLiquidity(token, WNATIVE, amtTokenDesired, msg.value);
        IERC20(token).safeTransferFrom(msg.sender, _pairFor(token, WNATIVE), amtToken);
        IWrappedNative(WNATIVE).deposit{value: amtETH}();
        assert(IWrappedNative(WNATIVE).transfer(_pairFor(token, WNATIVE), amtETH));
        liquidity = IChainovaPair(_pairFor(token, WNATIVE)).mint(msg.sender);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity
    ) public nonReentrant returns (uint amtA, uint amtB) {
        address pair = _pairFor(tokenA, tokenB);
        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (uint amt0, uint amt1) = IChainovaPair(pair).burn(msg.sender);
        (address token0,) = _sort(tokenA, tokenB);
        (amtA, amtB) = tokenA == token0 ? (amt0, amt1) : (amt1, amt0);
    }

    function removeLiquidityETH(
        address token,
        uint liquidity
    ) external nonReentrant returns (uint amtToken, uint amtETH) {
        (amtToken, amtETH) = this.removeLiquidity(token, WNATIVE, liquidity);
        IWrappedNative(WNATIVE).withdraw(amtETH);
        IERC20(token).safeTransfer(msg.sender, amtToken);
        payable(msg.sender).transfer(amtETH);
    }

    /*────────────────────── Swaps ─────────────────────*/
    function _swapSingle(
        uint amtIn,
        address tokenIn,
        address tokenOut,
        address to
    ) internal returns (uint amtOut) {
        address pair = _pairFor(tokenIn, tokenOut);
        (address token0,) = _sort(tokenIn, tokenOut);
        (uint112 resIn, uint112 resOut) = _reserves(tokenIn, tokenOut);
        amtOut = _getAmountOut(amtIn, resIn, resOut);
        IERC20(tokenIn).safeTransferFrom(msg.sender, pair, amtIn);
        (uint amt0Out, uint amt1Out) = tokenIn == token0 ? (uint(0), amtOut) : (amtOut, uint(0));
        IChainovaPair(pair).swap(amt0Out, amt1Out, to, "");
    }

    function swapExactTokensForTokens(
        uint amtIn,
        address tokenIn,
        address tokenOut,
        address to
    ) external nonReentrant returns (uint amtOut) {
        amtOut = _swapSingle(amtIn, tokenIn, tokenOut, to);
    }

    function swapExactETHForTokens(address tokenOut, address to) external payable nonReentrant returns (uint amtOut) {
        require(msg.value > 0, "NO_ETH");
        IWrappedNative(WNATIVE).deposit{value: msg.value}();
        amtOut = _swapSingle(msg.value, WNATIVE, tokenOut, to);
    }

    function swapExactTokensForETH(uint amtIn, address tokenIn, address to) external nonReentrant returns (uint amtOut) {
        amtOut = _swapSingle(amtIn, tokenIn, WNATIVE, address(this));
        IWrappedNative(WNATIVE).withdraw(amtOut);
        payable(to).transfer(amtOut);
    }

    receive() external payable {
        require(msg.sender == WNATIVE, "ONLY_WNATIVE");
    }
}