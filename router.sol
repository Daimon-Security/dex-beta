// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IChainovaFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IChainovaPair {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(uint amount0Out, uint amount1Out, address to) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract ChainovaRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable WNATIVE;

    constructor(address _factory, address _WNATIVE) {
        factory = _factory;
        WNATIVE = _WNATIVE;
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired
    ) internal returns (uint amountA, uint amountB, address pair) {
        pair = IChainovaFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IChainovaFactory(factory).createPair(tokenA, tokenB);
        }

        (uint reserveA, uint reserveB) = _getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired, "ChainovaRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _addLiquidityPublic(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired
    ) internal returns (uint amountA, uint amountB, address pair, uint liquidity) {
        (amountA, amountB, pair) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired);

        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);

        liquidity = IChainovaPair(pair).mint(msg.sender);
    }

    // Add liquidity with approve (no permit)
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired
    ) external nonReentrant returns (uint amountA, uint amountB, address pair, uint liquidity) {
        return _addLiquidityPublic(tokenA, tokenB, amountADesired, amountBDesired);
    }

    // Remove liquidity with approve
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity
    ) public nonReentrant returns (uint amountA, uint amountB) {
        address pair = IChainovaFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "ChainovaRouter: PAIR_NOT_EXISTS");

        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (amountA, amountB) = IChainovaPair(pair).burn(msg.sender);
    }

    // Swaps

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to
    ) external nonReentrant returns (uint[] memory amounts) {
        require(path.length >= 2, "ChainovaRouter: INVALID_PATH");
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "ChainovaRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(path[0]).safeTransferFrom(msg.sender, _pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to
    ) external payable nonReentrant returns (uint[] memory amounts) {
        require(path.length >= 2, "ChainovaRouter: INVALID_PATH");
        require(path[0] == WNATIVE, "ChainovaRouter: PATH_MUST_START_WITH_WNATIVE");

        amounts = getAmountsOut(msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "ChainovaRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        (bool success, ) = payable(WNATIVE).call{value: msg.value}("");
        require(success, "ChainovaRouter: WNATIVE_WRAP_FAILED");

        IERC20(WNATIVE).safeTransfer(_pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to
    ) external nonReentrant returns (uint[] memory amounts) {
        require(path.length >= 2, "ChainovaRouter: INVALID_PATH");
        require(path[path.length - 1] == WNATIVE, "ChainovaRouter: PATH_MUST_END_WITH_WNATIVE");

        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "ChainovaRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(path[0]).safeTransferFrom(msg.sender, _pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));

        (bool success, ) = payable(to).call{value: amounts[amounts.length - 1]}("");
        require(success, "ChainovaRouter: ETH_TRANSFER_FAILED");
    }

    // Internal swap helper
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint i = 0; i < path.length - 1; i++) {
            address input = path[i];
            address output = path[i + 1];
            address pair = _pairFor(input, output);

            (address token0,) = sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i == path.length - 2 ? _to : _pairFor(output, path[i + 2]);
            IChainovaPair(pair).swap(amount0Out, amount1Out, to);
        }
    }

    // Helpers

    function _pairFor(address tokenA, address tokenB) internal view returns (address pair) {
        pair = IChainovaFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "ChainovaRouter: PAIR_NOT_EXISTS");
    }

    function _getReserves(address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        address pair = IChainovaFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "ChainovaRouter: PAIR_NOT_EXISTS");
        (uint112 reserve0, uint112 reserve1,) = IChainovaPair(pair).getReserves();
        (address token0,) = sortTokens(tokenA, tokenB);
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
        require(amountA > 0, "ChainovaRouter: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "ChainovaRouter: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, "ChainovaRouter: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ChainovaRouter: ZERO_ADDRESS");
    }

    function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, "ChainovaRouter: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i = 0; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = _getReserves(path[i], path[i + 1]);
            require(reserveIn > 0 && reserveOut > 0, "ChainovaRouter: INSUFFICIENT_LIQUIDITY");
            uint amountInWithFee = amounts[i] * 997; // 0.3% fee
            uint numerator = amountInWithFee * reserveOut;
            uint denominator = (reserveIn * 1000) + amountInWithFee;
            amounts[i + 1] = numerator / denominator;
        }
    }

    receive() external payable {
        require(msg.sender == WNATIVE, "ChainovaRouter: ONLY_WNATIVE");
    }
}
