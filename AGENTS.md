# Repository Guidelines

This repository hosts a Flutter application in `dog_walker_app/` (PawPal – Dog Walking). Use the guidance below to keep changes consistent, testable, and easy to review.

## Project Structure & Module Organization
- `dog_walker_app/lib/`: app source.
  - `main.dart`, `main_simple.dart` (entry points)
  - `models/`, `screens/`, `services/`, `widgets/`, `utils/`, `l10n/`
- `dog_walker_app/test/`: Dart/Flutter tests (`*_test.dart`).
- Platforms: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`.
- Config/docs: `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `QUICK_START.md`, `firebase_setup_guide.md`.
- Helpers: `generate_pdf_report.py`, `simple_pdf_generator.py` (PDF tooling).

## Build, Test, and Development Commands
Run from `dog_walker_app/` unless noted.
- Install deps: `flutter pub get`
- Run app: `flutter run -d ios|android|chrome`
- Analyze lints: `flutter analyze`
- Format code: `flutter format .`
- Run tests: `flutter test` (coverage: `flutter test --coverage`)
- Clean builds: `flutter clean`
- iOS setup if needed: `cd ios && pod install`

## Coding Style & Naming Conventions
- Dart style with `flutter_lints` (see `analysis_options.yaml`).
- Indentation: 2 spaces; keep lines readable (< 100–120 cols).
- Files: `snake_case.dart`; Classes: `PascalCase`; members: `camelCase`.
- Place code by role (e.g., auth logic in `services/auth_service.dart`, UI in `screens/`).

## Testing Guidelines
- Framework: `flutter_test` (unit + widget tests).
- Location: `dog_walker_app/test/`; filenames end with `_test.dart`.
- Write deterministic tests; prefer small, fast units for `utils/` and `services/`.
- Run `flutter test` locally before opening a PR.

## Commit & Pull Request Guidelines
- History shows short, descriptive commit messages (no strict convention).
- Recommended: `type(scope): imperative summary` (e.g., `feat(auth): add signup flow`).
- PRs should include: clear description, linked issues, test notes, and UI screenshots when applicable.
- Require passing `flutter analyze` and `flutter test`; update docs when behavior changes.

## Security & Configuration Tips
- Do not commit Firebase secrets. Keep `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` local per environment.
- Avoid hardcoding API keys; prefer platform configs or remote config.

## Agent-Specific Instructions
- Keep changes within the appropriate `lib/` module; do not edit generated/platform files unless necessary.
- After edits, run: `flutter format . && flutter analyze && flutter test`.
