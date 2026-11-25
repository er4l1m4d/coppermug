# Submission checklist — Gnome Tavern Hackathon

Deadline: **2026-12-18 01:00 UTC**. Judging: technical quality 40%, user appeal 20%,
creativity 20%, docs and demo 20%.

## Requirements

| Requirement | Status | Notes |
|---|---|---|
| Live deployment on the Gno.land testnet | ✅ | [Live realm](https://onyx.testnets.gno.land/r/g1jjnn7hay2fyzufdqhjcqn50udc55h6tdr4yx8y/coppermug) on `onyx-1`, seeded with real activity |
| Public code repository | ✅ | [github.com/er4l1m4d/coppermug](https://github.com/er4l1m4d/coppermug) |
| Genuine Gno component (realm or package) | ✅ | Stateful realm with six routes and full state |
| README explaining the project and usage | ✅ | `README.md` |
| Demo video showing it working | ⏳ | Shot list below |
| Short project description | ✅ | First paragraph of `README.md` |
| Name has no "Gno" prefix or official branding | ✅ | "Copper Mug" |

## Before submitting

1. Record and upload the demo video.
2. Paste the repository and deployment links into the DoraHacks submission.
3. Register on DoraHacks if not already done.

## Demo video shot list (90–120 seconds)

1. Open the realm on gnoweb. Point at the empty room and the one-line premise.
2. `Join` from the Actions tab (or show the `gnokey` call) → the join post appears.
3. `Say` a line → the board updates.
4. Join a second wallet, `Tip` the first, show the balance and renown change.
5. `Cheer` a post → the author's renown increments; try to cheer twice (refused).
6. `OpenCup` 25 gold, `Roll` twice, `Hold` → profile shows wins and best pot.
7. Show the board: richest, most renowned, biggest pots.
8. Close on the fairness note and "no server, no database, no JavaScript".

## Judge-facing notes

- The realm is the product: every page is `Render`, so nothing depends on a
  frontend host or wallet integration to be usable.
- Validation is separated into pure helpers and unit-tested; the rejection paths
  are tested too.
- The Cup's randomness is documented honestly, including its limitation.
- State is bounded: 100 posts, 24 recent seats, no per-user growth.
- Only direct wallet calls are accepted; other realms cannot act for a player.

## Open decisions

- Project license.
- Whether the deploy key is also the prize wallet.
- Optional: reusable `p/` package for the gold ledger, to satisfy the retention
  prize's "another project imports it" criterion.
