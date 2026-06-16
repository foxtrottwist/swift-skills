# swift-skills

A Claude Code plugin for Swift and iOS development. Four skills covering on-device AI, persistence, accessibility, and logging patterns.

> **SwiftUI is covered by Apple's official Xcode 27 agent skills** (swiftui-specialist, swiftui-whats-new-27, etc.), which are authoritative. This plugin no longer ships a SwiftUI/iOS-26 reference.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **foundation-models** | `@Generable`, `LanguageModelSession`, on-device LLM | Complete guide for Apple's Foundation Models framework (iOS 26+). API reference, anti-patterns, decision trees, diagnostics, Instruments triage, production crisis defense. |
| **axiom-swiftdata** | `@Model`, `@Query`, `ModelContext`, CloudKit sync | SwiftData persistence patterns — model definitions, queries in SwiftUI, relationships, migration, and CloudKit integration. |
| **axiom-accessibility-diag** | VoiceOver, Dynamic Type, color contrast, WCAG | Accessibility diagnostics for iOS/macOS — systematic diagnosis with lint patterns and App Store Review preparation. |
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

The plugin includes one hook that activates automatically during Swift/iOS work:

- **swift-patterns** (PreToolUse) — blocks deprecated Swift patterns on Edit/Write (NavigationView, `.cornerRadius`, print/NSLog, ObservableObject, force-unwrapped URLs)

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
