# Agent Benchmarks Infrastructure Design

**Date:** 2026-10-10  
**Status:** Draft for Review  
**Author:** OpenCode MEM Team

## 1. Executive Summary

This document defines the architecture for a benchmark infrastructure that allows agents to:
- Execute benchmarks and capture session artifacts
- Store benchmark metadata, prompts, and results in SQLite
- Upload session logs to Google Cloud Storage
- Attach benchmark results to Pull Requests
- Share results between agents without public exposure

**Repository:** `gpt-mem/agent-benchmarks` (to be created)

## 2. Core Requirements

### 2.1 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR1 | Agents can execute benchmarks via simple CLI/API | P0 |
| FR2 | Benchmark sessions stored in SQLite with full provenance | P0 |
| FR3 | Session logs uploadable to Google Cloud Storage | P0 |
| FR4 | Results attachable to GitHub Pull Requests | P0 |
| FR5 | Local session upload from user's disk | P1 |
| FR6 | Results shareable between agents (non-public) | P0 |
| FR7 | Benchmark history, prompts, parameters, conclusions tracked | P0 |
| FR8 | Comments and annotations on benchmark results | P1 |

### 2.2 Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR1 | Simple agent interface | < 5 CLI commands |
| NFR2 | Local-first operation | Works offline |
| NFR3 | GCS integration | Reliable upload with retry |
| NFR4 | Security | No public exposure of results |
| NFR5 | Extensibility | Easy to add new benchmark types |

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Agent Workflow Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────────┐  │
│  │ CLI Commands │  │  MCP Tools   │  │  PR Attachment Service    │  │
│  └──────────────┘  └──────────────┘  └───────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Benchmark Orchestrator                            │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  • Session lifecycle management                                │ │
│  │  • Artifact collection (logs, prompts, results)                │ │
│  │  • Metadata extraction (model, params, timestamps)             │ │
│  │  • Storage coordination (local SQLite + GCS)                   │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Storage Layer                                │
│  ┌─────────────────────┐  ┌─────────────────────────────────────┐   │
│  │   Local SQLite DB   │  │   Google Cloud Storage              │   │
│  │  • sessions         │  │  • Session logs (JSON/JSONL)        │   │
│  │  • benchmarks       │  │  • Prompt artifacts                 │   │
│  │  • results          │  │  • Result artifacts                 │   │
│  │  • prompts          │  │  • Metadata                         │   │
│  │  • artifacts        │  │                                     │   │
│  └─────────────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## 4. Repository Structure

