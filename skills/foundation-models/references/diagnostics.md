# Foundation Models — Diagnostics

Diagnostic workflows for Foundation Models issues. Every entry maps symptoms to specific `GenerationError` cases with concrete resolution steps.

---

## Context Exceeded (`GenerationError.exceededContextWindowSize`)

**Triage with Instruments:** Product -> Profile (Cmd+I), add Foundation Models instrument. Check Inference track -> "Max token count". Identify which component consumes the most tokens: instructions, schema, transcript history, or current prompt.

**Resolution strategies:**

1. **Fresh session** — `session = LanguageModelSession(instructions: originalInstructions)`
2. **Condensed session** — summarize conversation, start fresh with summary as context:
```swift
let summary = try await session.respond(to: "Summarize our conversation in 2 sentences")
session = LanguageModelSession(instructions: originalInstructions)
let response = try await session.respond(to: "Context: \(summary.content)\n\n\(newPrompt)")
```
3. **Chunk large inputs** — split text into segments, process each in fresh session, aggregate results

**Prevention:** Monitor transcript length with `tokenUsage(for: session.transcript)`. Warn the user or auto-condense before hitting the limit.

---

## Guardrail Violation (`GenerationError.guardrailViolation`)

**Debug — access error details:**
```swift
do {
    let response = try await session.respond(to: prompt)
} catch let error as LanguageModelSession.GenerationError {
    if case .guardrailViolation = error {
        print(error.debugDescription)
        print(error.failureReason ?? "")
        print(error.recoverySuggestion ?? "")
    }
}
```

- Don't retry the same prompt — it will fail again
- Rephrase the prompt or pre-filter known problematic patterns
- Present a user-friendly message, don't expose raw error details
- Test with adversarial inputs during development

---

## Tool Not Called

**Checklist:**
1. Tool name and description clear? Vague descriptions = tool gets ignored.
2. Instructions direct the model? Add explicit guidance: "Always use the getWeather tool when the user asks about weather."
3. Prompt matches tool purpose?
4. Tool registered on session via `LanguageModelSession(instructions:tools:)`?

**Debug:** Inspect `session.transcript` — if no `.toolCall` entry, the model chose not to invoke. Fix: strengthen instructions, make tool description more specific, use `GenerationOptions(sampling: .greedy)` for deterministic debugging, reduce to only relevant tools per session.

---

## Slow Generation

**Triage with Instruments:**
1. **Asset Loading track** — model loading slow? Add pre-warming: `try await session.prewarm()`
2. **Inference track** — high token count? Shorter field names, `includeSchemaInPrompt: false`, constrain output length
3. **Response timeline** — first-token latency vs total time

**Stream for perceived performance:**
```swift
let stream = session.streamResponse(to: prompt)
for try await partial in stream {
    self.text = partial.content
}
```

Streaming doesn't reduce total time, but user sees tokens immediately.

---

## Wrong Output Format

**Checklist:**
1. All nested types marked `@Generable`?
2. Property declaration order matches desired generation order? (model generates in declaration order)
3. `@Guide` descriptions clear and specific?
4. Enum cases cover all expected values?

**Fixes:** Add one-shot example in prompt, use `@Guide(description:)` on every property, constrain with `.range()`, `.count()`, `.anyOf()`, verify with `GenerationOptions(sampling: .greedy)`.

---

## Decoding Error (`GenerationError.decodingError`)

Rare with well-defined types, more common with complex nested structures. Simplify the `@Generable` type (flatten nesting), add `@Guide(description:)` to all properties, ensure all nested types are `@Generable`, check enum case exhaustiveness.

---

## Unsupported Language (`GenerationError.unsupportedLanguageOrLocale`)

FM is optimized for English. Translation is NOT a supported use case. Check before generation: `session.supportsLanguage(of: inputText)`. Fall back to server API for unsupported languages.

---

## Rate Limited (`GenerationError.rateLimited`)

Too many concurrent requests. Implement backoff and retry. Queue requests instead of firing concurrently.

---

## Availability Issues

Three states from `SystemLanguageModel.default.availability`:

| State | Permanent? | User Action |
|-------|------------|-------------|
| `.unavailable(.deviceNotEligible)` | Yes | None — device can't support it |
| `.unavailable(.appleIntelligenceNotEnabled)` | No | Enable in Settings > Apple Intelligence & Siri |
| `.unavailable(.modelNotReady)` | No | Wait — try again later |

**Testing:** Edit Scheme -> Run -> Options -> "Simulated Foundation Models Availability" to cycle through all states.

**Check on scene activation:**
```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            showAIFeatures = true
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: showDeviceIneligibleMessage()
            case .appleIntelligenceNotEnabled: showEnableAIMessage()
            case .modelNotReady: showModelDownloadingMessage()
            @unknown default: showGenericUnavailableMessage()
            }
        }
    }
}
```

---

## Production Crisis Scenario

**Scenario: AI feature launches, significant error rate in telemetry.**

### Immediate Triage (first 15 minutes)

1. **Error type distribution** — which `GenerationError` cases dominate?
   - `.exceededContextWindowSize` -> context management missing
   - `.guardrailViolation` -> specific content triggering filters
   - `.deviceNotEligible` -> availability check missing
   - `.decodingError` -> `@Generable` schema issue
   - Mixed -> prioritize by volume

2. **Correlate with device class** — errors on specific hardware = availability check not implemented

3. **Check input patterns** — long inputs (context), specific topics (guardrail), non-English (language)

4. **Check session lifetime** — `exceededContextWindowSize` increasing over time = multi-turn without context management

### Instruments-Based Triage

1. Reproduce on affected device class
2. Profile with Foundation Models template
3. Check Asset Loading — loading fresh each time? Add `prewarm()`
4. Check Inference token counts — prompts larger than expected? Instructions bloated?
5. Check for concurrent session issues

### Quick Mitigations

```swift
// 1. ContentUnavailableView fallback
if !isModelAvailable {
    ContentUnavailableView("AI Features Unavailable",
        systemImage: "brain",
        description: Text(unavailabilityMessage))
}

// 2. Comprehensive error handling for every generation call
do {
    let response = try await session.respond(to: prompt)
    handleSuccess(response)
} catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    resetSessionAndRetry()
} catch LanguageModelSession.GenerationError.guardrailViolation {
    showContentFilterMessage()
} catch LanguageModelSession.GenerationError.unsupportedLanguageOrLocale {
    showLanguageUnsupportedMessage()
} catch LanguageModelSession.GenerationError.decodingError {
    showGenerationFailedMessage()
} catch LanguageModelSession.GenerationError.rateLimited {
    retryWithBackoff()
} catch {
    showGenericErrorMessage(error)
}

// 3. Input length validation
guard prompt.count < 3000 else {
    showInputTooLongMessage()
    return
}
```

- Consider feature flag to disable AI features for specific device classes
- Add telemetry for each error type to track fix effectiveness
