# Foundation Models — API Reference

Complete API reference with all WWDC 2025 code examples.

---

## LanguageModelSession

### Creating a Session

**Basic Creation**:
```swift
import FoundationModels

let session = LanguageModelSession()
```

**With Custom Instructions**:
```swift
let session = LanguageModelSession(instructions: """
    You are a friendly barista in a pixel art coffee shop.
    Respond to the player's question concisely.
    """
)
```

From WWDC 301:1:05

**With Tools**:
```swift
let session = LanguageModelSession(
    tools: [GetWeatherTool()],
    instructions: "Help user with weather forecasts."
)
```

From WWDC 286:15:03

**With Specific Model/Use Case**:
```swift
let session = LanguageModelSession(
    model: SystemLanguageModel(useCase: .contentTagging)
)
```

From WWDC 286:18:39

### Instructions vs Prompts

**Instructions**: From developer. Define model's role, style, constraints. Mostly static. First entry in transcript. Model trained to obey instructions over prompts (security feature).

**Prompts**: From user (or dynamic app state). Specific requests for generation. Dynamic input. Each `respond(to:)` call adds prompt to transcript.

**Security**: NEVER interpolate untrusted user input into instructions. User input goes in prompts only.

### respond(to:) Method

```swift
func respond(userInput: String) async throws -> String {
    let session = LanguageModelSession(instructions: """
        You are a friendly barista in a world full of pixels.
        Respond to the player's question.
        """
    )
    let response = try await session.respond(to: userInput)
    return response.content
}
```

From WWDC 301:1:05. Return Type: `Response<String>` with `.content` property.

### respond(to:generating:) Method

```swift
@Generable
struct SearchSuggestions {
    @Guide(description: "A list of suggested search terms", .count(4))
    var searchTerms: [String]
}

let response = try await session.respond(
    to: "Generate suggested search terms for an app about visiting famous landmarks.",
    generating: SearchSuggestions.self
)
print(response.content) // SearchSuggestions instance
```

From WWDC 286:5:51. Return Type: `Response<SearchSuggestions>` with `.content` property.

### isResponding Property

Gate UI on `session.isResponding` to prevent concurrent requests:

```swift
Button("Go!") {
    Task { haiku = try await session.respond(to: prompt).content }
}
.disabled(session.isResponding)
```

From WWDC 286:18:22

---

## Multi-Turn Interactions

```swift
let session = LanguageModelSession()

let firstHaiku = try await session.respond(to: "Write a haiku about fishing")
// Silent waters gleam, / Casting lines in morning mist— / Hope in every cast.

let secondHaiku = try await session.respond(to: "Do another one about golf")
// Model remembers context from first turn

print(session.transcript) // Shows full history
```

From WWDC 286:17:46

Each `respond()` call adds entry to transcript. Model uses entire transcript for context.

### Transcript Property

```swift
for entry in transcript.entries {
    print("Entry: \(entry.content)")
}
```

Use cases: debugging, displaying conversation history, exporting chat logs, condensing for context management.

---

## @Generable Macro

### Basic Usage

**On Structs**:
```swift
@Generable
struct Person {
    let name: String
    let age: Int
}

let person = try await session.respond(
    to: "Generate a person",
    generating: Person.self
).content
```

From WWDC 301:8:14

**On Enums**:
```swift
@Generable
struct NPC {
    let name: String
    let encounter: Encounter

    @Generable
    enum Encounter {
        case orderCoffee(String)
        case wantToTalkToManager(complaint: String)
    }
}
```

From WWDC 301:10:49

### Supported Types

**Primitives**: `String`, `Int`, `Float`, `Double`, `Decimal`, `Bool`

**Collections**: `[ElementType]` (arrays)

**Composed Types** (including recursive):
```swift
@Generable
struct Itinerary {
    var destination: String
    var days: Int
    var budget: Float
    var rating: Double
    var requiresVisa: Bool
    var activities: [String]
    var emergencyContact: Person
    var relatedItineraries: [Itinerary] // Recursive
}
```

