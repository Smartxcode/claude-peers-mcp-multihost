#!/usr/bin/env bash
#
# claude-peers-mcp-multihost installer
#
# What this script does:
#   1. Checks if Bun runtime is installed
#   2. Installs Bun if missing (Linux/macOS)
#   3. Installs project dependencies via bun install
#
# Usage:
#   chmod +x install.sh && ./install.sh
#
# Or directly:
#   bash install.sh
#

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Check OS ---

OS="$(uname -s)"
case "$OS" in
  Linux|Darwin)
    info "Detected OS: $OS"
    ;;
  *)
    error "Unsupported OS: $OS (only Linux and macOS are supported)"
    exit 1
    ;;
esac

# --- Check/Install Bun ---

if command -v bun &>/dev/null; then
  BUN_VERSION=$(bun --version 2>/dev/null || echo "unknown")
  info "Bun is already installed (v${BUN_VERSION})"
else
  warn "Bun is not installed. Installing now..."
  echo ""
  echo "  Bun is a fast JavaScript/TypeScript runtime (https://bun.sh)"
  echo "  It provides built-in SQLite, HTTP server, and TypeScript support"
  echo "  that this project needs. It installs alongside Node.js without conflicts."
  echo ""

  if ! command -v curl &>/dev/null; then
    error "curl is required to install Bun. Install curl first:"
    if [[ "$OS" == "Linux" ]]; then
      error "  apt install curl   (Debian/Ubuntu)"
      error "  yum install curl   (CentOS/RHEL)"
    else
      error "  brew install curl  (macOS)"
    fi
    exit 1
  fi

  if ! command -v unzip &>/dev/null; then
    error "unzip is required to install Bun. Install unzip first:"
    if [[ "$OS" == "Linux" ]]; then
      error "  apt install unzip  (Debian/Ubuntu)"
      error "  yum install unzip  (CentOS/RHEL)"
    else
      error "  brew install unzip (macOS)"
    fi
    exit 1
  fi

  curl -fsSL https://bun.sh/install | bash

  # Source the updated profile so bun is available in this session
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"

  if command -v bun &>/dev/null; then
    BUN_VERSION=$(bun --version 2>/dev/null || echo "unknown")
    info "Bun installed successfully (v${BUN_VERSION})"
  else
    error "Bun installation failed. Try installing manually:"
    error "  curl -fsSL https://bun.sh/install | bash"
    error "Then restart your shell and run this script again."
    exit 1
  fi
fi

# --- Install project dependencies ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

info "Installing project dependencies..."
bun install

# --- Done ---

echo ""
info "Installation complete!"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Generate a shared auth token:"
echo "     export CLAUDE_PEERS_TOKEN=\$(openssl rand -hex 32)"
echo ""
echo "  2. Start the broker (on one host):"
echo "     CLAUDE_PEERS_TOKEN=\"your-token\" bun broker.ts"
echo ""
echo "  3. Register MCP server in Claude Code (on each host):"
echo "     claude mcp add --scope user --transport stdio claude-peers -- \\"
echo "       env CLAUDE_PEERS_HOST=<broker-ip> CLAUDE_PEERS_TOKEN=<token> \\"
echo "       bun ${SCRIPT_DIR}/server.ts"
echo ""
echo "  4. Start Claude Code with channel support:"
echo "     claude --dangerously-load-development-channels server:claude-peers"
echo ""
echo "  For local-only mode (single machine), skip CLAUDE_PEERS_HOST."
echo "  Full docs: https://github.com/Smartxcode/claude-peers-mcp-multihost"
echo ""
