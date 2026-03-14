---
description: Bootstrap a new project by generating SPEC.md and PLAN.md from a project idea
argument-hint: <project description, e.g. "an iPhone app powered by Radio Browser similar to RadioDroid">
---

You are bootstrapping a new software project. The user has described: **$ARGUMENTS**

Your job is to produce two comprehensive documents — `SPEC.md` and `PLAN.md` — that together fully define the project so that `/implement` can build it feature by feature.

Follow these 9 steps in order. Do not skip steps.

---

## Step 1: Research

Gather all the information you need before writing anything:

1. **Parse the prompt** — identify the target platform, language/framework preferences, data sources, and any reference projects mentioned.
2. **Research APIs** — if the project depends on external APIs or data sources, fetch their documentation. Understand endpoints, authentication, data schemas, rate limits, and quirks. Use `WebFetch` / `WebSearch` to read API docs, READMEs, and relevant pages.
3. **Research reference projects** — if the prompt names an existing app to emulate (e.g., "similar to RadioDroid"), study its feature set, UI structure, and user flows. Fetch the project's README, browse its source structure, and read relevant code to understand what it does.
4. **Identify platform constraints** — note framework capabilities, OS version requirements, background modes, permissions, and any platform-specific considerations (e.g., iOS audio session categories, Android foreground services, web CORS).

Do thorough research. The quality of the generated docs depends entirely on how well you understand the domain, APIs, and reference projects.

---

## Step 2: Ask Product & Functional Questions

Before making decisions, surface ambiguities about **what the app should do** — its features, behavior, and user experience. These questions shape SPEC.md. Do NOT ask about technology choices here — that comes in Step 4.

Present a numbered list of questions to the user. Focus on questions where the answer materially changes the product — skip anything you can safely assume.

Good questions to consider (ask only those relevant to the project):

- **Platform & deployment** — iOS only or also iPad/macOS? App Store or side-load?
- **Scope boundaries** — which features from the reference project should be included vs. excluded? Are there features NOT in the reference project that the user wants?
- **User data** — should favorites, history, or settings persist across app restarts? Local-only or synced across devices? How much data should be kept (e.g., history limit)?
- **Authentication** — does the app need user accounts, or is it anonymous/local-only?
- **Monetization** — free, paid, freemium, ads? This affects what features are gated.
- **Design direction** — any specific design preferences? Dark mode? Match system appearance? Custom theme?
- **Content & data** — what data does the app display? Where does it come from? Is there offline access?
- **License** — what license for the project?
- **Existing constraints** — is there an existing codebase, backend, or design system to integrate with?

**Wait for the user to respond before proceeding.** Incorporate their answers into all subsequent steps. If the user says "use your best judgment" or similar, make reasonable defaults and document your assumptions.

---

## Step 3: Define Scope

Decide what's in and what's out:

1. **Core features (MVP)** — the minimum feature set for a usable v1. Be generous but realistic. Map each feature to its reference-project equivalent (if any) and its implementation approach.
2. **Post-MVP features** — features that are nice-to-have but not essential. Include them in PLAN.md as a roadmap so they can be built later.
3. **Explicit non-goals** — anything the user might expect but that is deliberately excluded (e.g., "no user accounts", "no offline mode in v1").

Present this scope to the user and ask for confirmation before proceeding. If the user has already been specific enough that the scope is clear, proceed.

---

## Step 4: Propose Tech Stack & Architecture

Now that the **what** is defined (Steps 2–3), decide **how** to build it. Present concrete technical options so the user can make informed choices before you write the full plan. This prevents wasted effort writing a detailed PLAN.md around the wrong stack.

### Part A: Tech Stack Options

Present 2–3 tech stack options in a comparison table. For each option, clearly state the trade-offs — what you gain and what you give up.

| Dimension | Option A | Option B | Option C (if applicable) |
|---|---|---|---|
| **Language** | e.g. Swift | e.g. Kotlin Multiplatform | e.g. Flutter/Dart |
| **UI framework** | e.g. SwiftUI | e.g. Jetpack Compose | e.g. Flutter widgets |
| **Architecture** | e.g. MVVM | e.g. MVI | e.g. BLoC |
| **Persistence** | e.g. SwiftData | e.g. Room | e.g. Hive |
| **Networking** | e.g. URLSession | e.g. Ktor | e.g. Dio |
| **Concurrency** | e.g. Swift concurrency (actor) | e.g. Kotlin coroutines | e.g. Dart isolates |
| **Dependencies** | e.g. zero third-party | e.g. Ktor, SQLDelight | e.g. flutter_bloc, dio |
| **Min OS** | e.g. iOS 16+ | e.g. Android 8+ | e.g. iOS 14+ / Android 8+ |
| **Trade-offs** | Native perf, Apple-only | Shared logic, two UI layers | Single codebase, non-native feel |