From WWDC 286:6:18

### @Guide Constraints

`@Guide` constrains generated properties. Supports `description:` (natural language), `.range()` (numeric bounds), `.count()` / `.maximumCount()` (array length), and `Regex` (pattern matching).

```swift
@Generable
struct NPC {
    @Guide(description: "A full name")
    let name: String

    @Guide(.range(1...10))
    let level: Int

    @Guide(.count(3))
    let attributes: [String]
}
```

From WWDC 301:11:20

### Constrained Decoding

How it works:
1. `@Generable` macro generates schema at compile-time
2. Schema defines valid token sequences
3. During generation, framework **masks out invalid tokens** based on schema
4. Model can only pick tokens valid according to schema
5. Guarantees structural correctness — no hallucinated keys, no invalid JSON

Benefits: zero parsing code, no runtime parsing errors, type-safe Swift objects, compile-time safety.

### Property Declaration Order

Properties generated in declaration order. Later properties can reference earlier ones. Declare important properties first for better streaming UX.

```swift
@Generable
struct Itinerary {
    var name: String        // Generated FIRST — shows immediately in streaming
    var days: [DayPlan]     // Generated SECOND
    var summary: String     // Generated LAST — can reference name and days
}
```

From WWDC 286:11:00

### One-Shot Prompting

Define a gold-standard example as a static property, include in prompt to teach tone/style:

```swift
extension Itinerary {
    static let exampleTripToJapan = Itinerary(
        destination: "Tokyo, Japan",
        days: 5,
        activities: ["Visit Senso-ji Temple", "Explore Akihabara", "Day trip to Mt. Fuji"],
        budget: 3000
    )
}

let prompt = Prompt {
    "Generate a travel itinerary for \(userDestination)"
    "Here is an example of the quality and format expected:"
    Itinerary.exampleTripToJapan
}

// When example demonstrates structure, skip schema insertion to save tokens
let response = try await session.respond(
    to: prompt,
    generating: Itinerary.self,
    options: GenerationOptions(includeSchemaInPrompt: false)
)
```

Constrained decoding still enforces structural correctness regardless of `includeSchemaInPrompt`.

---

## Streaming

Foundation Models uses **snapshot streaming** (not delta streaming). The `@Generable` macro creates a `PartiallyGenerated` nested type with all properties optional.

### streamResponse Method

```swift
let stream = session.streamResponse(
    to: "Plan a 3-day itinerary to Mt. Fuji.",
    generating: Itinerary.self
)

for try await partial in stream {
    print(partial) // Incrementally updated Itinerary.PartiallyGenerated
}
```

Return Type: `AsyncSequence<Itinerary.PartiallyGenerated>`

From WWDC 286:9:40

### SwiftUI Integration

```swift
struct ItineraryView: View {
    let session: LanguageModelSession
    let dayCount: Int
    let landmarkName: String

    @State private var itinerary: Itinerary.PartiallyGenerated?

    var body: some View {
        VStack {
            if let name = itinerary?.name {
                Text(name).font(.title)
            }
            if let days = itinerary?.days {
                ForEach(days, id: \.self) { day in
                    DayView(day: day)
                }
            }
            Button("Start") {
                Task {
                    let stream = session.streamResponse(
                        to: "Generate a \(dayCount) itinerary to \(landmarkName).",
                        generating: Itinerary.self
                    )
                    for try await partial in stream {
                        self.itinerary = partial
                    }
                }
            }
        }
    }
}
```

From WWDC 286:10:05

### Best Practices

1. **SwiftUI animations** — wrap updates in `withAnimation`
2. **Stable view identity** — use `ForEach(days, id: \.id)` not `ForEach(days.indices, id: \.self)`
3. **Property order** — declare title/name first for immediate streaming display

---

## Tool Protocol