```
agent-benchmarks/
├── README.md                          # Quick start for agents
├── AGENTS.md                          # Agent-facing documentation
├── CHANGELOG.md                        # Version history
├── LICENSE                             # License
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                      # CI pipeline
│   │   └── benchmark-validation.yml    # Validate benchmark results
│   ├── ISSUE_TEMPLATE/
│   │   └── benchmark-result.md         # PR template for results
│   └── PULL_REQUEST_TEMPLATE.md        # Pre-filled benchmark PR template
│
├── docs/
│   ├── architecture.md                 # This document
│   ├── agent-guide.md                  # How agents use the system
│   ├── benchmark-format.md             # Benchmark definition format
│   ├── storage-schema.md               # SQLite schema details
│   └── gcs-integration.md              # GCS setup and usage
│
├── src/
│   ├── cli/                            # CLI implementation
│   │   ├── index.ts                    # Entry point
│   │   ├── run.ts                      # `benchmark run`
│   │   ├── upload.ts                   # `benchmark upload`
│   │   ├── attach.ts                   # `benchmark attach-pr`
│   │   ├── list.ts                     # `benchmark list`
│   │   └── export.ts                   # `benchmark export`
│   │
│   ├── core/                           # Core logic
│   │   ├── orchestrator.ts              # Benchmark execution orchestration
│   │   ├── session-manager.ts          # Session lifecycle
│   │   ├── artifact-collector.ts       # Collect logs, prompts, results
│   │   ├── metadata-extractor.ts       # Extract model, params, etc.
│   │   └── result-validator.ts         # Validate benchmark results
│   │
│   ├── storage/                        # Storage layer
│   │   ├── sqlite.ts                   # SQLite operations
│   │   ├── gcs.ts                      # Google Cloud Storage
│   │   ├── schema.ts                   # Database schema definitions
│   │   └── migrations/                 # Schema migrations
│   │       ├── 001_initial.ts
│   │       └── 002_add_annotations.ts
│   │
│   ├── github/                         # GitHub integration
│   │   ├── pr-attacher.ts              # Attach results to PRs
│   │   ├── comment-formatter.ts        # Format results as comments
│   │   └── api-client.ts               # GitHub API wrapper
│   │
│   └── types/                          # TypeScript types
│       ├── session.ts
│       ├── benchmark.ts
│       ├── result.ts
│       └── artifact.ts
│
├── benchmarks/                         # Benchmark definitions
│   ├── README.md                       # How to define benchmarks
│   ├── definitions/                    # Benchmark YAML/JSON files
│   │   ├── memory-retrieval.yaml
│   │   ├── context-projection.yaml
│   │   └── token-savings.yaml
│   └── suites/                         # Benchmark suites
│       ├── memory-suite.yaml
│       └── context-suite.yaml
│
├── fixtures/                           # Test fixtures
│   ├── sample-session.jsonl
│   ├── sample-result.json
│   └── sample-prompts/
│
├── scripts/                            # Utility scripts
│   ├── setup-gcs.sh                    # GCS bucket setup
│   ├── setup-github-secrets.sh         # Configure GitHub secrets
│   └── migrate-db.sh                   # Database migrations
│
├── tests/                              # Test suite
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── templates/                          # Result templates
│   ├── pr-comment.md                   # PR comment template
│   ├── result-summary.md               # Summary template
│   └── comparison-report.md            # Comparison report
│
└── examples/                           # Example usage
    ├── basic-usage/
    ├── advanced-configuration/
    └── ci-integration/
```

## 5. SQLite Schema Design

### 5.1 Entity Relationship Diagram

```
┌─────────────────┐
│   benchmarks    │
├─────────────────┤
│ id (PK)         │
│ name            │
│ description     │
│ type            │
│ config (JSON)   │
│ created_at      │
│ updated_at      │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌─────────────────┐
│    sessions     │
├─────────────────┤
│ id (PK)         │
│ benchmark_id FK │
│ status          │
│ started_at      │
│ completed_at    │
│ model           │
│ params (JSON)   │
│ gcs_path        │
│ local_path      │
│ created_at      │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌─────────────────┐
│    artifacts    │
├─────────────────┤
│ id (PK)         │
│ session_id FK   │
│ type            │
│ name            │
│ gcs_path        │
│ local_path      │
│ size_bytes      │
│ content_hash    │
│ created_at      │
└─────────────────┘

┌─────────────────┐
│     results     │
├─────────────────┤
│ id (PK)         │
│ session_id FK   │
│ metric_name     │
│ metric_value    │
│ unit            │
│ metadata (JSON) │
│ created_at      │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌─────────────────┐
│  annotations    │
├─────────────────┤
│ id (PK)         │
│ result_id FK    │
│ author          │
│ comment         │
│ created_at      │
└─────────────────┘
```

### 5.2 Table Definitions

#### `benchmarks`
```sql
CREATE TABLE benchmarks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL,  -- 'memory', 'context', 'token', 'custom'
    config JSON,         -- Benchmark-specific configuration
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    
    UNIQUE(name, type)
);
```