Add a **Recommendation** with a brief rationale for which option best fits the project's goals (based on the user's answers from Step 2).

### Part B: Architectural Decisions

Surface specific architectural decisions where there are genuine trade-offs. For each, present the options with their trade-offs so the user understands what they're choosing. Only raise decisions relevant to this project — skip anything with an obvious best choice.

For each decision, use this format:

> **Decision:** [what needs to be decided]
>
> - **Option X:** [description] — *Trade-off: [what you gain vs. what you give up]*
> - **Option Y:** [description] — *Trade-off: [what you gain vs. what you give up]*
> - **Recommendation:** [which option and why]

Decisions to consider:

- **Navigation pattern** — e.g. tabs (*simple, familiar, limited to ~5 destinations*) vs. sidebar (*scales to many sections, less mobile-friendly*) vs. drawer (*saves space, hidden discoverability*)
- **State management** — e.g. observable objects (*simple, direct, can lead to scattered state*) vs. unidirectional data flow (*predictable, more boilerplate*) vs. Redux-style store (*single source of truth, heavy for small apps*)
- **Persistence strategy** — e.g. local database (*structured queries, schema migrations*) vs. flat files/UserDefaults (*simple, no migrations, limited querying*) vs. cloud sync (*cross-device, adds complexity and latency*)
- **Offline support** — e.g. offline-first with sync (*resilient, complex sync logic*) vs. online-required with graceful degradation (*simpler, unusable without network*)
- **Image loading** — e.g. built-in async loading (*no dependencies, more code to write*) vs. third-party library (*battle-tested, adds dependency*)
- **Dependency philosophy** — e.g. zero third-party (*full control, more code*) vs. selective dependencies (*faster development, maintenance burden*)
- **Testing strategy** — e.g. protocol-based mocks (*flexible, verbose setup*) vs. concrete test doubles (*less ceremony, tighter coupling*) vs. snapshot tests (*catches visual regressions, brittle to UI changes*)

**Wait for the user to choose before proceeding.** Their choices lock in the technical foundation for PLAN.md. The user may pick a full stack option, mix and match, or override individual decisions.

---

## Step 5: Write SPEC.md

`SPEC.md` is the **behavioral specification** — the single source of truth for what the app does from the user's perspective. It does NOT contain implementation details, code samples, or architecture decisions.

Write `SPEC.md` with these sections (adapt headings to fit the project):

### Structure

1. **Title & one-paragraph summary** — what the app is, what it does, platform, license.
2. **Data source** — where data comes from (API, local, user-generated). Include:
   - Server discovery / base URL strategy (if applicable)
   - Authentication requirements
   - Error handling table: condition → user message → recovery hint
3. **Data model** — every entity the app works with. For each:
   - Identity field
   - All fields with types
   - Derived behavior (computed properties, formatting rules)
   - Persistence rules (max entries, dedup windows, TTLs)
4. **App structure** — navigation hierarchy (tabs, sidebar, drawer), with a table mapping each top-level destination to its icon and screen.
5. **Screen-by-screen behavior** — one section per screen. For each:
   - What it shows (sections, layouts, data sources, limits)
   - All user interactions (tap, swipe, long-press, drag)
   - All states: loading, loaded, empty, error, searching
   - Pagination rules (page size, "has more" logic, sort order)
   - Pull-to-refresh behavior
6. **Reusable components** — list rows, cards, image views, error views. Describe layout, interactions, and states.
7. **System integrations** — background modes, notifications, lock screen, audio session, permissions, deep links, sharing. Describe the behavior, not the implementation.

### Guidelines

- **Be precise.** Specify sort orders, page sizes, debounce durations, max counts, and format strings. Vague specs produce vague implementations.
- **Cover every state.** For each screen: what does the user see when data is loading? When there are no results? When there's an error? When the list is empty?
- **Describe behavior, not code.** Say "tapping a station plays it" not "call playerVM.play(station)". Say "search is debounced by 400ms" not "use Task.sleep(nanoseconds: 400_000_000)".
- **Use tables** for structured information (error mappings, state tables, feature lists).
- **No code samples.** SPEC.md is readable by non-engineers.