Tools let the model autonomously execute custom code to fetch external data or perform actions.

### Protocol Definition

```swift
protocol Tool {
    var name: String { get }
    var description: String { get }
    associatedtype Arguments: Generable
    func call(arguments: Arguments) async throws -> ToolOutput
}
```

### Example: GetWeatherTool

```swift
struct GetWeatherTool: Tool {
    let name = "getWeather"
    let description = "Retrieve the latest weather information for a city"

    @Generable
    struct Arguments {
        @Guide(description: "The city to fetch the weather for")
        var city: String
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        let places = try await CLGeocoder().geocodeAddressString(arguments.city)
        let weather = try await WeatherService.shared.weather(for: places.first!.location!)
        let temperature = weather.currentWeather.temperature.value
        return ToolOutput("\(arguments.city)'s temperature is \(temperature) degrees.")
    }
}
```

From WWDC 286:13:42

### Attaching Tools to Session

```swift
let session = LanguageModelSession(
    tools: [GetWeatherTool()],
    instructions: "Help the user with weather forecasts."
)
let response = try await session.respond(to: "What is the temperature in Cupertino?")
// It's 71F in Cupertino!
```

From WWDC 286:15:03

**Flow**: Session initialized with tools -> user prompt -> model decides tool needed -> generates tool call -> framework calls `call()` -> tool output in transcript -> model generates final response.

Model autonomously decides when and how often to call tools. Can call multiple tools per request, even in parallel.

### Stateful Tools

Use `class` when a tool tracks state across calls. `struct` copies lose mutations between calls.

```swift
class FindContactTool: Tool {
    let name = "findContact"
    let description = "Finds a contact from a specified age generation."
    var pickedContacts = Set<String>()

    @Generable
    struct Arguments {
        let generation: Generation
        @Generable enum Generation { case babyBoomers, genX, millennial, genZ }
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        // Fetch, filter out already-picked, return new contact
        pickedContacts.insert(pickedContact.givenName)
        return ToolOutput(pickedContact.givenName)
    }
}
```

From WWDC 301:18:47, 301:21:55

### Transcript Inspection

After a tool-augmented response, inspect the transcript:

```swift
for entry in session.transcript {
    switch entry {
    case .instruction(let text): print("Instructions: \(text)")
    case .prompt(let prompt): print("Prompt: \(prompt.segments.first?.description ?? "")")
    case .toolCall(let call): print("Tool call: \(call.toolName)(\(call.arguments))")
    case .toolOutput(let output): print("Tool output: \(output.content)")
    case .response(let response): print("Response: \(response.segments.first?.description ?? "")")
    @unknown default: break
    }
}
```

### Tool Naming

DO: Short readable names (`getWeather`, `findContact`), verbs, one-sentence descriptions.
DON'T: Abbreviations, implementation details, long descriptions (they're in the prompt, consuming tokens).

---

## Dynamic Schemas

`DynamicGenerationSchema` creates schemas at runtime. Use when structure is only known at runtime (user-defined schemas, level creators, dynamic forms).

```swift
let questionProp = DynamicGenerationSchema.Property(
    name: "question", schema: DynamicGenerationSchema(type: String.self)
)
let answersProp = DynamicGenerationSchema.Property(
    name: "answers", schema: DynamicGenerationSchema(
        arrayOf: DynamicGenerationSchema(referenceTo: "Answer")
    )
)

let riddleSchema = DynamicGenerationSchema(name: "Riddle", properties: [questionProp, answersProp])
let answerSchema = DynamicGenerationSchema(name: "Answer", properties: [/* text, isCorrect */])

let schema = try GenerationSchema(root: riddleSchema, dependencies: [answerSchema])
let response = try await session.respond(to: "Generate a riddle", schema: schema)
let question = try response.content.value(String.self, forProperty: "question")
```

From WWDC 301:14:50

Use `@Generable` when structure is known at compile-time (type safety, automatic parsing). Use Dynamic Schemas when structure is only known at runtime. Both use same constrained decoding guarantees.

