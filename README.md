# COBOL Bank Account Management System + Execution Visualizer

A small, idiomatic COBOL bank account program paired with a web-based
visualizer that replays its execution live. The goal is simple: take a
piece of legacy-style banking logic and make its behavior observable, the
way you'd instrument a modern service.

```
cobol/       bank-system.cob        — the GnuCOBOL program
scripts/     run_demo.sh            — driver script / test harness
visualizer/  index.html             — single-file web visualizer
data/        (generated at runtime) — bank-accounts.dat, event_log.csv
```

## What it does

`bank-system.cob` is a menu-driven bank account manager:

- **Create account** — opens an account with a holder name and initial deposit
- **Deposit** / **Withdraw** — with insufficient-funds and negative-amount checks
- **Balance inquiry**
- **Simple interest** — `principal × rate × days / (100 × 365)`, applied to the balance
- **Transaction history** — last 5 transactions per account

Accounts are stored in `bank-accounts.dat`, an **indexed (VSAM-style)**
file (`ORGANIZATION IS INDEXED`, keyed on account ID), so balances persist
across runs. Invalid account IDs, blank input, negative amounts, and
insufficient funds are all rejected with a message — nothing abends.

The `PROCEDURE DIVISION` is organized into clearly named paragraphs:

| Paragraph | Purpose |
|---|---|
| `1000-MAIN-PROCESS` | Menu loop / dispatch |
| `1500-CREATE-ACCOUNT` | Account creation |
| `2000-DEPOSIT` | Deposit |
| `3000-WITHDRAW` | Withdrawal |
| `3500-BALANCE-INQUIRY` | Balance lookup |
| `3600-VIEW-HISTORY` | Transaction history |
| `4000-VALIDATE-ACCOUNT` | Shared account/ID validation |
| `5000-CALC-INTEREST` | Simple interest calculation |
| `9000-LOG-EVENT` / `9100-ADD-TXN-HISTORY` / `9200-GET-TIMESTAMP` | Structured logging helpers |

### Structured event logging

Every paragraph entry/exit, validation pass/fail, and balance change is
appended to `event_log.csv` as one structured, timestamped row:

```
timestamp,paragraph,account_id,event_type,balance_before,balance_after,message
2026-08-14T09:00:14,2000-DEPOSIT,ACC001,BALANCE-CHANGE,1000.00,1250.50,Deposit applied
```

This file is the bridge between the COBOL program and the visualizer —
nothing more than a plain-text trace of what the program did, in order.

## Compiling with GnuCOBOL

You need a GnuCOBOL build with **indexed-file (ISAM) support** enabled —
the account file won't open without it. Check with:

```sh
cobc -info | grep -i indexed
# should print something other than "disabled", e.g.:
# indexed file handler     : BDB version 5.3
```

On Debian/Ubuntu, the packaged `gnucobol4` build ships with ISAM
**disabled**. Either install a distro package that enables it (e.g. via
Berkeley DB), or build GnuCOBOL from source with `--with-db` (or
`--with-vbisam`) and `libdb-dev` installed. On macOS, `brew install
gnu-cobol` builds with ISAM support out of the box.

Once you have a working `cobc`, compile:

```sh
cd cobol
cobc -x bank-system.cob -o bank-system
./bank-system
```

The program creates `bank-accounts.dat` and `event_log.csv` in the
current directory the first time it runs, and appends to both on
subsequent runs.

## Running the test harness

`scripts/run_demo.sh` compiles the program and feeds it a scripted
sequence of transactions across two accounts — deposits, a withdrawal
that deliberately overdraws (to exercise the insufficient-funds path),
a successful withdrawal, a balance inquiry, an interest calculation, and
a history lookup:

```sh
./scripts/run_demo.sh
```

This writes `data/bank-accounts.dat` and `data/event_log.csv`, ready for
the visualizer.

## Opening the visualizer

`visualizer/index.html` is a single, self-contained file — no build step,
no dependencies. Open it directly in a browser, or serve the repo root
so its auto-fetch can find the generated log:

```sh
python3 -m http.server 8000
# then open http://localhost:8000/visualizer/index.html
```

From there:

- **Try Auto-Fetch** looks for `data/event_log.csv` (and a couple of other
  relative paths) automatically — this is what picks up the harness output
- **Upload event_log.csv** or drag-and-drop the file directly
- **Load Sample Run** replays a bundled demo trace if you just want to see
  it work without compiling anything

Playback animates the currently executing paragraph on a flowchart of the
`PROCEDURE DIVISION`, plots each account's balance over time, and lists
every event in a scrollable log (most recent first). Use the transport
controls to play, pause, step, scrub, or change speed.

## Why this project exists

COBOL banking systems are still running trillions of dollars in
transactions today, but they're almost always a black box from the
outside — you send a request, a batch job runs somewhere, and a balance
changes. There's rarely a way to *see* the logic execute.

This project is a small experiment in bridging that gap: instrument a
COBOL program's control flow and state changes as a structured event
stream, and build ordinary web tooling on top of it — the same pattern
you'd use to add observability to any modern service. The COBOL program
doesn't know or care that anything is watching; it just writes one CSV
row per meaningful step. Everything downstream — the flowchart, the
balance chart, the log table — is built entirely from that trace.

It's a portfolio piece first and a working bank system second: the COBOL
is intentionally kept idiomatic and readable, and the visualizer is
intentionally dependency-free, so both halves are easy to read end to
end in one sitting.
