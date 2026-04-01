# claude-peers-mcp-multihost

> Forked from [louislva/claude-peers-mcp](https://github.com/louislva/claude-peers-mcp) — extended with cross-host communication for VMs, LXC containers, and multi-machine setups.

Let your Claude Code instances find each other and talk — **across different hosts**. Whether you're running sessions on separate VMs, LXC containers, or bare-metal machines, any Claude can discover the others and send messages that arrive instantly.

```
  Host A (vm-dev)                    Host B (lxc-staging)
  ┌───────────────────────┐          ┌──────────────────────┐
  │ Claude A              │          │ Claude B             │
  │ "send a message to    │  ──────> │                      │
  │  peer xyz: what files │          │ <channel> arrives    │
  │  are you editing?"    │  <────── │  instantly, Claude B │
  │                       │          │  responds            │
  └───────────────────────┘          └──────────────────────┘
         │                                    │
         └──────── Broker (any host) ─────────┘
                   0.0.0.0:7899
```

---

## Deployment Guide for Claude Code Sessions

> **This section is for you, Claude Code instance.** Follow these steps to deploy the peers network on your host. The user will tell you whether this host should be the **broker** or a **client**. If unsure, ask.

### Decision: Broker or Client?

```
  Is there already a broker running on another host?
    │
    ├─ NO  → You are the BROKER. Follow Step A + Step B.
    │
    └─ YES → You are a CLIENT. Follow Step B only.
        │    You need: broker IP and CLAUDE_PEERS_TOKEN from the broker host.
```

### Step A: Deploy the Broker (one host only)

Run these commands in sequence on the host that will be the central broker:

```bash
# 1. Install Bun runtime (skip if already installed)
if ! command -v bun &>/dev/null; then
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

# 2. Clone the project
git clone https://github.com/Smartxcode/claude-peers-mcp-multihost.git ~/claude-peers-mcp
cd ~/claude-peers-mcp
bun install

# 3. Generate auth token (save this — all clients need it)
export CLAUDE_PEERS_TOKEN=$(openssl rand -hex 32)
echo "BROKER TOKEN: $CLAUDE_PEERS_TOKEN"
echo "BROKER IP:    $(hostname -I | awk '{print $1}')"

# 4. Start the broker daemon
CLAUDE_PEERS_TOKEN="$CLAUDE_PEERS_TOKEN" nohup bun broker.ts > /tmp/claude-peers-broker.log 2>&1 &
echo "Broker PID: $!"

# 5. Verify
sleep 1
curl -s http://localhost:7899/health
# Expected: {"status":"ok","peers":0}
```

**Save two values** and give them to the user (or to other Claude Code sessions):
- `BROKER_IP` — the IP address printed in step 3
- `CLAUDE_PEERS_TOKEN` — the token printed in step 3

### Step B: Deploy a Client (every host, including the broker host)

Run these commands on each host that should join the peers network. You need `BROKER_IP` and `CLAUDE_PEERS_TOKEN` from the broker setup.

```bash
# 1. Install Bun runtime (skip if already installed)
if ! command -v bun &>/dev/null; then
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

# 2. Clone the project (skip if already cloned, e.g. on broker host)
if [ ! -d ~/claude-peers-mcp ]; then
  git clone https://github.com/Smartxcode/claude-peers-mcp-multihost.git ~/claude-peers-mcp
  cd ~/claude-peers-mcp
  bun install
fi

# 3. Register MCP server in Claude Code
#    Replace <BROKER_IP> and <TOKEN> with actual values
claude mcp add --scope user --transport stdio claude-peers -- \
  env CLAUDE_PEERS_HOST=<BROKER_IP> CLAUDE_PEERS_TOKEN=<TOKEN> \
  bun ~/claude-peers-mcp/server.ts

# 4. Add env vars to shell profile for persistence
cat >> ~/.bashrc << 'PEERS_EOF'
# claude-peers-mcp-multihost
export CLAUDE_PEERS_HOST=<BROKER_IP>
export CLAUDE_PEERS_TOKEN=<TOKEN>
PEERS_EOF
source ~/.bashrc

# 5. Verify connection to broker
curl -s http://<BROKER_IP>:7899/health
# Expected: {"status":"ok","peers":N}

# 6. Start Claude Code with channel support
claude --dangerously-load-development-channels server:claude-peers
```

### Verification Checklist

After deployment, confirm everything works:

```bash
# On any host — check broker is reachable
curl -s http://<BROKER_IP>:7899/health

# On any host — list all connected peers
CLAUDE_PEERS_HOST=<BROKER_IP> CLAUDE_PEERS_TOKEN=<TOKEN> bun ~/claude-peers-mcp/cli.ts status

# Inside Claude Code — test peer discovery
# Ask: "List all peers on the network"
# Ask: "Send a message to peer <id>: hello from <hostname>"
```

### Troubleshooting

| Problem | Check |
|---------|-------|
| `connection refused` | Is broker running? `curl http://<BROKER_IP>:7899/health` |
| `401 unauthorized` | Token mismatch — verify `CLAUDE_PEERS_TOKEN` matches on broker and client |
| `bun: command not found` | Bun not in PATH — run `export PATH="$HOME/.bun/bin:$PATH"` or re-run install |
| Peer not showing up | Check heartbeat — peers disappear after 60s without heartbeat |
| Channel messages not arriving | Must use `--dangerously-load-development-channels server:claude-peers` flag |

---

## What's new vs upstream

| Feature | upstream | multihost |
|---------|----------|-----------|
| Cross-host messaging | No (localhost only) | Yes |
| Broker bind address | `127.0.0.1` | `0.0.0.0` (configurable) |
| Peer liveness | PID check (local only) | Heartbeat timeout (works remote) |
| Auth | None | Bearer token (`CLAUDE_PEERS_TOKEN`) |
| Hostname tracking | No | Yes (`hostname` field on peers) |
| Scope: `host` | No | Yes (filter peers by hostname) |

## Prerequisites

This project runs on **[Bun](https://bun.sh)** — a fast JavaScript/TypeScript runtime with built-in SQLite, HTTP server, and native TypeScript support. Bun installs alongside Node.js without conflicts, so your existing Claude Code setup stays untouched.

| Requirement | Why | How to check |
|-------------|-----|--------------|
| **Bun** >= 1.0 | Runtime for broker and MCP server | `bun --version` |
| **Claude Code** >= v2.1.80 | Channel support for instant messaging | `claude --version` |
| **claude.ai login** (OAuth) | Channels require subscription auth | `claude auth status` |
| **curl** + **unzip** | Only needed if Bun isn't installed yet | `which curl unzip` |
| **Network access** to broker | Peers must reach the broker's IP:port | `curl http://<broker-ip>:7899/health` |

### Automated install script

The included `install.sh` handles Bun installation and project setup:

```bash
git clone https://github.com/Smartxcode/claude-peers-mcp-multihost.git ~/claude-peers-mcp
cd ~/claude-peers-mcp
chmod +x install.sh
./install.sh
```

The script will:
1. Detect your OS (Linux or macOS)
2. Check if Bun is installed — if not, install it automatically
3. Verify that `curl` and `unzip` are available
4. Run `bun install` to fetch project dependencies
5. Print next steps for configuring the broker and MCP server

## Local-only mode

Works exactly like the original — just don't set `CLAUDE_PEERS_HOST`:

```bash
claude mcp add --scope user --transport stdio claude-peers -- bun ~/claude-peers-mcp/server.ts
claude --dangerously-skip-permissions --dangerously-load-development-channels server:claude-peers
```

The broker auto-launches on localhost. No token needed for local-only use.

## What Claude can do

| Tool | What it does |
|------|-------------|
| `list_peers` | Find other Claude Code instances — scoped to `machine`, `host`, `directory`, or `repo` |
| `send_message` | Send a message to another instance by ID (arrives instantly via channel push) |
| `set_summary` | Describe what you're working on (visible to other peers) |
| `check_messages` | Manually check for messages (fallback if not using channel mode) |

## How it works

```
  Host A                          Host B                          Host C
  ┌──────────┐                    ┌──────────┐                    ┌──────────┐
  │ Claude A  │                   │ Claude B  │                   │ Claude C  │
  │ MCP srv   │──┐                │ MCP srv   │──┐                │ MCP srv   │──┐
  └──────────┘  │                 └──────────┘  │                 └──────────┘  │
                │                               │                               │
                └───────────┐     ┌─────────────┘     ┌─────────────────────────┘
                            │     │                    │
                            ▼     ▼                    ▼
                     ┌─────────────────────────────────────┐
                     │  Broker daemon (any host)           │
                     │  0.0.0.0:7899 + SQLite              │
                     │  Token auth: CLAUDE_PEERS_TOKEN     │
                     └─────────────────────────────────────┘
```

Each MCP server registers with the broker, sends heartbeats every 15s, and polls for messages every 1s. Peers not seen for 60s are automatically cleaned up — no PID checks needed, so it works across hosts.

## CLI

```bash
# Point CLI at the broker
export CLAUDE_PEERS_HOST=<broker-ip>
export CLAUDE_PEERS_TOKEN=<your-token>

bun cli.ts status            # broker status + all peers (all hosts)
bun cli.ts peers             # list peers
bun cli.ts send <id> <msg>   # send a message into a Claude session
bun cli.ts kill-broker       # stop the local broker
```

## Auto-summary

If you set `OPENAI_API_KEY` in your environment, each instance generates a brief summary on startup using `gpt-5.4-nano` (costs fractions of a cent). The summary describes what you're likely working on based on your directory, git branch, and recent files. Other instances see this when they call `list_peers`.

Without the API key, Claude sets its own summary via the `set_summary` tool.

## Configuration

| Environment variable | Default | Description |
|---------------------|---------|-------------|
| `CLAUDE_PEERS_HOST` | `127.0.0.1` | Broker address (set on MCP servers and CLI) |
| `CLAUDE_PEERS_PORT` | `7899` | Broker port |
| `CLAUDE_PEERS_BIND` | `0.0.0.0` | Broker bind address |
| `CLAUDE_PEERS_DB` | `~/.claude-peers.db` | SQLite database path |
| `CLAUDE_PEERS_TOKEN` | — | Bearer token for auth (recommended for multihost) |
| `OPENAI_API_KEY` | — | Enables auto-summary via gpt-5.4-nano |

## Security

- **Token auth**: Set `CLAUDE_PEERS_TOKEN` on broker and all clients. Without it, the broker accepts any connection.
- **Network**: The broker binds to `0.0.0.0` by default. Use `CLAUDE_PEERS_BIND=127.0.0.1` for local-only, or firewall rules to restrict access.
- **No TLS**: Communication is plain HTTP. For production use across untrusted networks, put the broker behind a reverse proxy with TLS.

## Requirements

- **[Bun](https://bun.sh)** >= 1.0 (auto-installed by `install.sh`)
- **Claude Code** >= v2.1.80
- **claude.ai login** (channels require OAuth — API key auth won't work)
- **curl** + **unzip** (only for Bun installation)
- Network connectivity between hosts and broker

## Credits

Based on [claude-peers-mcp](https://github.com/louislva/claude-peers-mcp) by [louislva](https://github.com/louislva).