---

## Sampling & Generation Options

**Greedy (deterministic)** — use for tests and demos:
```swift
let response = try await session.respond(
    to: prompt,
    options: GenerationOptions(sampling: .greedy)
)
```

**Temperature** — `0.1-0.5` focused, `1.0` default, `1.5-2.0` creative:
```swift
let response = try await session.respond(
    to: prompt,
    options: GenerationOptions(temperature: 0.5)
)
```

From WWDC 301:6:14

---

## Built-in Use Cases

### Content Tagging Adapter

```swift
@Generable
struct Result {
    let topics: [String]
}

let session = LanguageModelSession(
    model: SystemLanguageModel(useCase: .contentTagging)
)
let response = try await session.respond(to: articleText, generating: Result.self)
```

From WWDC 286:19:19

### Custom Use Cases

```swift
@Generable
struct Top3ActionEmotionResult {
    @Guide(.maximumCount(3)) let actions: [String]
    @Guide(.maximumCount(3)) let emotions: [String]
}

let session = LanguageModelSession(
    model: SystemLanguageModel(useCase: .contentTagging),
    instructions: "Tag the 3 most important actions and emotions in the given input text."
)
let response = try await session.respond(to: text, generating: Top3ActionEmotionResult.self)
```

From WWDC 286:19:35

---

## Error Handling

### GenerationError Types

- **`.exceededContextWindowSize`** — Context limit (4096 tokens) exceeded
- **`.guardrailViolation`** — Content policy triggered
- **`.unsupportedLanguageOrLocale`** — Language not supported
- **`.decodingError`** — Model output doesn't match `@Generable` schema
- **`.rateLimited`** — Too many concurrent requests

### Context Window Management

**Strategy 1: Fresh Session**
```swift
do {
    let response = try await session.respond(to: prompt)
} catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    session = LanguageModelSession()
}
```

From WWDC 301:3:37

**Strategy 2: Condensed Session**
```swift
private func newSession(previousSession: LanguageModelSession) -> LanguageModelSession {
    let allEntries = previousSession.transcript.entries
    var condensedEntries = [Transcript.Entry]()

    if let firstEntry = allEntries.first {
        condensedEntries.append(firstEntry) // Instructions
        if allEntries.count > 1, let lastEntry = allEntries.last {
            condensedEntries.append(lastEntry) // Recent context
        }
    }

    let condensedTranscript = Transcript(entries: condensedEntries)
    return LanguageModelSession(transcript: condensedTranscript)
}
```

From WWDC 301:3:55

### Token Usage Tracking

`SystemLanguageModel` provides APIs to measure token consumption before and during generation. Use these to monitor context budget and prevent `exceededContextWindowSize` errors.

**Context size:**
```swift
let model = SystemLanguageModel.default
let contextSize = try await model.contextSize // 4096
```

**Measure instructions:**
```swift
let instructions = Instructions("You're a helpful assistant that generates haiku.")
let usage = try await model.tokenUsage(for: instructions)
print(usage.tokenCount) // 16
```

**Measure instructions + tools combined:**
```swift
let usage = try await model.tokenUsage(for: instructions, tools: [MoodTool()])
print(usage.tokenCount) // 79
```

**Measure prompts:**
```swift
let prompt = Prompt("Generate a haiku about Swift")
let usage = try await model.tokenUsage(for: prompt)
```

**Measure transcript (total conversation):**
```swift
let usage = try await model.tokenUsage(for: session.transcript)
print(usage.tokenCount)
```

**Context usage percentage helper:**
```swift
extension SystemLanguageModel.TokenUsage {
    func percent(ofContextSize contextSize: Int) -> Float {
        guard contextSize > 0 else { return 0 }
        return Float(tokenCount) / Float(contextSize)
    }
}
```

