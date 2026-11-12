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

Full reference: `../docs/ARCHITECTURE.md`. Rules below are enforced by
`test/architecture/import_rules_test.dart`.

Structure:

- `lib/app/` — composition root: router, app shell, global listeners. Only place that knows every feature.
- `lib/core/` — cross-cutting infrastructure, never imports `features/` or `app/`:
  `firebase/` (the ONLY place that touches `Firebase*.instance`, Firestore paths), `error/` (`Failure`, `FailureMapper`),
  `logging/` (`AppLogger`), `media/`, `notifications/`, `app_update/`, `utils/`.
- `lib/design_system/` — tokens (`ZyncroColors` theme extension, `AppSpacing`, `AppRadii`) and `context.colors`.
- `lib/shared/` — `domain/` (pure cross-feature domain: recurrence, categories), `data/mappers/`, `presentation/`, `widgets/`.
- `lib/features/<feature>/` — `domain/` (entities, repository interfaces, pure services), `data/` (mappers, repositories, technical services), `presentation/` (`screens/`, `widgets/`, `providers/`).

Rules:

- `domain/` is pure Dart: no Flutter, Firebase or Riverpod imports.
- Entities live in `features/<f>/domain/entities/`. Never add `fromMap`/`toMap` to an entity.
- Serialization lives in `data/mappers/<x>_mapper.dart` (`XMapper.fromFirestore/toFirestore`) with field names in `XFields`. No raw field strings elsewhere.
- Repository interface `XRepository` in `domain/repositories/`; implementation `FirestoreXRepository` in `data/repositories/`, receiving Firebase instances by constructor (from `core/firebase/firebase_providers.dart`).
- Read lists with `mapDocsSafely` (an unreadable document is skipped and logged, never breaks the stream).
- `presentation/` never imports `cloud_firestore` / `firebase_storage`; widgets never call Firebase or plugins directly (use services in `core/`). Media / network plugins (`http`, `gal`, `path_provider`, `image_picker`, `record`, `flutter_image_compress`) are only imported by `core/media` or a feature's `data/services/` (enforced by test).
- Features don't import each other, except the session context (`auth`, `groups`). Compose in `app/` or use ports in `shared/domain`.
- Map technical errors with `FailureMapper.from(e)`; check `Failure` subtypes in UI, never Firebase error codes.
- Avoid large monolithic files (target ≤ 300 lines; screens compose, widgets render).

## Data contract (production app — backward compatibility)

- Never rename a collection, field or stored enum value (message `type`, `expenseType`, `splitType`, member `role`…).
- New fields are optional with a read default. Update existing documents with `update()` or `set(merge: true)`, never a bare `set()`.
- Tab settings are written field by field (`TabSettingsMapper.changedFields`).
- Wire format is pinned by `test/characterization/models_wire_format_test.dart` — it must stay green.
- Any `firestore.rules` / `storage.rules` change starts with tests in `../firebase-tests/` (legit v1.x flows + attacks); deploy from the repository root.

## UI and component rules

This project must stay highly modular.

Rules:

- Every reusable button, input, card, tile, and interactive element should be its own component when reuse is likely.
- Every button or tappable component must include visible press feedback.
- Prefer small reusable widgets over duplicated UI blocks.
- Keep screens focused on composition, not implementation details.
- Use consistent spacing, rounded cards, and strong readability.
- Colors come from the theme: `context.colors.<role>` (`design_system/`). Fixed identity colors (tab colors, balance colors) come from `TabPalette` / `BalancePalette` (`design_system/tokens/brand_palette.dart`). Never add a hard-coded color in a widget.
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

- Riverpod 3, no code generation.
- `Provider` for infrastructure (repositories, services), `StreamProvider` for real-time data, `Notifier`/`AsyncNotifier` for commands and screen state.
- One responsibility per provider; derived state computed in providers/domain services, not in widgets.
- No side effects in `build` (use `ref.listen`, `initState`); use `select` when reading part of a state.

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

Quality gate (also run by CI):

- `dart format --set-exit-if-changed lib test`
- `flutter analyze` → **0 issues**, infos included (strict analysis options)
- `flutter test` (unit, characterization, architecture tests)
- `flutter build apk --debug`
- functions: `cd ../functions && npm run build && npm run lint && npm test`
- rules: `cd ../firebase-tests && npm test`
- critical flows: `integration_test/app_smoke_test.dart` against Firebase emulators (`--dart-define=USE_FIREBASE_EMULATORS=true`)

Known bugs are listed in `../docs/refactor/BUGS_FOUND.md` and pinned by `BUG …` tests: fixing one means flipping its test.

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
