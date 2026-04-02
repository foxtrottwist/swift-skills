---
name: swift-structured-logging
description: "Structured logging for Swift/macOS apps using the SBLogger pattern. Use when adding a new log category to a Swift service, writing log messages in Swift code, setting up logging infrastructure in a new Swift project, or reviewing log message format consistency. Triggers on: 'add logging', 'new log category', 'set up logging', 'log messages', 'SBLogger', 'Logger category'. Swift-specific — covers Sendable isolation, nonisolated let, MainActor, os.Logger, and stderr debug output."
---

# Swift Structured Logging

Enforce consistent logging across Swift/macOS apps using the SBLogger pattern: actor-based stderr sink in DEBUG, os.Logger in release, domain-labeled categories, and a strict message format.

## Adding a New Category

Two files, one line each:

1. **Logger extension** (e.g., `Logger+AppName.swift`):
   ```swift
   static nonisolated let calendar = SBLogger(subsystem: subsystem, category: "Calendar")
   ```

2. **SBLogger domain labels** (e.g., `AppLogger.swift`):
   ```swift
   "Calendar": "📅 AppName.Calendar",
   ```

Then at file scope in the service — never inside the class:
```swift
private nonisolated let log = Logger.calendar
```

Bare `private let` picks up MainActor isolation from project settings and breaks in actors/nonisolated contexts. Always use `private nonisolated let`.

## Message Format

Every log message follows: `"methodName: description"` with optional `" — detail"` suffix.

The method prefix is non-negotiable — without it, log output from multiple services is indistinguishable. The dash separator before error details enables grep filtering.

```swift
// Success
log.info("createEvent: \"\(title)\"")

// Failure — method prefix, then dash, then error
log.error("createEvent: failed — \(error)")

// State
log.info("syncStatus: events=\(eventStatus), reminders=\(reminderStatus)")

// Decision
log.info("perform: requesting access for events")

// Rejection
log.info("speakOnly: rejected — phase is \(phase)")

// Warning
log.warning("perform: access denied for reminders")
```

### Levels

- **debug** — verbose tracing, parameter dumps. Normally off.
- **info** — operations worth recording. Method entry for key paths, completions.
- **warning** — recoverable issues. Denied permissions, fallback paths.
- **error** — failed operations. Thrown errors, exhausted retries.

### What NOT to write

```swift
// Missing method prefix — useless in mixed log output
log.info("Created event: \(title)")

// Generic — which method? Which service?
log.error("Failed to create event")

// Verbose — log lines aren't prose
log.info("The event was successfully created and saved to the calendar")
```

## Worked Example

Adding logging to a new `PaymentService`:

```swift
// 1. Logger+App.swift — add category
static nonisolated let payments = SBLogger(subsystem: subsystem, category: "Payments")

// 2. AppLogger.swift — add domain label
"Payments": "💳 MyApp.Payments",

// 3. PaymentService.swift — file scope logger + usage
private nonisolated let log = Logger.payments

@Observable final class PaymentService {
    func processPayment(amount: Decimal, merchantId: String) async throws -> Receipt {
        log.info("processPayment: \(amount) to \(merchantId)")
        do {
            let receipt = try await gateway.charge(amount: amount, merchant: merchantId)
            log.info("processPayment: completed — receipt \(receipt.id)")
            return receipt
        } catch {
            log.error("processPayment: failed — \(error)")
            throw error
        }
    }

    func refund(receiptId: String) async -> RefundResult {
        guard let receipt = store.find(receiptId) else {
            log.warning("refund: receipt not found — \(receiptId)")
            return .notFound
        }
        log.info("refund: processing \(receiptId)")
        // ...
    }
}
```

Output in DEBUG:
```
[14:23:01.445] [INFO] [💳 MyApp.Payments] processPayment: 29.99 to merch_abc123
[14:23:02.112] [INFO] [💳 MyApp.Payments] processPayment: completed — receipt rec_xyz789
```

## Verification

After adding logging to a file, grep to check format consistency:

```bash
grep -n 'log\.\(info\|error\|warning\|debug\)' Services/NewService.swift
```

Every match should show `"methodName:` immediately after the opening quote. Flag any that start with a capital letter without a method prefix, or use generic phrasing like "Failed to" or "Successfully".

## Infrastructure Setup (New Projects Only)

When setting up logging in a new project (not adding to an existing one), read the existing `SBLogger` and `LogSink` implementations in SpokenBite as the reference pattern:
- `SBLogger` — Sendable struct, four levels, `@autoclosure` messages, `#if DEBUG` stderr via LogSink actor, release via os.Logger
- `LogSink` — actor with `DateFormatter`, writes `[timestamp] [LEVEL] [label] message` to stderr
- Domain labels — static dict mapping category strings to emoji-prefixed display names
- Warning/error in release write to both os.Logger AND stderr for visibility
