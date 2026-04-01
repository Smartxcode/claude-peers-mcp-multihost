# Use Cases & Capabilities

## What peers can exchange

Claude Code sessions communicate via **plain text messages** and **peer metadata**. There is no binary transfer, no shared memory, and no streaming — but because each Claude Code instance has full access to its host (files, git, shell, databases), a simple text message like *"show me the nginx config"* is enough to trigger a complete read-and-reply cycle.

### Peer discovery

Every connected session exposes metadata visible to all other peers:

| Field | Example | Description |
|-------|---------|-------------|
| `id` | `a3kx92mf` | Unique peer identifier |
| `hostname` | `lxc-frontend` | Host machine name |
| `pid` | `12847` | Process ID on the host |
| `cwd` | `/var/www/app` | Working directory |
| `git_root` | `/var/www/app` | Git repository root (if any) |
| `summary` | `"Building React dashboard components"` | Self-described current task |
| `last_seen` | `2026-04-01T14:32:00Z` | Last heartbeat timestamp |

Peers can be filtered by scope:
- **`machine`** — all peers across all hosts
- **`host`** — only peers on the same hostname
- **`directory`** — peers in the same working directory
- **`repo`** — peers in the same git repository

### Messaging

Messages are free-form text with no enforced structure or size limit. What makes this powerful is that each Claude Code session interprets messages intelligently and has full access to its local environment.

**What peers can do in practice:**

| Action | Example message |
|--------|-----------------|
| Ask questions | *"What schema does the users table have in your database?"* |
| Coordinate work | *"Auth module is done. You can start building the login page."* |
| Share code snippets | *"Here's the API response format: `{ data: [...], meta: { page, total } }`"* |
| Request checks | *"Run the test suite and tell me if anything fails."* |
| Report status | *"Staging deploy complete. Endpoint /api/v2/orders is live."* |
| Delegate tasks | *"Review the Dockerfile and check for security issues."* |
| Share config | *"The database connection string is postgres://db-host:5432/app"* |
| Debug together | *"I'm getting 502 from your API. Check nginx logs for errors."* |
| Sync state | *"I've migrated the DB schema. Pull latest and restart your service."* |

### Limitations

| Limitation | Description | Workaround |
|------------|-------------|------------|
| Text only | No binary or file transfer | Encode as base64 in message, or share file paths on shared storage |
| No broadcast | Must send to each peer individually | Loop through `list_peers` and send to each |
| No threading | Flat message stream, no conversations | Include context/reference in each message |
| No delivery confirmation | Fire-and-forget after broker accepts | Peer can reply to confirm receipt |
| No shared memory | Each session has its own context | Exchange state via messages or shared files/DB |
| No streaming | Message is atomic — all or nothing | Send incremental updates as separate messages |

---

## Ideal use case: Distributed application stacks

This tool shines when your application is spread across **multiple hosts** — each running a different layer of the stack, each with its own Claude Code session.

### Example: E-commerce platform on LXC containers

```
  lxc-frontend         lxc-backend          lxc-database         lxc-middleware
  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
  │ Claude A      │    │ Claude B      │    │ Claude C      │    │ Claude D      │
  │ React/Next.js │    │ Express API   │    │ PostgreSQL    │    │ Redis/Queue   │
  │ Tailwind CSS  │    │ Auth, Orders  │    │ Migrations    │    │ Nginx proxy   │
  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘
         │                    │                    │                    │
         └────────┤    ┌────┴────┤    ┌────┴─────────────┘
                  │    │         │    │
                  ▼    ▼         ▼    ▼
              ┌───────────────────────┐
              │    Broker (any LXC)     │
              │    0.0.0.0:7899         │
              └───────────────────────┘
```

**Real conversation between peers:**

> **Claude A** (frontend) → **Claude B** (backend):  
> *"I need a new endpoint `GET /api/v2/products?category=X` with pagination. Can you create it?"*

> **Claude B** (backend) → **Claude C** (database):  
> *"What indexes exist on the products table? I need to query by category with offset/limit."*

> **Claude C** (database) → **Claude B** (backend):  
> *"Index on (category, created_at DESC) exists. Use `SELECT * FROM products WHERE category = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`."*

> **Claude B** (backend) → **Claude A** (frontend):  
> *"Endpoint ready: `GET /api/v2/products?category=electronics&page=1&limit=20`. Response: `{ data: Product[], meta: { page, total, pages } }`."*

> **Claude A** (frontend) → **Claude D** (middleware):  
> *"Add `/api/v2/products` to the nginx proxy pass rules and enable caching with 60s TTL."*

### More scenarios where this fits

**Microservices architecture:**

| Host | Role | Claude's job |
|------|------|--------------|
| `lxc-gateway` | API Gateway / Nginx | Routing rules, rate limiting, SSL certs |
| `lxc-auth` | Auth service | JWT, OAuth, session management |
| `lxc-core` | Core business logic | Domain models, business rules |
| `lxc-worker` | Background jobs | Queue consumers, scheduled tasks |
| `lxc-db` | Database server | Schemas, migrations, query optimization |
| `lxc-cache` | Redis/Memcached | Cache strategies, invalidation |
| `lxc-monitor` | Observability | Logs, metrics, alerting rules |

Each Claude Code session is an expert on its host's stack. Together they can:

- **Build features end-to-end** across all layers simultaneously
- **Debug cross-service issues** ("I see 502 errors" → "Let me check my logs" → "Found it: DB connection pool exhausted")
- **Coordinate deployments** ("Schema migrated" → "Pulling new code" → "Cache invalidated" → "Gateway updated")
- **Review architecture** ("What's the request flow for /checkout?" → each service describes its role)

**Proxmox / Virtualization cluster:**

| Host | Example |
|------|---------|
| VM with Magento | Claude manages PHP, nginx, catalog |
| VM with PostgreSQL | Claude manages schemas, backups, replication |
| VM with Elasticsearch | Claude manages indexes, mappings, queries |
| LXC with Redis | Claude manages caching, sessions |
| LXC with n8n | Claude manages automation workflows |

**Multi-project monorepo split across hosts:**

| Host | Project |
|------|---------|
| `dev-1` | Shared library / SDK |
| `dev-2` | Web application |
| `dev-3` | Mobile BFF (backend for frontend) |
| `dev-4` | Admin panel |

Claude sessions can synchronize breaking changes: *"I renamed `getUserById` to `findUser` in the SDK. Update your imports."*

---

## What makes this different from subagents?

Claude Code already has a built-in `Agent` tool for spawning subagents. Here's when to use peers instead:

| | Subagents (built-in) | Peers (this project) |
|-|---------------------|---------------------|
| **Scope** | Same host, same repo | Cross-host, any repo |
| **Lifecycle** | Spawned for a task, then dies | Persistent, always running |
| **Context** | Inherits parent's context | Has its own independent context |
| **Access** | Same filesystem | Different filesystem per host |
| **Best for** | Parallelizing work in one codebase | Coordinating work across distributed systems |

Use subagents when the work is in one place. Use peers when the work is spread across hosts.
