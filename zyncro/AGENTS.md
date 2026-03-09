# AGENTS.md

## Project

Zyncro is a Flutter mobile app for shared group organization.
Core modules:

- shared calendar
- collaborative notes
- expense tracking
- group chat

The product concept is a single shared-space hub for couples, roommates, families, or small groups.
All business data is scoped by `groupId`.

## Tech stack

- Flutter
- Dart
- Riverpod for state management
- GoRouter for navigation
- Firebase Auth
- Cloud Firestore
- Firebase Cloud Messaging
- Firebase Storage (only when needed)

## Architecture rules

Use a feature-first modular architecture.

Preferred structure:

- `lib/core/` for app-wide infrastructure, theme, utilities, shared services
- `lib/shared/` for cross-feature reusable widgets/models/enums
- `lib/features/<feature_name>/` for business modules

Inside each feature, use:

- `data/`
- `domain/`
- `presentation/`

Inside `presentation/`, prefer:

- `screens/`
- `widgets/`
- `providers/`

Rules:

- Do not put business logic inside widgets.
- Do not access Firebase directly from UI widgets.
- Keep domain entities framework-agnostic.
- Repository contracts belong in `domain/repositories/`.
- Implementations belong in `data/repositories/`.
- Firebase models belong in `data/models/`.
- Mapping logic belongs in `mappers/` when needed.
- Avoid large monolithic files.

## UI and component rules

This project must stay highly modular.

Rules:

- Every reusable button, input, card, tile, and interactive element should be its own component when reuse is likely.
- Every button or tappable component must include visible press feedback.
- Prefer small reusable widgets over duplicated UI blocks.
- Keep screens focused on composition, not implementation details.
- Use consistent spacing, rounded cards, and strong readability.
- Keep the UI modern, clean, warm, and product-oriented.

## Product rules

The app must feel like one unified collaborative ecosystem, not four disconnected tools.

Main navigation:

- Home
- Calendar
- Notes
- Expenses
- Chat

Home should behave like a dashboard for the selected group.

Group context must always be clear in the UI.
Notes, events, expenses, and messages must all belong to a group.

## State management rules

- Use Riverpod providers consistently.
- Prefer one responsibility per provider.
- Streams should be used for real-time Firebase features where appropriate.
- Derived state should stay outside widgets when possible.

## Navigation rules

- Use GoRouter.
- Keep route naming explicit and predictable.
- Do not introduce hidden navigation flows.
- Detail and create/edit screens should be separate routes when it improves clarity.

## Code quality rules

- Keep files focused on one responsibility.
- Use explicit and readable naming.
- Avoid dead code and commented-out code.
- Do not introduce new dependencies unless necessary.
- Do not refactor unrelated files unless required for the task.
- Preserve existing project conventions unless the task explicitly changes them.

## Firebase and data rules

- Scope all business documents with `groupId`.
- Enforce clear separation between auth/user data and group data.
- Prefer predictable Firestore structures.
- Keep security assumptions explicit in code comments when relevant.
- Do not invent backend behavior silently; create the required models, repositories, and services clearly.

## Testing and validation

After code changes:

- run `flutter analyze`
- run `flutter test` when business logic changes
- do not leave analyzer errors unresolved

## Output expectations

When making changes:

1. explain what changed
2. explain why it changed
3. list files added, edited, or removed

When the user asks for code output:

- provide code file by file
- provide each file in full
- clearly indicate modifications, additions, or deletions

## Implementation behavior

Before coding:

- inspect the relevant files first
- follow the closest existing pattern in the repository
- prefer minimal, clean changes over broad rewrites

If architecture is missing:

- create the simplest version that matches the rules in this file

If a rule conflicts with the existing codebase:

- preserve consistency with the existing project
- mention the conflict clearly in the response