Source: [artemnovichkov.com/blog/tracking-token-usage-in-foundation-models](https://artemnovichkov.com/blog/tracking-token-usage-in-foundation-models)

### Fallback Architecture

Wrap Foundation Models behind a protocol for graceful degradation:

```swift
protocol TextSummarizer {
    func summarize(_ text: String) async throws -> String
}
struct OnDeviceSummarizer: TextSummarizer { /* Foundation Models */ }
struct ServerSummarizer: TextSummarizer { /* Server API fallback */ }
struct TruncationSummarizer: TextSummarizer { /* Simple truncation */ }
```

---

## Availability

```swift
switch SystemLanguageModel.default.availability {
case .available:
    Text("Model is available").foregroundStyle(.green)
case .unavailable(let reason):
    Text("Reason: \(reason)").foregroundStyle(.red)
}
```

From WWDC 286:19:56

### Supported Languages

```swift
let supportedLanguages = SystemLanguageModel.default.supportedLanguages
guard supportedLanguages.contains(Locale.current.language) else { return }
```

From WWDC 301:7:06

### Device Requirements

- iPhone 15 Pro or later
- iPad with M1+ chip
- Mac with Apple silicon
- Supported region, user opted into Apple Intelligence

---

## Performance & Profiling

### Instruments for Foundation Models

Product -> Profile (Cmd+I) -> add "Foundation Models" instrument. Three key tracks:

1. **Asset Loading** — model load time. Target with pre-warming.
2. **Inference** — token counts (input/output), generation duration. Optimize with shorter names, `includeSchemaInPrompt: false`.
3. **Response timeline** — first-token latency vs total time.

### Prewarming

```swift
class ViewModel: ObservableObject {
    private var session: LanguageModelSession?

    init() {
        Task { self.session = LanguageModelSession(instructions: "...") }
    }
}
```

Saves 1-2 seconds off first generation. From WWDC 259.

### includeSchemaInPrompt

Skip schema insertion for subsequent requests in same session:

```swift
let second = try await session.respond(
    to: "Generate another person",
    generating: Person.self,
    options: GenerationOptions(includeSchemaInPrompt: false)
)
```

Saves 10-20% per request. From WWDC 259.

---

## Xcode Playgrounds

```swift
import FoundationModels
import Playgrounds

#Playground {
    let session = LanguageModelSession()
    let response = try await session.respond(
        to: "What's a good name for a trip to Japan? Respond only with a title"
    )
}
```

Create inside existing project to access app-defined `@Generable` types. Prompt changes execute without rebuilding. From WWDC 286:2:28.

---

## Feedback & Analytics

`LanguageModelFeedbackAttachment` reports model quality issues to Apple via Feedback Assistant. Create with `input`, `output`, `sentiment` (`.positive`/`.negative`), `issues` (category + explanation), and `desiredOutputExamples`. From WWDC 286:22:13.

---

## API Quick Reference

- **`LanguageModelSession`** — `respond(to:)` -> `Response<String>`, `respond(to:generating:)` -> `Response<T>`, `streamResponse(to:generating:)` -> `AsyncSequence<T.PartiallyGenerated>`. Properties: `transcript`, `isResponding`.
- **`SystemLanguageModel`** — `default.availability`, `default.supportedLanguages`, `init(useCase:)`
- **`GenerationOptions`** — `sampling` (`.greedy`/`.random`), `temperature`, `includeSchemaInPrompt`
- **`@Generable`** — Structured output with constrained decoding
- **`@Guide`** — Property constraints: `description:`, `.range()`, `.count()`, `.maximumCount()`, `Regex`
- **`Tool` protocol** — `name`, `description`, `Arguments: Generable`, `call(arguments:) -> ToolOutput`
- **`DynamicGenerationSchema`** — Runtime schemas with `GeneratedContent` output
- **`GenerationError`** — `.exceededContextWindowSize`, `.guardrailViolation`, `.unsupportedLanguageOrLocale`, `.decodingError`, `.rateLimited`
