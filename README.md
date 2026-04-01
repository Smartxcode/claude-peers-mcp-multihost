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

You need the following on **each host** that will participate in the peers network:

| Requirement | Why | How to check |
|-------------|-----|--------------|
| **Bun** >= 1.0 | Runtime for broker and MCP server | `bun --version` |
| **Claude Code** >= v2.1.80 | Channel support for instant messaging | `claude --version` |
| **claude.ai login** (OAuth) | Channels require subscription auth | `claude auth status` |
| **curl** + **unzip** | Only needed if Bun isn't installed yet | `which curl unzip` |
| **Network access** to broker | Peers must reach the broker's IP:port | `curl http://<broker-ip>:7899/health` |

### Automated install script

The included `install.sh` handles everything automatically:

```bash
git clone https://github.com/Smartxcode/claude-peers-mcp-multihost.git ~/claude-peers-mcp
cd ~/claude-peers-mcp
chmod +x install.sh
./install.sh
```

The script will:
1. Detect your OS (Linux or macOS)
2. Check if Bun is installed — if not, install it automatically
3. Verify that `curl` and `unzip` are available (needed for Bun installer)
4. Run `bun install` to fetch project dependencies
5. Print next steps for configuring the broker and MCP server

> **Already have Bun?** The script detects it and skips straight to dependency installation.

### Manual install

If you prefer to install step by step:

```bash
# 1. Install Bun (skip if already installed)
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc  # or restart your shell

# 2. Verify Bun
bun --version  # should print 1.x.x

# 3. Clone and install dependencies
git clone https://github.com/Smartxcode/claude-peers-mcp-multihost.git ~/claude-peers-mcp
cd ~/claude-peers-mcp
bun install
```

## Quick start

### 1. Install (on each host)

```bash
git clone https://github.com/Smartxcode/claude-peers-mcp-multihost.git ~/claude-peers-mcp
cd ~/claude-peers-mcp
./install.sh
```

### 2. Start the broker (on ONE host)

Pick one machine to run the broker. Generate a shared token:

```bash
export CLAUDE_PEERS_TOKEN=$(openssl rand -hex 32)
echo "Save this token: $CLAUDE_PEERS_TOKEN"
```

Start the broker:

```bash
CLAUDE_PEERS_TOKEN="your-token" bun broker.ts
```

The broker listens on `0.0.0.0:7899` by default. Verify it's running:

```bash
curl http://localhost:7899/health
# {"status":"ok","peers":0}
```

### 3. Register the MCP server (on each host)

```bash
claude mcp add --scope user --transport stdio claude-peers -- \
  env CLAUDE_PEERS_HOST=<broker-ip> CLAUDE_PEERS_TOKEN=<your-token> \
  bun ~/claude-peers-mcp/server.ts
```

Replace `<broker-ip>` with the broker host's IP (e.g. `10.10.10.65`).

### 4. Run Claude Code with the channel

```bash
export CLAUDE_PEERS_HOST=<broker-ip>
export CLAUDE_PEERS_TOKEN=<your-token>
claude --dangerously-skip-permissions --dangerously-load-development-channels server:claude-peers
```

> **Tip:** Add to your shell profile:
> ```bash
> export CLAUDE_PEERS_HOST=10.10.10.65
> export CLAUDE_PEERS_TOKEN=your-token-here
> alias claudepeers='claude --dangerously-load-development-channels server:claude-peers'
> ```

### 5. Try it

In a terminal on any host:

> List all peers on the network

Then:

> Send a message to peer [id]: "what are you working on?"

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
