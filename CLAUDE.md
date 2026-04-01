---
description: Use Bun instead of Node.js, npm, pnpm, or vite.
globs: "*.ts, *.tsx, *.html, *.css, *.js, *.jsx, package.json"
alwaysApply: false
---

# claude-peers-mcp-multihost

Peer discovery and messaging MCP channel for Claude Code instances — with cross-host support.

## Architecture

- `broker.ts` — Singleton HTTP daemon on 0.0.0.0:7899 + SQLite. Supports bearer token auth. Uses heartbeat timeout for peer liveness (works across hosts).
- `server.ts` — MCP stdio server, one per Claude Code instance. Connects to broker (local or remote), exposes tools, pushes channel notifications. Sends hostname on registration.
- `shared/types.ts` — Shared TypeScript types for broker API (includes hostname field).
- `shared/summarize.ts` — Auto-summary generation via gpt-5.4-nano.
- `cli.ts` — CLI utility for inspecting broker state (supports remote broker).

## Multihost vs Local

- Local mode (default): `CLAUDE_PEERS_HOST` not set → broker auto-launches on 127.0.0.1
- Multihost mode: Set `CLAUDE_PEERS_HOST` to broker IP → connects to remote broker, no auto-launch

## Running

```bash
# Broker (on one host):
CLAUDE_PEERS_TOKEN=secret bun broker.ts

# MCP server (on each host):
CLAUDE_PEERS_HOST=10.10.10.65 CLAUDE_PEERS_TOKEN=secret claude --dangerously-load-development-channels server:claude-peers

# CLI:
CLAUDE_PEERS_HOST=10.10.10.65 CLAUDE_PEERS_TOKEN=secret bun cli.ts status
```

## Bun

Default to using Bun instead of Node.js.

- Use `bun <file>` instead of `node <file>` or `ts-node <file>`
- Use `bun test` instead of `jest` or `vitest`
- Use `bun build <file.html|file.ts|file.css>` instead of `webpack` or `esbuild`
- Use `bun install` instead of `npm install` or `yarn install` or `pnpm install`
- Use `bun run <script>` instead of `npm run <script>` or `yarn run <script>` or `pnpm run <script>`
- Use `bunx <package> <command>` instead of `npx <package> <command>`
- Bun automatically loads .env, so don't use dotenv.

## APIs

- `Bun.serve()` supports WebSockets, HTTPS, and routes. Don't use `express`.
- `bun:sqlite` for SQLite. Don't use `better-sqlite3`.
- `Bun.redis` for Redis. Don't use `ioredis`.
- `Bun.sql` for Postgres. Don't use `pg` or `postgres.js`.
- `WebSocket` is built-in. Don't use `ws`.
- Prefer `Bun.file` over `node:fs`'s readFile/writeFile
- Bun.$`ls` instead of execa.

## Testing

Use `bun test` to run tests.

```ts#index.test.ts
import { test, expect } from "bun:test";

test("hello world", () => {
  expect(1).toBe(1);
});
```
