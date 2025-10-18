# FHE Battleship

**FHE Battleship** is a two-player Battleship-style game that runs on an **FHE-enabled EVM** (fhEVM by Zama).  
It demonstrates how to build a **privacy-preserving, verifiable on-chain game** where boards, hits, and remaining ships are kept **confidential** throughout play. Only minimal facts (like the winner or an optional hit/miss reveal) are ever made public—via explicit, auditable decryptions.

> Tech focus: Fully Homomorphic Encryption (FHE) on EVM and asynchronous public decryption callbacks for minimal information disclosure.

---

## ✨ Features

- **Hidden boards & state** — Ship layout and remaining lives stored as encrypted values (`euint*`, `ebool`).
- **Leak-free turns** — Hit checks and life deductions use **encrypted selection**.
- **Asynchronous reveals** — Public info (winner, optional hit/miss) is revealed **only** through opt-in decryption requests and oracle callbacks.
- **DoS-resistant UX** — Public decryption happens at checkpoints (e.g., winner claim), not every move.
- **Modular** — Contracts separated from the web UI. The front end can run mock mode or connect to FHEVM.

---

## 🧭 Repository Structure

```
fhe-battleship/
├─ contracts/               # Solidity smart contracts (fhEVM types & logic)
│  ├─ FHEBattleShiop.sol    # Core game logic with encrypted state
│  └─ ...
├─ frontend/                # Web UI (React/Next/Vite) — static prototype & hooks
│  └─ src/
│     └─ ...                # Components, game grid, wallet, contract hooks
├─ scripts/                 # Deployment / verification / helper scripts
├─ test/                    # Unit & property tests (Foundry/Hardhat)
├─ .env.example             # Environment variables template
├─ README.md
└─ LICENSE
```

---

## 🧪 Game Rules (on chain)

- Board: 10×10 grid (64-bit example in code can be extended to 100 cells easily).
- Each player places **5 ships** (example sizes configurable).
- Players take turns to shoot a cell.
- **Hit/miss** is computed **in encrypted form**. Remaining ships are encrypted and decremented via `cmux`.
- Winner is **not** decided in the same transaction as a shot; a player calls `claimWin()` to **publicly decrypt** the boolean “opponentRemaining == 0”.  
  If true, the callback finalizes the winner.

---

## 🔐 Crypto & Privacy Model

- **Confidential state**: `board.grid`, `board.remaining`, and intermediate “hit” signals are stored/processed as `euint*/ebool`.
- **No observable branches**: logic uses **encrypted selection** (`FHE.cmux`) instead of public `if` on secret conditions.
- **Minimal disclosure**: Any secret → public transition **must** go through `FHE.requestDecryption(...)` → oracle callback.  

---

## 🏗️ Contracts Overview

**`FHEBattleGrid.sol`**

- `createGame()` → returns `gameId`.
- `joinGame(gameId)` → second player joins.
- `submitBoard(gameId, externalEuint64 board, bytes inputProof)` → submit encrypted board; transitions to `ACTIVE` when both are set.
- `shoot(gameId, cell)` → record shot; compute encrypted `hit`; update encrypted `remaining` using `cmux`; **no public result emitted**.
- `claimWin(gameId)` → request public decryption of “opponentRemaining == 0”;  
  `claimWinCallback(...)` finalizes `winner`.
- `requestShotReveal(gameId, cell)` → (optional) decrypt hit/miss for an already-fired cell;  
  `shotRevealCallback(...)` emits `ShotRevealed`.
- `revealGrid(gameId)` / `revealGridCallback(...)` → (optional) post-game board reveal for replay/analytics.

**Key events**

- `GameCreated`, `PlayerJoined`, `BoardSubmitted`, `GameStarted`, `ShotFired`
- `WinCheckRequested`, `WinClaimed`, `ShotRevealed`, `GameWon`

---

## 🚀 Quick Start

### Prerequisites

- Node.js ≥ 18 and `pnpm` or `npm`
- A Solidity toolchain — choose one:
  - **Foundry** (`forge`, `cast`)
  - **Hardhat** (with fhEVM plugins if you prefer)
- Wallet with test ETH on your fhEVM-compatible testnet (e.g., Sepolia)  
- Access to fhEVM decryption oracle on your target network

### 1) Install

```bash
# root
pnpm install
# or
npm install
```

### 2) Configure

Copy `.env.example` to `.env` and set values:

```
PRIVATE_KEY=0x...
RPC_URL=https://...
EXPLORER_API_KEY=...
FHEVM_NETWORK=sepolia   # or your fhEVM endpoint name
```

> If your oracle/decryption endpoints require additional keys, add them here.

### 3) Compile & Test

Using Foundry (example):

```bash
forge build
forge test
```

Using Hardhat:

```bash
pnpm -w hardhat compile
pnpm -w hardhat test
```

### 4) Deploy

```bash
# Foundry example
forge script scripts/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast -vv
```

Record the deployed `FHEBattleGrid` address and put it into `frontend/.env.local`.

### 5) Run the Frontend

```bash
cd frontend
pnpm install
pnpm dev  # or pnpm build && pnpm preview
```

Open <http://localhost:5173> (Vite default) or your Next.js dev URL.

---

## 🌐 Frontend Integration (hooks sketch)

- `submitBoard()` encodes board bitmask → `externalEuint64` with input proof.
- `shoot()` sends clear cell index (or **encrypted cell** for fully private targeting in an advanced mode).
- `claimWin()` / `requestShotReveal()` trigger decryption requests; UI shows **optimistic** animations and finalizes on callback.
- Display **public** info only:
  - Fired cells bitmap (`shots0/shots1`)
  - Game state / turn
  - Winner (after `claimWinCallback`)


---

## 🧩 Board Encoding

The example contract encodes the board as a **bitmask**:

- `1` = ship, `0` = empty
- For a 10×10 board, you can upgrade to `euint128` or pack into multiple `euint64` values.
- Enforce ship placements (size, adjacency rules) either:
  - Off-chain with a zero-knowledge proof of validity, or
  - On-chain with encrypted constraints (costlier), or
  - Hybrid (commit-then-verify minimal bits).

---

## 🔒 Security Notes

- **Secret-to-public** transitions must **only** use `FHE.requestDecryption(...)` and verified callbacks.
- Validate **replay & ordering** in callbacks: check `gameId`, `claimer`, state still `ACTIVE`, etc.
- Ensure **no early probing**: only allow shot reveal if the caller actually fired that cell in history.
- Add **rate limits** / anti-grief rules as needed for public endpoints.

---

## 🧭 Roadmap

- [ ] Drag-and-drop ship placement with validity checks  
- [ ] Matchmaking / lobby & friend invites  
- [ ] Spectator mode with post-game reveal  

---

## 🤝 Contributing

Issues and PRs are welcome!  
Please:

1. Describe the problem and the intended fix.
2. Include tests where possible.
3. Avoid introducing public branches dependent on confidential conditions.

---

## 📄 License

MIT — see [LICENSE](./LICENSE).

---

## 🙌 Acknowledgments

- **Zama fhEVM** for the Solidity FHE primitives (`euint*`, `ebool`, `cmux`, etc.)
- The privacy-preserving gaming community for patterns on constant-shape execution and minimal disclosure.
