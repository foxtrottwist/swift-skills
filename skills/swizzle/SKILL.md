---
name: swizzle
description: "Use the Swizzle CLI for Foundation Models eval pipelines, NLP operations, SwiftData inspection, and os_log streaming on macOS. Use when running evals, testing FM prompts, scoring model responses, comparing eval runs, checking FM availability, performing NLP analysis, inspecting SwiftData stores, or streaming os_log. Triggers on: 'run eval', 'test prompt', 'check FM', 'swizzle', 'eval diff', 'score response', 'nlp entity', 'db stats', 'stream logs'. The CLI is installed in the user's PATH."
---

# Swizzle CLI

Native macOS developer CLI with on-device Foundation Models access. Binary: `swizzle` (in PATH). Global flags: `--profile <name>`, `-v/--verbose`.

## Commands

### `fm` — Foundation Models

```bash
swizzle fm check [--verbose]           # Check FM availability
swizzle fm prompt --content <text>     # Send prompt to FM
  [--instruction <text>]               # System instructions
  [--expected <text>]                  # Expected output (enables scoring)
  [--scoring summary|synthesis|keyterm|exact]
  [--generable]                        # Structured output (SimpleAnswer)
```

### `eval` — Evaluation Pipelines

```bash
swizzle eval run --corpus <path.json>  # Run eval pipeline
  [--pipeline fm|nlp]                  # Default: fm
  [--scoring summary|synthesis|keyterm|exact]
  [--instructions <path.txt>]          # FM system instructions file
  [--nlp-op lemma|entity|pos|embedding] # Required for nlp pipeline

swizzle eval diff <baseline.json> <current.json>  # Compare runs
  [--regression-threshold 0.1]         # Score drop to flag
```

Results saved to `~/.swizzle/eval-results/<ISO8601>.json`.

### `nlp` — Natural Language Processing

```bash
swizzle nlp run --op <operation> --content <text>
  [--expected <text>] [--scoring <strategy>]
```

Operations: `lemma` (base word forms), `entity` (names, places, orgs), `pos` (nouns, verbs, adjectives, adverbs), `embedding` (distance between two `|`-separated words → `close` or `far`).

### `db` — SwiftData Inspection

```bash
swizzle db stats --store <path.store>  # Row counts per table
```

### `log` — os_log Streaming

```bash
swizzle log --subsystem <id> [--category <name>] [--since 1m|2h|1d]
```

### `profile` — Profile Management

```bash
swizzle profile create <name> [--subsystem <id>] [--categories a,b]
  [--store-path <path>] [--eval-corpus-path <path>] [--force]
```

Profiles at `~/.swizzle/profiles/<name>.yml`. CLI flags override profile values.

## @file Convention

Any text flag accepts `@` prefix to read from file instead of literal string. Supports tilde expansion.

```bash
--content @path/to/file.txt
--instruction @~/my-instructions.txt
```

## Corpus Format

JSON array. Each entry has `instruction` (optional FM system instruction), `content` (the prompt), `expected` (for scoring), and `scoring` (optional per-entry override). Legacy `prompt` key still decodes as `content`.

## Scoring Strategies

| Strategy | How it works |
|----------|-------------|
| **summary** | 30% token length (target 80-120) + 70% key-term overlap |
| **synthesis** | Expected split by `\|`. Per point: ≥50% key terms found = hit. Score = hits / total points |
| **keyterm** | Pure key-term overlap (stop words filtered, >2 chars, case-insensitive) |
| **exact** | Case-insensitive trimmed string equality (1.0 or 0.0) |

Pass/fail marks: ✓ ≥0.8, ~ ≥0.5, ✗ <0.5.

## Constraints

- FM responses vary ±0.1 per entry per run. Average 2+ runs before concluding a variant is better or worse.
- Change instructions, not corpus, during prompt tuning.
- Use `eval diff` to compare runs — don't eyeball score tables.

## Worked Example: Eval Tuning Loop

Write an instruction variant:
```bash
echo "Summarize in a single flowing paragraph of 80-120 tokens..." > instructions-v1.txt
```

Run the eval:
```bash
swizzle eval run --corpus corpus.json --scoring summary --instructions instructions-v1.txt -v
# Output:
#   [1/5] "Summarize the content..." ✓ (0.85)
#   [2/5] "Summarize the content..." ~ (0.62)
#   ...
#   Score: 0.71 (2/5 passed)
#   Results saved to: ~/.swizzle/eval-results/2026-03-08T13:28:20Z.json
```

Compare against baseline:
```bash
swizzle eval diff ~/.swizzle/eval-results/2026-03-07T10:00:00Z.json \
                  ~/.swizzle/eval-results/2026-03-08T13:28:20Z.json
```

Iterate on instructions. When satisfied, apply the winning instruction text to the app's FM session.