---

## Step 6: Write PLAN.md

`PLAN.md` is the **architectural blueprint** — the single source of truth for how the app is built. It contains everything an engineer (or `/implement`) needs to write correct code without making architectural decisions.

Write `PLAN.md` with these sections:

### Structure

1. **Project overview** — one paragraph restating what the app is, plus a metadata block:
   - Platform & minimum OS version
   - Language & version
   - UI framework
   - Architecture pattern
   - Key frameworks used
   - Persistence strategy
   - Dependencies (ideally: none)
   - License
2. **Feature set** — two tables (MVP and Post-MVP), each with columns: Feature | Reference Equivalent (if any) | Implementation approach. This maps SPEC.md features to concrete technical approaches.
3. **API reference** (if applicable) — complete documentation of every API endpoint the app will use:
   - Server discovery mechanism
   - Authentication
   - Request/response schemas with field types
   - Pagination parameters
   - Rate limits and quirks
   - Example response JSON (abbreviated)
4. **Architecture diagram** — ASCII box diagram showing layers (Views → ViewModels → Services → Models → Frameworks). List every component in each layer.
5. **Key architectural decisions** — table of Decision | Rationale. Document every non-obvious choice (why this persistence strategy, why this concurrency model, why this error handling approach).
6. **Project structure** — complete file tree showing every file to be created, with one-line descriptions. Group by directory.
7. **Detailed component specifications** — for every file in the project structure:
   - **Models:** full struct/class definition with all properties, types, coding keys, computed properties, and initializers. Include Swift code blocks.
   - **Services:** full API surface (public methods with signatures), internal state, concurrency model (actor vs @MainActor), and behavioral notes.
   - **ViewModels:** full class definition with all @Published properties, public methods, internal state, and business logic descriptions.
   - **Views:** layout description (ASCII wireframe for complex views), data flow, interactions, and navigation.
8. **Implementation phases** — break the work into ordered phases, each with:
   - **Goal:** one sentence describing what works at the end of this phase
   - **Numbered steps:** specific files to create/modify, in dependency order
   - **Verify:** what to test to confirm the phase is complete
   - Leave room for **Implementation notes** to be added by `/implement` after each phase is built.
9. **Platform-specific technical considerations** — deep-dive on framework usage, session management, background behavior, memory management, concurrency model, and any platform quirks.
10. **Post-MVP roadmap** — ordered list of future features with brief implementation notes.

### Guidelines

- **Include code.** PLAN.md should contain actual Swift/Kotlin/TypeScript/etc. struct definitions, method signatures, and enum cases. The implementer should be able to copy these directly.
- **Be exhaustive on APIs.** Document every endpoint, every field, every parameter. The implementer should never need to visit external API docs.
- **Specify concurrency model per component.** Which are actors? Which are @MainActor? Why?
- **Order phases by dependency.** Phase 1 must be buildable and testable on its own. Each subsequent phase adds to what exists.
- **Anticipate gotchas.** If a framework has quirks (e.g., AVPlayer must be on main thread, SwiftData @Query only works in views), document them in the relevant component spec.

---

## Step 7: Review & Cross-check

Before presenting the documents:

1. **Cross-check SPEC.md against PLAN.md** — every feature in SPEC.md must have a corresponding component in PLAN.md. Every component in PLAN.md must trace back to a SPEC.md requirement.
2. **Cross-check against API docs** — verify that endpoint URLs, field names, and response schemas in PLAN.md match the actual API documentation you researched.
3. **Check for gaps** — are there screens described in SPEC.md with no view in PLAN.md? Are there services in PLAN.md with no behavioral spec? Are there error states in SPEC.md with no error enum case in PLAN.md?
4. **Check for contradictions** — does SPEC.md say "max 50 entries" but PLAN.md say "max 25"? Does SPEC.md describe 5 tabs but PLAN.md only list 4 views?

Fix any issues found.

---

## Step 8: Write the Files

Write both files to the project root:

1. Write `SPEC.md`
2. Write `PLAN.md`

---

## Step 9: Summary

Present a brief summary to the user:

1. What the project is
2. Key architectural decisions made
3. Number of MVP features vs post-MVP features
4. Number of implementation phases
5. Any assumptions made or questions that remain
6. Suggest running `/implement <phase-1-description>` to start building
