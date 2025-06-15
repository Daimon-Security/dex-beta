// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Chainova Pair (Uniswap V2 style)
 * @notice Liquidity pool de dos tokens, maneja swaps, mint, burn y reserves en un DEX tipo Uniswap V2.
 * @author CHAINOVA DEVS
 */

 /*───────────────────────────────────────────────────────────────
███╗   ██╗ ██████╗ ██╗   ██╗ █████╗ 
████╗  ██║██╔═══██╗██║   ██║██╔══██╗
██╔██╗ ██║██║   ██║██║   ██║███████║
██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══██║
██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║
╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝
           CHAINOVA DEX – Router (V2 style)
───────────────────────────────────────────────────────────────*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IChainovaFactory {
    function feeTo() external view returns (address);
}

contract ChainovaPair is ERC20("Chainova LP", "CNV-LP"), ReentrancyGuard {
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public kLast;

    address public factory;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address to);
    event Swap(address indexed sender, uint amountIn0, uint amountIn1, uint amountOut0, uint amountOut1, address to);
    event Sync(uint112 reserve0, uint112 reserve1);

    modifier onlyFactory() {
        require(msg.sender == factory, "ONLY_FACTORY");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external onlyFactory {
        require(token0 == address(0) && token1 == address(0), "ALREADY_INITIALIZED");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function _update(uint balance0, uint balance1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp % 2**32);
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external nonReentrant returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - 1000;
            _mint(address(0), 1000); // evitar ataques de liquidez mínima
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY");
        _mint(to, liquidity);

        _update(balance0, balance1);
        kLast = uint(reserve0) * reserve1;

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external nonReentrant returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint liquidity = balanceOf(address(this));

        uint _totalSupply = totalSupply();
        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_AMOUNT");
        _burn(address(this), liquidity);
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);
        kLast = uint(reserve0) * reserve1;

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint amountOut0, uint amountOut1, address to) external nonReentrant {
        require(amountOut0 > 0 || amountOut1 > 0, "INSUFFICIENT_OUTPUT");

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amountOut0 < _reserve0 && amountOut1 < _reserve1, "INSUFFICIENT_LIQUIDITY");

        if (amountOut0 > 0) IERC20(token0).transfer(to, amountOut0);
        if (amountOut1 > 0) IERC20(token1).transfer(to, amountOut1);

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint amountIn0 = balance0 > _reserve0 - amountOut0 ? balance0 - (_reserve0 - amountOut0) : 0;
        uint amountIn1 = balance1 > _reserve1 - amountOut1 ? balance1 - (_reserve1 - amountOut1) : 0;

        require(amountIn0 > 0 || amountIn1 > 0, "INSUFFICIENT_INPUT");

        // aplicar fee 0.3%
        uint balance0Adjusted = (balance0 * 1000) - (amountIn0 * 3);
        uint balance1Adjusted = (balance1 * 1000) - (amountIn1 * 3);

        require(balance0Adjusted * balance1Adjusted >= uint(_reserve0) * _reserve1 * 1_000_000, "K_INVARIANT");

        _update(balance0, balance1);

        emit Swap(msg.sender, amountIn0, amountIn1, amountOut0, amountOut1, to);
    }

    function sync() external {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }
}
