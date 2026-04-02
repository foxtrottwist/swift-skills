# swift-skills

A Claude Code plugin for Swift, SwiftUI, and iOS development. Six skills covering on-device AI, persistence, modern UI, accessibility, CLI tooling, and logging patterns.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **foundation-models** | `@Generable`, `LanguageModelSession`, on-device LLM | Complete guide for Apple's Foundation Models framework (iOS 26+). API reference, anti-patterns, decision trees, diagnostics, Instruments triage, production crisis defense. |
| **axiom-swiftdata** | `@Model`, `@Query`, `ModelContext`, CloudKit sync | SwiftData persistence patterns — model definitions, queries in SwiftUI, relationships, migration, and CloudKit integration. |
| **axiom-swiftui-26-ref** | iOS 26 SwiftUI, Liquid Glass, `@Animatable` | iOS 26+ SwiftUI features — Liquid Glass design system, 3D spatial layout, WebView, rich text, drag/drop, visionOS. |
| **axiom-accessibility-diag** | VoiceOver, Dynamic Type, color contrast, WCAG | Accessibility diagnostics for iOS/macOS — systematic diagnosis with lint patterns and App Store Review preparation. |
| **swizzle** | `swizzle`, eval pipelines, FM testing | Swizzle CLI integration — Foundation Models eval, NLP operations, SwiftData inspection, os_log streaming. |
| **swift-structured-logging** | Logging, `os.Logger`, `SBLogger` | Structured logging patterns for Swift/macOS apps using actor-based sinks and domain-labeled categories. |

## Complementary Community Plugins

These community plugins cover areas that complement swift-skills. Install them alongside for broader Swift/iOS coverage:

| Plugin | Author | Coverage |
|--------|--------|----------|
| [Skills](https://github.com/dimillian/Skills) | Thomas Ricouard | SwiftUI architecture, Swift concurrency, app lifecycle patterns |
| [SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) | Paul Hudson | SwiftUI view composition, modifiers, layout system |
| [Axiom](https://github.com/CharlesWiltgen/Axiom) | Charles Wiltgen | Swift conventions, testing patterns, code review |

## Install

```
/plugin marketplace add Foxtrottwist/swift-skills
/plugin install swift-skills@swift-skills
```

Or from the CLI:

```bash
claude plugin marketplace add Foxtrottwist/swift-skills
claude plugin install swift-skills@swift-skills
```

## Hooks

The plugin includes three hooks that activate automatically during Swift/iOS work:

- **swift-patterns** (PreToolUse) — blocks deprecated Swift patterns (NSLock, DispatchQueue for sync, print/NSLog)
- **swift-skill-nudge** (UserPromptSubmit) — suggests relevant skills when Swift/iOS work is detected
- **swizzle-reminder** (PostToolUse) — reminds to check logs after Xcode builds/tests

## Development

### Local testing

```bash
claude --plugin-dir .
```

### Validate and package

```bash
bash build.sh     # validate plugin structure
bash package.sh   # package skills into dist/*.skill
```

## Origin

This plugin was extracted from [workflow-tools](https://github.com/Foxtrottwist/workflow-tools) v0.26.0, which previously bundled both productivity and Swift/iOS skills. The Swift skills were split out to allow independent versioning and focused development. The foundation-models skill was consolidated from three separate skills (ref, discipline, diagnostics) during the extraction.

## License

MIT
