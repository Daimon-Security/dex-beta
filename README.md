/*───────────────────────────────────────────────────────────────
███╗   ██╗ ██████╗ ██╗   ██╗ █████╗ 
████╗  ██║██╔═══██╗██║   ██║██╔══██╗
██╔██╗ ██║██║   ██║██║   ██║███████║
██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══██║
██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║
╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝
           CHAINOVA DEX – Router (V2 style)
───────────────────────────────────────────────────────────────*/

# Chainova DEX Router (V2 Style)

Chainova Router is a decentralized exchange (DEX) router contract inspired by Uniswap V2 architecture.  
It enables seamless swapping, liquidity provision, and removal for token pairs on EVM-compatible blockchains.

---

## Features

- **Swap tokens:** Swap any ERC20 tokens or swap between native ETH and ERC20 tokens using wrapped native token.
- **Add liquidity:** Provide liquidity to token pairs and receive liquidity tokens.
- **Remove liquidity:** Withdraw liquidity and receive underlying tokens.
- **Compatible with ChainovaFactory and ChainovaPair contracts:** Fully integrated with Chainova ecosystem.
- **Uses OpenZeppelin libraries:** SafeERC20 for secure token transfers and ReentrancyGuard for security.

---

## Contract Overview

- `factory`: Address of the ChainovaFactory contract responsible for pair creation and lookup.
- `WNATIVE`: Address of the wrapped native token contract (e.g., WETH, WBNB, WCNV).
- Core methods:
  - `addLiquidity` / `addLiquidityETH`
  - `removeLiquidity` / `removeLiquidityETH`
  - `swapExactTokensForTokens`
  - `swapExactETHForTokens`
  - `swapExactTokensForETH`

---

## Deployment Instructions

1. Deploy or have deployed:
   - ChainovaFactory contract
   - Wrapped native token contract (WETH/WCNV/etc.)
2. Deploy the ChainovaRouter contract providing the addresses of the factory and wrapped native token.
3. Use the router contract to create pairs via factory, add liquidity, and perform swaps.

---

## Usage Example

```solidity
// Adding liquidity between tokenA and tokenB
router.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired);

// Swapping exact ETH for tokens
router.swapExactETHForTokens{value: msg.value}(tokenOut, recipient);

// Removing liquidity and receiving ETH back
router.removeLiquidityETH(token, liquidityAmount);
```

---

## Security

- Utilizes OpenZeppelin's `SafeERC20` for secure token transfers.
- Protects sensitive functions with `ReentrancyGuard` to prevent reentrancy attacks.
- Validates inputs and state to prevent common DEX vulnerabilities.

---

## License

This project is licensed under the MIT License.

---

## Author

Chainova Devs

---

For more info or support, reach out to the Chainova team.
