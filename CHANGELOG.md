# Changelog

All notable changes to **ALIVE** will be documented in this file.

## [1.0.0] - 2026-11-27

### Added
- **Daily Allowance Engine (`AliveCore`)**: Exact integer-cents / `Decimal` budget calculations over `[Start Date, Payday)` using a fixed `Asia/Shanghai` calendar boundary, supporting active, pending, overspent, zero-balance, and negative-balance states.
- **Bento Grid Home Screen (`Alive`)**: Modular Bento layout featuring a primary daily allowance hero tile, side-by-side days-remaining and balance tiles, and recent expense summary.
- **Quick Entry & Cycle History**: Top-unfolding quick-entry card with automatic keyboard focus and optional 80-character note, plus cycle history with expense editing, deletion confirmation, and archived read-only cycles.
- **Live Activity & Dynamic Island (`AliveWidgets`)**: Compact/minimal states with continuous ALIVE ribbon monogram, Lock Screen activity view with in-app continuity (`alive://live-entry`), and expanded Micro-Bento 2-step integer keypad entry via `LiveActivityIntent`.
- **App Icon**: Custom default, dark, and tinted `1024×1024` iOS app icons.