#### `sessions`
```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    benchmark_id TEXT NOT NULL REFERENCES benchmarks(id),
    status TEXT NOT NULL,  -- 'pending', 'running', 'completed', 'failed'
    started_at TEXT NOT NULL DEFAULT (datetime('now')),
    completed_at TEXT,
    model TEXT,            -- LLM model used
    params JSON,           -- Model parameters (temperature, etc.)
    prompt_hash TEXT,      -- Hash of the prompt used
    gcs_path TEXT,         -- Path in GCS bucket
    local_path TEXT,       -- Local file path
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_sessions_benchmark ON sessions(benchmark_id);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_started ON sessions(started_at);
```

#### `artifacts`
```sql
CREATE TABLE artifacts (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id),
    type TEXT NOT NULL,    -- 'log', 'prompt', 'result', 'trace', 'config'
    name TEXT NOT NULL,
    gcs_path TEXT,         -- Path in GCS bucket
    local_path TEXT,       -- Local file path
    size_bytes INTEGER,
    content_hash TEXT,     -- SHA-256 for integrity
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_artifacts_session ON artifacts(session_id);
CREATE INDEX idx_artifacts_type ON artifacts(type);
```

#### `results`
```sql
CREATE TABLE results (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id),
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    unit TEXT,             -- 'tokens', 'ms', 'bytes', 'percent'
    metadata JSON,         -- Additional context
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_results_session ON results(session_id);
CREATE INDEX idx_results_metric ON results(metric_name);
```

#### `annotations`
```sql
CREATE TABLE annotations (
    id TEXT PRIMARY KEY,
    result_id TEXT NOT NULL REFERENCES results(id),
    author TEXT NOT NULL,  -- Who added the annotation
    comment TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_annotations_result ON annotations(result_id);
```

### 5.3 Database Location

**Default:** `~/.opencode/benchmarks.db`

**Custom:** `BENCHMARK_DB_PATH` environment variable

**GCS Sync:** The SQLite file itself can be uploaded to GCS for backup/sharing between agents.

## 6. CLI Interface Design

### 6.1 Command Overview

```bash
# Run a benchmark
benchmark run <benchmark-name> [options]

# Upload session to GCS
benchmark upload <session-id> [options]

# Attach results to PR
benchmark attach-pr <session-id> <pr-number> [options]

# List benchmark sessions
benchmark list [benchmark-name] [options]

# Export results
benchmark export <session-id> [options]

# Get session details
benchmark show <session-id>

# Compare sessions
benchmark compare <session-id-1> <session-id-2>

# Initialize (create DB, setup GCS)
benchmark init
```

### 6.2 Detailed Command Specifications

#### `benchmark run`
```bash
benchmark run <benchmark-name> \
  --model <model-name> \
  --prompt <prompt-file-or-string> \
  --params <json-string> \
  --output <local-path> \
  [--no-upload] \
  [--tag <tag>]
```

**Example:**
```bash
benchmark run memory-retrieval \
  --model "gpt-4" \
  --prompt "Find all decisions from yesterday's session" \
  --params '{"temperature": 0.7}' \
  --output ./results/ \
  --tag "v1.2.0"
```

**Output:**
```json
{
  "session_id": "sess_20261010_abc123",
  "benchmark_id": "memory-retrieval",
  "status": "running",
  "artifacts_collected": 0,
  "upload_status": "pending"
}
```

#### `benchmark upload`
```bash
benchmark upload <session-id> \
  [--bucket <bucket-name>] \
  [--path <gcs-path>]
```

**Example:**
```bash
benchmark upload sess_20261010_abc123 \
  --bucket opencode-benchmarks \
  --path sessions/2026/10/10/
```

#### `benchmark attach-pr`
```bash
benchmark attach-pr <session-id> <pr-number> \
  [--repo <owner/repo>] \
  [--comment-style <summary|detailed>]
```

**Example:**
```bash
benchmark attach-pr sess_20261010_abc123 42 \
  --repo gpt-mem/opencode-mem \
  --comment-style detailed
```

**Result:** Creates PR comment with:
- Benchmark metadata
- Key metrics
- Comparison with baseline (if available)
- Link to full session in GCS

