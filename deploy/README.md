# Crucible as a service (P1-17)

Runs the `crucible-cli` release behind its zero-dependency MCP wrapper as a
socket-activated systemd service, and generates the resolver (oracle) key on
the VPS so its secret never leaves the host.

## What is deployed

- `target/release/crucible` — the release CLI. One JSON object in on stdin,
  one JSON object out on stdout, one verb per call.
- `mcp/crucible-mcp.mjs` — the MCP wrapper. It reads the tool catalogue from
  `crucible tools` at startup, so the CLI is the single definition of what
  Crucible can do.
- `ares-crucible.socket` + `ares-crucible.service` — a socket-activated
  systemd unit. The accepted connection on `/run/ares-crucible.sock` becomes
  the MCP server's stdin/stdout; a client speaks JSON-RPC MCP over it. No TCP
  port, so the oracle seam is reachable only on the box's filesystem.
- `/etc/ares/crucible/resolver.json` (0600) — the resolver keypair generated
  on the VPS.

## Install

```
sudo bash deploy/install.sh
```

It builds the release, generates the resolver key (idempotent), installs and
enables the socket, and prints the resolver pubkey.

## The resolver key and `oracle_authorities`

The resolver is the community oracle: its `oracle.verdict` events are the
exogenous answers that `settle()` scores attestors against, instead of their
own aggregate. A verdict is only meaningful once the policy names the
resolver's key:

```json
{"policy": {"oracle_authorities": ["<resolver pubkey>"]}}
```

The pubkey is printed by `install.sh` (or read from
`/etc/ares/crucible/resolver.json`). Wire it into the policy Vantage passes
when it calls `resolve` / `ledger.replay` (P3-01) and minipae carries
(P3-08).

**Long-term holder = open decision.** The key is generated on the VPS and its
secret stays there; who ultimately controls that identity (and how it is
rotated/escrowed) is the handoff's open decision 4 and is not resolved here.

## Notes

- `keygen` (seed-derived) is demo-only and gated behind
  `CRUCIBLE_ALLOW_DEMO_KEYS`. The resolver uses `keygen.live`, which draws
  from the OS CSPRNG and is not gated.
- MCP is stdio-only by design; the socket unit is the daemon transport. If a
  later phase wants HTTP/SSE, change the transport here, not the CLI.
- `ares-crucible.service` is registered in ares-control as `Category.BRIDGE`
  (P1-16): it never places orders.
