# Contributing to ALIVE

Thank you for your interest in contributing to **ALIVE**!

## Project Scope & Philosophy

ALIVE is intentionally minimal and focuses on answering a single question: **"How much can I spend today?"**
Before proposing large features, please keep in mind that the following are intentionally **out of scope** to keep the app calm and clutter-free:

- Cloud sync, user accounts, or third-party analytics SDKs
- Expense categories, budgets-per-category, or multi-currency ledgers
- Complex financial charts, bank scraping, or bill imports

## Development Setup

1. Install **Xcode 26+** and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. If you want to run on a physical iOS device, update `bundleIdPrefix` in `project.yml` to your own reverse-domain prefix and regenerate the Xcode project:

   ```bash
   xcodegen generate
   ```

3. Never edit `ALIVE.xcodeproj/project.pbxproj` directly; always modify `project.yml` and run `xcodegen generate`.

## Coding Standards

- **Swift 6 Strict Concurrency**: All targets compile with `SWIFT_STRICT_CONCURRENCY: complete`.
- **Single Source of Truth**: Domain rules, calendar math (`Asia/Shanghai`), and monetary formatting (`Decimal` / integer cents) live in `AliveCore`. Do not duplicate calculation logic in `Alive` or `AliveWidgets`.
- **Accessibility & Appearance**: Verify UI changes in both Light and Dark modes, and check Dynamic Type scaling.
- **No App Group**: `AliveWidgets` reads `ContentState` pushed by the App; intents execute in the App process.

## Running Tests

Run the full `AliveTests` suite before opening a Pull Request:

```bash
xcodebuild -project ALIVE.xcodeproj -scheme Alive \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -configuration Debug \
  test
```

## Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat(ios): ...`
- `fix(core): ...`
- `refactor(ui): ...`
- `docs(readme): ...`
- `test(core): ...`