#### `benchmark list`
```bash
benchmark list [benchmark-name] \
  [--status completed] \
  [--since 2026-10-01] \
  [--limit 20] \
  [--format table|json]
```

**Output:**
```
SESSION ID              BENCHMARK           MODEL    STATUS     STARTED
sess_20261010_abc123    memory-retrieval    gpt-4    completed  2026-10-10 14:30
sess_20261010_def456    context-projection  gpt-4    completed  2026-10-10 14:15
```

#### `benchmark show`
```bash
benchmark show <session-id> [--format json|yaml|table]
```

#### `benchmark compare`
```bash
benchmark compare <session-id-1> <session-id-2> \
  [--metrics tokens,latency] \
  [--format table|json]
```

**Output:**
```
METRIC          SESSION 1    SESSION 2    DELTA
tokens          12,345       8,901        -3,444 (-27.9%)
latency_ms      2,340        1,890        -450 (-19.2%)
cache_hit_rate  0.85         0.92         +0.07 (+7.0%)
```

### 6.3 Environment Variables

```bash
# Database
BENCHMARK_DB_PATH=~/.opencode/benchmarks.db

# Google Cloud Storage
BENCHMARK_GCS_BUCKET=opencode-benchmarks
BENCHMARK_GCS_PROJECT=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

# GitHub
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
GITHUB_REPO=gpt-mem/opencode-mem

# Agent
OPENCODE_BENCHMARK_AUTO_UPLOAD=1
OPENCODE_BENCHMARK_DEFAULT_TAGS=production,automated
```

## 7. Google Cloud Storage Integration

### 7.1 Bucket Structure

```
gs://opencode-benchmarks/
├── sessions/
│   ├── 2026/
│   │   ├── 10/
│   │   │   ├── 10/
│   │   │   │   ├── sess_20261010_abc123/
│   │   │   │   │   ├── metadata.json
│   │   │   │   │   ├── session.jsonl
│   │   │   │   │   ├── prompts/
│   │   │   │   │   │   ├── system.txt
│   │   │   │   │   │   ├── user.txt
│   │   │   │   │   │   └── assistant.txt
│   │   │   │   │   ├── results/
│   │   │   │   │   │   └── metrics.json
│   │   │   │   │   └── traces/
│   │   │   │   │       └── tool-calls.jsonl
│   │   │   │   └── sess_20261010_def456/
│   │   │   └── ...
│   │   └── ...
│   └── ...
├── benchmarks/
│   ├── memory-retrieval/
│   │   └── latest -> ../../sessions/2026/10/10/sess_xxx/
│   └── context-projection/
│       └── latest -> ...
└── baselines/
    ├── memory-retrieval-baseline.json
    └── context-projection-baseline.json
```

### 7.2 Authentication

**Service Account Key:**
- Stored in GitHub Secrets as `GCS_SERVICE_ACCOUNT_KEY`
- Path: `~/.config/gcloud/application_default_credentials.json` (local)
- Injected as secret in CI/CD

**Setup Commands:**
```bash
# One-time setup
./scripts/setup-gcs.sh --project your-project-id --bucket opencode-benchmarks

# GitHub Secrets setup
./scripts/setup-github-secrets.sh --repo gpt-mem/opencode-mem
```

### 7.3 Upload Strategy

```typescript
interface UploadConfig {
  bucket: string;
  path: string;
  metadata: Record<string, string>;
  contentType: string;
  gzip?: boolean;
  retryAttempts?: number;
}

// Upload with exponential backoff
async function uploadToGCS(
  localPath: string,
  config: UploadConfig
): Promise<string> {
  // 1. Calculate content hash
  // 2. Check if already exists (idempotent)
  // 3. Upload with retry
  // 4. Verify integrity
  // 5. Return GCS URI
}
```

## 8. Agent Workflow Integration

### 8.1 MCP Tool Integration

