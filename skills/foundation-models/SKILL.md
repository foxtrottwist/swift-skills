---
name: foundation-models
description: "Complete guide for Apple's on-device Foundation Models framework (3B LLM, iOS 26+).
  Use when implementing, debugging, or architecting with Foundation Models.
  Triggers on: 'Foundation Models', 'LanguageModelSession', '@Generable', '@Guide',
  'on-device LLM', 'FM framework'. Covers API reference, anti-patterns, decision trees,
  diagnostics, Instruments triage, and production crisis defense."
---

# Foundation Models

3B parameter on-device LLM. 2-bit quantized, 4096 token context (input + output combined). Optimized for summarization, extraction, classification, and generation. No network, no cost, no data leaves device.

## Worked Example

**Request:** "Add article summarization with streaming to my app."

**1. Check availability:**
```swift
guard case .available = SystemLanguageModel.default.availability else {
    showUnavailableMessage()
    return
}
```

**2. Define output type:**
```swift
@Generable
struct ArticleSummary {
    @Guide(description: "One-sentence summary of the article's main point")
    var headline: String

    @Guide(.count(2...5), description: "Key takeaways in order of importance")
    var takeaways: [String]

    @Guide(.range(1...10), description: "Reading complexity score")
    var complexity: Int
}
```

**3. Stream with progressive UI:**
```swift
let session = LanguageModelSession(instructions: "Summarize articles concisely and accurately")

let stream = session.streamResponse(
    to: Prompt { "Summarize this article:"; articleText },
    generating: ArticleSummary.self
)

for try await partial in stream {
    withAnimation { self.summary = partial }
}
// partial.headline appears first, then takeaways fill in, then complexity
```

**4. Handle errors:**
```swift
catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    // Article too long — chunk it or truncate
    session = LanguageModelSession(instructions: originalInstructions)
}
```

---

## Anti-Patterns

### 1: Manual JSON Parsing

```swift
// WRONG: Manual JSON parsing — fragile, model might produce malformed output
let json = try JSONSerialization.jsonObject(with: response.content.data(using: .utf8)!)

// RIGHT: @Generable with constrained decoding — model cannot produce invalid structure
let person = try await session.respond(to: "Generate a person", generating: Person.self).content
```

### 2: Blocking UI with Synchronous Generation

```swift
// WRONG: User waits for entire response
self.text = try await session.respond(to: prompt).content

// RIGHT: Streaming for progressive display
for try await partial in session.streamResponse(to: prompt) {
    withAnimation { self.text = partial.content }
}
```

### 3: Context Overflow from Unbounded Conversations

```swift
// WRONG: Endless multi-turn — crashes at 4096 token limit

// RIGHT: Catch and recover
catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    session = LanguageModelSession(instructions: originalInstructions)
}
```

The 4096 token context is TOTAL — instructions + schema + transcript + new prompt + output.

### 4: User Input in Instructions (Prompt Injection)

```swift
// WRONG: User input in instructions
let session = LanguageModelSession(instructions: "Summarize: \(userInput)")

// RIGHT: User input in prompt only
let session = LanguageModelSession(instructions: "You summarize text concisely")
let response = try await session.respond(to: userInput)
```

Instructions are developer-controlled. Model trained to prioritize instructions over prompts.

### 5: Struct for Stateful Tools

Use `class` (not `struct`) when tools track state across calls. Struct copies lose mutations between calls.

### 6: Over-Complex Instructions Duplicating @Generable

`@Generable` and `@Guide` encode output structure at the decoding level. Don't repeat the schema in instructions — it wastes tokens (critical with 4096 limit). Use instructions for tone and behavioral constraints only.

---

## Decision Trees

### Foundation Models vs Server API

| Question | Choice |
|----------|--------|
| Privacy required / offline needed / avoid per-request cost? | FM |
| Summarization, extraction, or classification? | FM |
| World knowledge, complex reasoning, math, or translation? | Server API |
| Need >4096 token context? | Server API |

Both can coexist in one app.

### Other Decisions

- **@Generable vs plain text:** Use @Generable when you need structured data or type safety. Plain text when just displaying to user.
- **Tools vs prompt context:** Tools for dynamic/real-time data, device data (contacts, calendar), external APIs. Prompt context for static, short data.
- **New session vs reuse:** Reuse for same topic. New session when context fills, topic changes, or you need different instructions/tools.

---

## Pressure Scenarios

### "Use ChatGPT API Instead"

FM: private, offline, no latency, no per-request cost, no API keys. Server API: world knowledge, complex reasoning, larger context, translation. Both can coexist — not either/or.

### "One Big Prompt for Everything"

4096 tokens is TOTAL. Keep instructions concise, use @Generable instead of describing format, chunk large inputs, monitor with `tokenUsage(for:)`, catch `exceededContextWindowSize` for multi-turn.

### "Skip Availability Checks"

Three unavailable states — `.deviceNotEligible` (permanent), `.appleIntelligenceNotEnabled` (user action), `.modelNotReady` (temporary). Not checking = crashes on unsupported devices. Check on `scenePhase` activation to catch state changes.

---

## Diagnostics Quick Reference

| Symptom | Error | Key Fix |
|---------|-------|---------|
| Context too long | `.exceededContextWindowSize` | Fresh/condensed session |
| Content policy error | `.guardrailViolation` | Rephrase prompt, filter input |
| Language not supported | `.unsupportedLanguageOrLocale` | Fall back to server |
| Structured output fails | `.decodingError` | Verify nested `@Generable`, add `@Guide` |
| Too many requests | `.rateLimited` | Backoff, queue requests |
| Tool not called | Inspect `session.transcript` | Strengthen instructions and tool description |
| Slow response | Profile with Instruments | Pre-warm, reduce tokens, stream |
| Wrong output | Check `@Guide` constraints | Add descriptions, constrain range/count |

Full triage procedures and production crisis playbook: [references/diagnostics.md](references/diagnostics.md)

---

## References

- **[API Reference](references/api-reference.md)** — Complete API with WWDC code examples
- **[Diagnostics](references/diagnostics.md)** — Error triage, Instruments workflow, production crisis defense
- **WWDC Sessions**: 286, 259, 301
