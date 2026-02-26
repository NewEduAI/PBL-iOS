# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: Developer Context and Interaction Style

**The developer is a full-stack engineer fluent in backend development but NEW to Swift and iOS development.**

**TEACHING MODE - DO NOT IMPLEMENT:**
- **NEVER write code directly unless explicitly asked**
- **ALWAYS guide and explain how to implement features**
- Focus on teaching Swift/iOS concepts, patterns, and best practices
- Explain WHY certain approaches are used in iOS development
- Provide code examples as learning references, but let the developer implement
- Point to relevant Apple documentation and SwiftUI patterns
- Answer questions about Swift syntax, iOS frameworks, and architecture
- Review code and suggest improvements with explanations

**Project Goal:**
Building an iOS app for a service that uses LLM agents to simulate teammates for completing projects with users. The app handles real-time collaboration, agent interactions, and project management workflows.

**Git Commit Guidelines:**
- Since the developer writes all code, **DO NOT add "Co-Authored-By: Claude" to commit messages**
- Keep commit messages **simple and short** - one sentence explaining what the modifications are intended to do

## Project Overview

Multi-platform SwiftUI app (iOS + macOS), targeting iOS 26.2+. Xcode 26.2, Swift 5.0.

**Bundle Identifier:** MAIC.PBL
**Development Team:** KT3RLF5V3W

## Build Commands

```bash
# Build iOS target for simulator
xcodebuild -project PBL.xcodeproj -scheme PBL -sdk iphonesimulator -configuration Debug build

# List simulators (to get SIMULATOR_ID)
xcrun simctl list devices

# Build and run on specific simulator
xcodebuild -project PBL.xcodeproj -scheme PBL -sdk iphonesimulator -configuration Debug -destination 'id=SIMULATOR_ID' build

# Clean
xcodebuild -project PBL.xcodeproj -scheme PBL clean

# Open in Xcode
open PBL.xcodeproj
```

## Architecture

### Dual-Target Platform Structure

The project has **two separate Xcode targets** — one for iOS, one for macOS. Each target compiles its own `@main` entry point and platform-specific views, while sharing all `Core/` code and most `Features/` logic.

| File | Target |
|------|--------|
| `PBLApp.swift` | iOS only — `@main struct PBLApp` |
| `PBLAppZone.swift` | macOS only — `@main struct PBLAppZone` |
| `MainTabView/iOS.swift` | iOS only — `MainTabViewiOS` |
| `MainTabView/MacOS.swift` | macOS only — `MainTabViewMacOS` |
| `Features/Auth/View/LoginViewiOS.swift` | iOS only |
| `Features/Auth/View/LoginViewMacOS.swift` | macOS only |
| `Core/**`, `Features/**/` (non-view files) | Both targets |

**Naming convention:** platform-specific types are suffixed `*iOS` / `*MacOS`.

> Both `@main` structs cannot coexist in the same target — Xcode's target membership controls which file compiles into which binary.

### App Entry & Navigation Flow

Each entry point creates a single `AppState` instance and conditionally renders:
- Login view — when `appState.token` is `""`
- Main tab view — when authenticated

Both `MainTabViewiOS` and `MainTabViewMacOS` currently provide the same 3-tab structure: **Notifications**, **Projects** (ProjectPanelView), **Profile**.

### State Management

`Core/AppState.swift` uses Swift's `@Observable` macro (iOS 17+ equivalent to `ObservableObject`+`@Published`). It holds global user state: `userId`, `token`, `username`, `isTeacher`, `organization`, `organizationBaseUrl`. Views access it via `@Environment(AppState.self)`.

### API Layer (`Core/Services/API/`)

Layered, inheritance-based API architecture:

- **`Module/Base.swift`** — `BaseAPI` class handles URL construction, JSON encoding/decoding, auth headers, and error handling. All responses are wrapped in `APIResponse<T>` with `isSuccess`/`message`/`data`. Throws `APIError` on failure.
- **`Module/User.swift`** — `UserAPI : BaseAPI` with `/user` prefix. Methods: `login()`, `getUserInfo()`.
- **`Module/Project.swift`** — `StudentProjectAPI : BaseAPI` with `/group` prefix. Method: `getStudentAssignments()`.
- **`Main.swift`** — `API` facade class bundling modules (currently only `user`).

### Multi-Tenancy

`Core/Constant/Institution.swift` maps email domains to institutions (e.g., `tsinghua.edu.cn` → Tsinghua's backend URL). `AuthService` extracts the institution from the user's email domain at login to route API calls to the correct backend. This means **base URLs are dynamic per user**, not hardcoded.

### Feature Organization (`Features/`)

Features are organized by domain:
- `Auth/` — `AuthService.swift` (orchestrates login: resolves institution → calls API → saves to AppState), `View/LoginView.swift`
- `ProjectPanel/` — `View/ProjectPanelView.swift` (role-conditional: student list vs. teacher TODO), `Component/ProjectCardStudent.swift`
- `Notification/` — `NotificationView.swift` (placeholder)
- `Profile/` — `UserProfileView.swift` (displays AppState data, logout)

### Implementation Status

- **Functional:** Auth flow, student assignment listing, profile/logout
- **TODO/Stub:** Teacher project views, notification system, project detail views, join/create project dialogs

### Key Swift Patterns in Use

- `@Observable` (not `ObservableObject`) for state — requires `import Observation`
- `async/await` + `.task {}` view modifier for network calls
- `@Environment(AppState.self)` to access shared state in views
- `Identifiable` on model types using domain-specific IDs (e.g., `projectId`)
- Swift 6 concurrency: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set project-wide