```typescript
// tools/benchmark.ts
export const benchmarkTools = {
  run_benchmark: async (params: {
    name: string;
    model?: string;
    prompt: string;
    params?: Record<string, any>;
  }) => {
    // Execute benchmark
    // Store in SQLite
    // Upload to GCS (if configured)
    // Return session ID and results
  },
  
  upload_session: async (sessionId: string) => {
    // Upload to GCS
    // Update session record
  },
  
  attach_to_pr: async (sessionId: string, prNumber: number) => {
    // Format results
    // Post PR comment
  },
  
  compare_sessions: async (sessionIds: string[]) => {
    // Fetch results
    // Calculate deltas
    // Format comparison
  }
};
```

### 8.2 OpenCode Integration

**In `opencode-mem` repository:**

```typescript
// packages/core/src/benchmark/index.ts
import { runBenchmark } from 'agent-benchmarks';

export async function executeBenchmark(config: BenchmarkConfig) {
  const result = await runBenchmark({
    name: config.name,
    model: config.model,
    prompt: config.prompt,
    params: config.params
  });
  
  // Auto-attach to PR if in CI
  if (process.env.CI && process.env.GITHUB_PR_NUMBER) {
    await attachToPR(result.sessionId, parseInt(process.env.GITHUB_PR_NUMBER));
  }
  
  return result;
}
```

### 8.3 CI/CD Integration

```yaml
# .github/workflows/benchmark.yml
name: Benchmark

on:
  push:
    branches: [memory-context-v1]
  pull_request:
    branches: [dev]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
      
      - name: Install dependencies
        run: npm ci
      
      - name: Setup GCS credentials
        run: |
          echo "${{ secrets.GCS_SERVICE_ACCOUNT_KEY }}" | base64 -d > gcs-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=gcs-key.json
      
      - name: Run benchmark
        id: benchmark
        run: |
          npx benchmark run memory-retrieval \
            --model "gpt-4" \
            --prompt "Test memory retrieval accuracy" \
            --tag "pr-${{ github.event.number }}"
      
      - name: Upload results
        run: |
          npx benchmark upload ${{ steps.benchmark.outputs.session-id }}
      
      - name: Attach to PR
        if: github.event_name == 'pull_request'
        run: |
          npx benchmark attach-pr \
            ${{ steps.benchmark.outputs.session-id }} \
            ${{ github.event.number }} \
            --repo ${{ github.repository }}
```

## 9. PR Attachment Format

### 9.1 Summary Comment (default)

```markdown
## Benchmark Results: memory-retrieval

**Session ID:** `sess_20261010_abc123`  
**Model:** gpt-4  
**Completed:** 2026-10-10 14:30:00 UTC

### Key Metrics

| Metric | Value | Baseline | Delta |
|--------|-------|----------|-------|
| Token Savings | 12,345 | 15,000 | -2,655 (-17.7%) |
| Latency | 2,340ms | 2,500ms | -160ms (-6.4%) |
| Cache Hit Rate | 85% | 82% | +3% |

### Artifacts

- [Full Session Log](https://storage.googleapis.com/opencode-benchmarks/sessions/2026/10/10/sess_xxx/session.jsonl)
- [Detailed Results](https://storage.googleapis.com/opencode-benchmarks/sessions/2026/10/10/sess_xxx/results/metrics.json)
- [Prompt Used](https://storage.googleapis.com/opencode-benchmarks/sessions/2026/10/10/sess_xxx/prompts/)

### Summary

This benchmark shows a 17.7% improvement in token savings compared to baseline...
```

### 9.2 Detailed Comment

Includes additional sections:
- Full parameter breakdown
- Tool call analysis
- Error analysis
- Comparison with previous runs
- Recommendations

## 10. Security Considerations

### 10.1 Data Privacy

- **No public access:** All GCS objects are private
- **Signed URLs:** Use signed URLs for temporary access (24h expiry)
- **Encryption:** GCS default encryption (Google-managed keys)
- **PII handling:** Results are PII-scanned before storage

### 10.2 Access Control

