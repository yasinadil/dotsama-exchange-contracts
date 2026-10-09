# Dotsama Exchange Contracts

Smart contracts for the **Dotsama NFT Marketplace** on **Astar** and **Moonbeam**: an off-chain order book with on-chain settlement, where **badge holders who stake earn a share of every trade's protocol fee**, and holders of partner collections get fee discounts funded from royalties.

The exchange core is a fork of the **[LooksRare v1](https://github.com/LooksRare/contracts-exchange-v1)** exchange (MIT). On top of it I built the parts that make it Dotsama's:

| Contract | Origin | What it does |
|---|---|---|
| `DotsamaExchange` (`Dotsama.sol`) | LooksRare fork, **modified** | EIP-712 maker orders (asks and bids) matched by takers; nonce-based cancellation. **Settlement splits the protocol fee** between treasury and badge stakers (`dotsamaBadgesCut`), applies holder discounts, and books staker revenue to the next epoch. |
| `DotsamaBadgesStaking` | **Original** | Stake Dotsama Badges and earn WETH/WASTR from trading fees. Revenue is accounted per 30-day epoch; each badge earns `epochRevenue / stakedBadges × timeStakedInEpoch`, so partial epochs earn pro rata. Re-staking in the same epoch is blocked to stop flash-staking. |
| `DotsamaDiscountPromotions` (+ `GMLR` for Moonbeam) | **Original** | Fee discounts for partner-collection holders (−1% or −0.5% protocol fee, when the collection's royalty is high enough). The discount is redirected from royalties to badge stakers. |
| `DotsamaBadges` | **Original** | ERC721A badge collection with mint limits and airdrops. |
| Currency / execution / royalty managers, transfer managers, strategies | LooksRare v1 | Whitelists, royalty registry, ERC721/1155 transfer routing, fixed-price and Dutch-auction strategies. |

Trades are indexed by [dotsama-multichain-indexer](https://github.com/yasinadil/dotsama-multichain-indexer) (Subsquid, Astar + Moonbeam → one GraphQL API).

---

## Settlement, worked example

A 100 WETH sale with a 3% protocol fee, 5% royalty and a 50% badge cut:

| Recipient | No discount | Seller holds a partner NFT (−1%) |
|---|---|---|
| Seller | 92 | **93** |
| Royalty receiver | 5 | 4 (1% redirected to stakers) |
| Treasury | 1.5 | 1 |
| Badge stakers (next epoch) | 1.5 | 2 |

Both columns are asserted wei-for-wei in `test/DotsamaExchange.t.sol`.

## Tests

```bash
git clone --recurse-submodules https://github.com/yasinadil/dotsama-exchange-contracts
cd dotsama-exchange-contracts
forge test
```

**19 tests**, covering:
- **End-to-end trades with real EIP-712 signatures:** maker ask with taker bid, and maker bid with taker ask.
- **Fee, royalty and discount split** for both columns of the example above.
- **Order safety:** replay protection, cancel-all and cancel-specific nonces, forged signatures, tampered prices, seller slippage (`minPercentageToAsk`), taker must be the sender.
- **Staking:** custody, same-epoch restake block, pro-rata partial epochs, multi-epoch accrual, claim, and access control on epoch funding.

Line coverage is 47% overall: settlement, discounts and staking are covered, while LooksRare admin setters and the Dutch-auction strategy aren't yet.

### Deployment note

Partner-collection addresses in `DotsamaDiscountPromotions` are **hard-coded per chain**, with a separate `GMLR` variant for Moonbeam. If the contract is deployed on a chain where those addresses have no code, every trade of a royalty-bearing collection reverts in `discountEligibility`. The tests set up mock collections at those addresses for this reason.

## Deployments

`script/` holds the Astar (`DeployDotsamaExchange`, `DeployDotsamaBadgesStaking`) and Moonbeam (`DeployDotsamaMoonbeam`, `DeployDotsamaBadgesStakingGMLR`) deployment scripts, with the live wrapped-asset, badge and exchange addresses.

## Stack

Solidity 0.8.20 · Foundry · OpenZeppelin 5 · ERC721A · EIP-712 · Astar EVM · Moonbeam
