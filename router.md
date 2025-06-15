# Solidity API

## IWrappedNative

### Contract
IWrappedNative : contracts/router.sol

 --- 
### Functions:
### deposit

```solidity
function deposit() external payable
```

### withdraw

```solidity
function withdraw(uint256) external
```

### transfer

```solidity
function transfer(address, uint256) external returns (bool)
```

## IChainovaFactory

### Contract
IChainovaFactory : contracts/router.sol

 --- 
### Functions:
### getPair

```solidity
function getPair(address, address) external view returns (address)
```

### createPair

```solidity
function createPair(address, address) external returns (address)
```

## IChainovaPair

### Contract
IChainovaPair : contracts/router.sol

 --- 
### Functions:
### getReserves

```solidity
function getReserves() external view returns (uint112, uint112, uint32)
```

### mint

```solidity
function mint(address) external returns (uint256)
```

### burn

```solidity
function burn(address) external returns (uint256 amount0, uint256 amount1)
```

### swap

```solidity
function swap(uint256, uint256, address, bytes) external
```

## ChainovaRouter

### Contract
ChainovaRouter : contracts/router.sol

 --- 
### Functions:
### constructor

```solidity
constructor(address _factory, address _wnative) public
```

### _sort

```solidity
function _sort(address a, address b) internal pure returns (address, address)
```

### _pairFor

```solidity
function _pairFor(address a, address b) internal view returns (address)
```

### _reserves

```solidity
function _reserves(address a, address b) internal view returns (uint112 rA, uint112 rB)
```

### _quote

```solidity
function _quote(uint256 amtA, uint112 resA, uint112 resB) internal pure returns (uint256)
```

### _getAmountOut

```solidity
function _getAmountOut(uint256 amtIn, uint112 resIn, uint112 resOut) internal pure returns (uint256)
```

### _addLiquidity

```solidity
function _addLiquidity(address tokenA, address tokenB, uint256 amtADes, uint256 amtBDes) internal returns (uint256 amtA, uint256 amtB, address pair)
```

### addLiquidity

```solidity
function addLiquidity(address tokenA, address tokenB, uint256 amtADes, uint256 amtBDes) external returns (uint256 amtA, uint256 amtB, uint256 liquidity)
```

### addLiquidityETH

```solidity
function addLiquidityETH(address token, uint256 amtTokenDesired) external payable returns (uint256 amtToken, uint256 amtETH, uint256 liquidity)
```

### removeLiquidity

```solidity
function removeLiquidity(address tokenA, address tokenB, uint256 liquidity) public returns (uint256 amtA, uint256 amtB)
```

### removeLiquidityETH

```solidity
function removeLiquidityETH(address token, uint256 liquidity) external returns (uint256 amtToken, uint256 amtETH)
```

### _swapSingle

```solidity
function _swapSingle(uint256 amtIn, address tokenIn, address tokenOut, address to) internal returns (uint256 amtOut)
```

### swapExactTokensForTokens

```solidity
function swapExactTokensForTokens(uint256 amtIn, address tokenIn, address tokenOut, address to) external returns (uint256 amtOut)
```

### swapExactETHForTokens

```solidity
function swapExactETHForTokens(address tokenOut, address to) external payable returns (uint256 amtOut)
```

### swapExactTokensForETH

```solidity
function swapExactTokensForETH(uint256 amtIn, address tokenIn, address to) external returns (uint256 amtOut)
```

### receive

```solidity
receive() external payable
```

inherits ReentrancyGuard:
### _reentrancyGuardEntered

```solidity
function _reentrancyGuardEntered() internal view returns (bool)
```

_Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
`nonReentrant` function in the call stack._