```yaml
# IAM roles
roles/storage.objectAdmin:
  - serviceAccount: benchmark-uploader@project.iam.gserviceaccount.com

roles/storage.objectViewer:
  - group: benchmark-viewers@gpt-mem.com
  - serviceAccount: ci-runner@project.iam.gserviceaccount.com
```

### 10.3 Secret Management

| Secret | Location | Rotation |
|--------|----------|----------|
| GCS Service Account Key | GitHub Secrets | 90 days |
| GitHub Token | GitHub Secrets | 180 days |
| API Keys (LLM) | Agent env vars | Per provider policy |

## 11. Implementation Phases

### Phase 1: Core Infrastructure (Week 1)
- [ ] Create `agent-benchmarks` repository
- [ ] Implement SQLite schema and migrations
- [ ] Build basic CLI (`run`, `list`, `show`)
- [ ] Implement artifact collection
- [ ] Write core tests

### Phase 2: Storage Integration (Week 2)
- [ ] Implement GCS upload
- [ ] Add GCS configuration and setup scripts
- [ ] Implement signed URL generation
- [ ] Add GCS integration tests

### Phase 3: GitHub Integration (Week 3)
- [ ] Implement PR attachment
- [ ] Build comment formatter
- [ ] Add GitHub API client
- [ ] Write integration tests

### Phase 4: Agent Tools (Week 4)
- [ ] Implement MCP tools
- [ ] Add OpenCode integration
- [ ] Write agent documentation
- [ ] Create example benchmarks

### Phase 5: Polish and Launch (Week 5)
- [ ] Add comparison features
- [ ] Implement baseline tracking
- [ ] Write comprehensive documentation
- [ ] Create demo benchmarks
- [ ] Internal testing with agents

## 12. Example Usage

### 12.1 Agent Workflow Example

```bash
# 1. Run a benchmark
$ benchmark run memory-retrieval \
    --model "gpt-4" \
    --prompt "Find all decisions from session-123" \
    --tag "validation"

Session started: sess_20261010_abc123
Collecting artifacts...

# 2. Upload to GCS
$ benchmark upload sess_20261010_abc123

Uploading to gs://opencode-benchmarks/sessions/2026/10/10/sess_xxx/
✓ metadata.json (1.2 KB)
✓ session.jsonl (245 KB)
✓ prompts/system.txt (3.4 KB)
✓ prompts/user.txt (1.1 KB)
✓ results/metrics.json (892 B)

Upload complete!

# 3. Attach to PR
$ benchmark attach-pr sess_20261010_abc123 42

Posting comment to PR #42...
✓ Comment posted: https://github.com/gpt-mem/opencode-mem/pull/42#issuecomment-1234567890

# 4. Compare with baseline
$ benchmark compare sess_20261010_abc123 baseline

METRIC          CURRENT      BASELINE     DELTA
tokens          8,901        15,000       -6,099 (-40.7%)
latency_ms      1,890        2,500        -610 (-24.4%)
```

### 12.2 Local Session Upload

```bash
# User has a session file locally
$ benchmark upload-local ./my-session.jsonl \
    --benchmark memory-retrieval \
    --model gpt-4 \
    --tag "manual-upload"

Session imported: sess_local_20261010_xyz789
```

## 13. Next Steps

1. **Review this design document** with team
2. **Create `agent-benchmarks` repository** in GitHub
3. **Set up GCS bucket** and service account
4. **Implement Phase 1** (core infrastructure)
5. **Test with simple benchmark** (memory retrieval)
6. **Iterate based on agent feedback**

## 14. Open Questions

1. Should benchmarks support concurrent execution?
2. Do we need real-time progress reporting for long-running benchmarks?
3. Should we support benchmark result aggregation across multiple runs?
4. Do we need a web UI for browsing results?
5. Should we integrate with other storage providers (S3, Azure)?

---

**Document Version:** 1.0  
**Last Updated:** 2026-10-10
