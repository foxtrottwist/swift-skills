# Agent File Optimization Guide

> Portable reference for reviewing, writing, and maintaining CLAUDE.md files, skills, and agent definitions.
> Any Claude instance with this document has the evidence base, procedures, and examples to execute.
> February 2026 — Synthesized from academic research, practitioner interviews, and field-tested examples.

---

## How to Use This Document

This guide serves two purposes. When **reviewing** existing agent files, follow the checklists in Section 5. When **writing** new agent files, follow the templates and examples in Sections 4 and 6. The principles in Section 3 provide the reasoning behind every checklist item — consult them when a decision isn't clear-cut.

---

## 1. Sources and Attribution

### Academic Research

**Paper 1: "Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?"**
Authors: Thibaud Gloaguen, Niels Mündler, Mark Müller, Veselin Raychev, Martin Vechev (ETH Zurich / SRI Lab). Published February 12, 2026.
[arxiv.org/abs/2602.11988](https://arxiv.org/abs/2602.11988) | Code: [github.com/eth-sri/agentbench](https://github.com/eth-sri/agentbench)

**Paper 2: "SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks"**
Authors: Xiangyi Li, Wenbo Chen, Yimin Liu, Shenghan Zheng, et al. (40+ authors). Published February 13, 2026.
[arxiv.org/abs/2602.12670](https://arxiv.org/abs/2602.12670)

### Practitioner Source

**Boris Cherny** — Creator and Head of Claude Code at Anthropic. 100% of his code has been written by Claude Code since November 2025.

- [Lenny's Podcast interview, February 2026](https://www.lennysnewsletter.com/p/head-of-claude-code-what-happens)
- [howborisusesclaudecode.com](https://howborisusesclaudecode.com/) (40 tips across 4 posts)
- [Boris's team tips gist](https://gist.github.com/joyrexus/e20ead11b3df4de46ab32b4a7269abe0)
- [Push to Prod summary](https://getpushtoprod.substack.com/p/how-the-creator-of-claude-code-actually)

### Skill Routing Research

Based on Claude Code skill routing analysis, Anthropic official documentation, and empirical activation rate testing across 200+ prompts.

### Field Examples

Real-world examples in this guide are drawn from a production Claude Code plugin (20 skills, 4 agents) evaluated against the research findings above. The review rated each skill on signal-to-noise, focus, worked examples, prescription level, domain specificity, verification, and token cost.

---

## 2. What the Research Found

### Context Files: Cost vs. Benefit

The ETH Zurich study tested CLAUDE.md, AGENTS.md, and COPILOT.md files across multiple coding agents. Context files generally reduce task success rates while increasing inference cost.

| Condition | Performance Effect | Cost Effect |
|---|---|---|
| LLM-generated context files | -0.5% to -2% resolve rate | +20–23% cost |
| Human-written context files | +4% average on AGENTbench | +up to 19% cost |
| No context file (baseline) | — | — |

Agents follow instructions reliably (tools mentioned in context files are used 1.6x more frequently), but the instructions themselves often don't help. Context files cause agents to burn 14–22% more reasoning tokens without improving resolve rates.

The one exception: under-documented repositories. When documentation was stripped from repos, LLM-generated context files improved performance by 2.7%. Context files have value as a documentation substitute, not a supplement.

> "LLM-generated context files have a small negative effect on agent performance."
> — Gloaguen et al., 2026

### Skills: Focused Beats Comprehensive

The SkillsBench study tested curated procedural knowledge files (skills) across 84 diverse tasks.

| Configuration | No Skills | With Skills | Delta |
|---|---|---|---|
| Opus 4.5 | 22.0% | 45.3% | **+23.3pp** |
| Opus 4.6 | 30.6% | 44.5% | +13.9pp |
| Sonnet 4.5 | 17.3% | 31.8% | +14.5pp |
| Haiku 4.5 | 11.0% | 27.7% | +16.7pp |

Three findings stand out:

1. **Self-generated skills are useless or harmful** (-1.3pp average). Models cannot reliably author the procedural knowledge they benefit from consuming.
2. **2–3 focused modules beat comprehensive documentation.** Comprehensive skills had a -2.9pp delta vs. no skills. Concise, stepwise guidance with at least one worked example is the formula.
3. **Skills partially substitute for model scale.** Haiku 4.5 + Skills (27.7%) beat Opus 4.5 without Skills (22.0%).

**Over-prescription causes harm:** 16 of 84 tasks (19%) showed negative deltas. Software Engineering showed the smallest gain (+4.5pp) because models already know generic coding. Specialized domains like Healthcare gained +51.9pp.

> "Skills are most helpful when success depends on concrete procedures and verifier-facing details (steps, constraints, sanity checks), rather than broad conceptual knowledge."
> — SkillsBench, 2026

### The Shortcut Anti-Pattern

Rich output templates in the skill body give Claude enough scaffolding to respond *without following the full workflow*. The templates become a shortcut that bypasses the procedure.

**Before (shortcut-enabling):**
```
**Output format:**
## [Brief Title]
**TL;DR:** [One sentence — what you did and the outcome]
### Situation
[Context — what was happening...]
### Action
[What YOU did — be specific...]
### Result
[Outcome — quantify if possible...]
```

**After (procedure-enforcing):**
> STAR format — Situation/Task/Action/Result. TL;DR one sentence. Resume bullet ≤30 words, action verb + quantified result.

Constraint lines tell Claude *what must be true* without giving it a fill-in-the-blank template.

### Practitioner Corroboration

Boris Cherny's workflow aligns with the research:

- **Verification over instruction.** "Give Claude a way to verify its work. If Claude has that feedback loop, it will 2–3x the quality of the final result."
- **Correction-driven CLAUDE.md.** "Anytime we see Claude do something incorrectly we add it to the CLAUDE.md, so Claude knows not to do it next time." Rules are added reactively, not generated upfront.
- **Skills as repeatable workflows.** Slash commands in `.claude/commands/` and subagents in `.claude/agents/`. Threshold: if you do something more than once daily, encode it.
- **Subagents for context protection.** Complex subtasks run in isolated agents with worktree isolation, returning only results to the main session.

---

## 3. Principles

### Principle 1: Prescribe, Don't Describe

Include only hard requirements an agent cannot discover on its own. Specific build tools, test runners, environment constraints, naming conventions that differ from defaults. Agents already navigate codebases effectively — 67% of human-written context files include repository overviews, and these do not reduce the steps an agent takes to find relevant files (ETH Zurich).

- **Good:** `Use uv for package management`
- **Bad:** `This project uses uv for package management, which handles virtual environments and…`

### Principle 2: Write Reactively, Not Proactively

Start with an empty or minimal CLAUDE.md. Add rules only when you observe a failure. Each entry should trace back to a specific incident. LLM-generated context files performed worse than no context file at all (ETH Zurich). Boris's team adds entries only when Claude makes a mistake.

### Principle 3: Focus Skills on 2–3 Modules — Eliminate Templates

Each skill file should cover one procedure with at least one complete worked example. Remove output format templates — they enable shortcuts that bypass the procedure (see Shortcut Anti-Pattern above). Comprehensive skills degraded performance by -2.9pp (SkillsBench).

### Principle 4: Invest in Verification, Not Instruction

Instead of writing more instructions, give the agent a way to check its own work. A one-line test command in CLAUDE.md is worth more than a paragraph of style guidance. Context files increase exploration tokens by 14–22% without improving outcomes; verification loops 2–3x quality.

### Principle 5: Specialize for Your Domain

Don't write skills for things the model already knows (REST API patterns, React structure, Git workflows). Write skills for your project's unique conventions, domain-specific APIs, unusual architectures, post-training-cutoff knowledge, and proprietary tooling.

### Principle 6: Protect Context with Subagents

Use `.claude/agents/` for complex subtasks. Each agent gets only the context it needs. Results flow back without polluting the main session. Context files increase reasoning tokens by 14–22% per task — for parallel subagent workflows, this compounds multiplicatively.

### Principle 7: Never Auto-Generate Context Files

Do not use `claude init` or any automated tool to generate CLAUDE.md content. Both papers agree: LLM-generated context files had -0.5% to -2% effect on resolve rate (ETH Zurich); self-generated skills were -1.3pp on average (SkillsBench).

### Principle 8: Separate Routing from Execution

Skill descriptions are always loaded in context, even when the body is not. The description routes (when to invoke); the body executes (how to act).

| | Description (frontmatter) | Body (SKILL.md content) |
|---|---|---|
| **Purpose** | Routing — when to invoke | Execution — how to act |
| **Always in context?** | Yes | No (loaded on invocation) |
| **Content** | Trigger phrases, use-when framing | Procedure, worked example, constraints |
| **Behavioral instructions?** | Never | Yes |
| **Trigger keywords?** | Yes | No |

Testing across 200+ prompts: optimized descriptions improve activation from 20% to 50%; adding quoted trigger examples reaches 90%. Anthropic recommends making descriptions "a little bit pushy" to combat undertriggering.

---

## 4. Templates

### CLAUDE.md Template

An effective CLAUDE.md contains these categories — and nothing else:

```markdown
# CLAUDE.md

## Build and Test
{Exact commands to build, test, lint, and run the project}

## Constraints
{Naming conventions, file organization rules, concurrency model — things
that differ from language/framework defaults and can't be inferred from code}

## Corrections
{Specific mistakes that have occurred. Phrased as imperatives.}
- Do X, not Y.
- Use A instead of B for C.

## Gotchas
{Non-obvious traps: framework bugs, workarounds, environment quirks}
```

**Omit:** repository overviews, architecture descriptions that duplicate what the code shows, explanations of why decisions were made, general language/framework guidance.

### Skill Description (Frontmatter) Template

```yaml
---
name: {skill-name}
description: "{One sentence: what + domain}. Use when {3–5 use cases}.
  Triggers on: '{exact phrase 1}', '{exact phrase 2}', '{exact phrase 3}'.
  {Technical keywords for secondary matching}."
---
```

### Skill Body Template

```markdown
# {Skill Name}

{One sentence scope — what this skill does.}

## {Core Procedure Section}

{Numbered steps or clear subsections. Each step is an action with specific
tool/command/API call. No background theory.}

## Worked Example

{A complete input → action → output sequence showing the procedure applied
to a realistic case.}

## Constraints

- Never {X}.
- Always {Y} before {Z}.
- {Boundary condition or safety rule.}
```

### Agent Definition Template

```markdown
# {Agent Name}

{One sentence: what this agent does and its access level (read-only, write, etc.)}

## Operating Principles

{3–5 behavioral constraints. Phrased as imperatives.}

## Output

{What the agent returns. Format specification if structured.}

## Constraints

- {What this agent must NOT do.}
- {Scope boundary.}
```

---

## 5. Review Checklists

### Reviewing a Skill

| # | Question | If Yes | Principle |
|---|----------|--------|-----------|
| 1 | Is the main skill body >200 lines? | Split into focused modules with reference files | P3 |
| 2 | Does the body contain output format templates with `[placeholder]` syntax? | Replace with 1–2 constraint lines | P3 / Shortcut |
| 3 | Does the body contain a "When to Use" section? | Remove — the description field handles routing | P8 |
| 4 | Does the description contain behavioral instructions? | Move them to the body | P8 |
| 5 | Does the description include quoted trigger phrases? | If not, add them — activation rates improve from 50% to 90% | P8 |
| 6 | Does the skill teach generic knowledge the model already has? | Cut it or compress to behavioral constraints only | P5 |
| 7 | Does the skill include a worked example? | If not, add one — most commonly missing element | P3 |
| 8 | Does the skill include a verification mechanism? | If not, consider adding one — tests, lint script, build check | P4 |

### Reviewing an Agent Definition

| # | Question | If Yes | Principle |
|---|----------|--------|-----------|
| 1 | Is it >100 lines? | Compress — agents should be behavioral constraints, not methodology | P1 |
| 2 | Does it describe a methodology the model already knows? | Replace with behavioral constraints | P5 |
| 3 | Does it clearly state what the agent must NOT do? | If not, add scope boundaries | P1 |
| 4 | Does it duplicate content from a skill or another agent? | Keep one authoritative copy | Cost |

---

## 6. Improvement Procedures

### Writing a New Skill from Scratch

1. Check if it's needed — does this encode knowledge the model already has?
2. Write the description first: one sentence + "Use when" + quoted triggers + keywords.
3. Write the body: scope → procedure → worked example → constraints.
4. Verify the worked example is complete — realistic request, exact actions, expected output.
5. Check for `[placeholder]` output templates — replace with constraint lines.
6. Check line count — if >200 lines, split into main + references.
7. Test activation with 3–5 natural-language prompts.

### Writing a New Agent Definition

1. One sentence scope with access level (read-only, write, etc.)
2. 3–5 behavioral constraints as operating principles — phrased as imperatives.
3. Clear output specification.
4. Explicit scope boundaries — what the agent must NOT do.
5. Target <100 lines total.

---

## 7. Key Quotes

> "Give Claude a way to verify its work. If Claude has that feedback loop, it will 2–3x the quality of the final result."
> — Boris Cherny, Lenny's Podcast, Feb 2026

> "Anytime we see Claude do something incorrectly we add it to the CLAUDE.md, so Claude knows not to do it next time."
> — Boris Cherny, howborisusesclaudecode.com

> "LLM-generated context files have a small negative effect on agent performance."
> — Gloaguen et al., ETH Zurich, Feb 2026

> "Focused Skills with 2–3 modules outperform comprehensive documentation, and smaller models with Skills can match larger models without them."
> — SkillsBench, Feb 2026

> "Self-generated Skills provide no benefit on average, showing that models cannot reliably author the procedural knowledge they benefit from consuming."
> — SkillsBench, Feb 2026

---

## 8. Source Index

- Gloaguen et al. (2026). *Evaluating AGENTS.md.* [arXiv:2602.11988](https://arxiv.org/abs/2602.11988)
- Li et al. (2026). *SkillsBench.* [arXiv:2602.12670](https://arxiv.org/abs/2602.12670)
- [Lenny's Podcast: Head of Claude Code](https://www.lennysnewsletter.com/p/head-of-claude-code-what-happens)
- [howborisusesclaudecode.com](https://howborisusesclaudecode.com/)
