# Contributing to Tunnelbar

Thanks for your interest! Tunnelbar is a small, dependency-free native macOS
app, so contributing is straightforward.

## Prerequisites

- macOS 14+ (Apple Silicon)
- The Swift toolchain — **Xcode** or the **Command Line Tools**
  (`xcode-select --install`)
- `cloudflared` on your `PATH` only if you want to exercise cloudflared
  connections

There are **no external dependencies** — just Swift + AppKit/SwiftUI.

## Build & test

```sh
./scripts/run-tests.sh   # compile + run the logic tests
./build.sh               # produce Tunnelbar.app
open Tunnelbar.app
```

> The project builds with `swiftc` directly (see `build.sh`) rather than
> `swift build`, because SwiftPM's manifest API fails to link in bare Command
> Line Tools installs. With full Xcode, `swift build` also works.

## Project layout

| Path | Purpose |
|------|---------|
| `Sources/Tunnelbar/` | App sources (AppKit + SwiftUI) |
| `Tests/main.swift` | Pure-logic tests (run via `scripts/run-tests.sh`) |
| `scripts/` | Icon generation, test runner, legacy-data cleanup |
| `build.sh` / `package.sh` | Build the `.app` / package DMG + zip |
| `.github/workflows/` | `ci.yml` (build + test) and `release.yml` |

## Pull request workflow

`main` is protected — all changes land via pull request:

1. Branch off `main` (`feat/…`, `fix/…`, `docs/…`).
2. Make your change. If you touch the pure-logic layer (`CommandParser`,
   `Models`), add/extend tests in `Tests/main.swift`.
3. Run `./scripts/run-tests.sh` and `./build.sh` locally.
4. Open a PR. **CI (`build-and-test`) must pass** — it's a required check.
5. Squash-merge once green.

## Code style

- Match the surrounding code: comment density, naming, and idioms.
- Keep it dependency-free.
- Prefer small, focused PRs.

## Releasing (maintainers)

Run the **Release** workflow from the Actions tab (enter a version, e.g.
`1.4`), or push a `v*` tag. CI builds the DMG/zip, publishes the GitHub
Release, and auto-merges a PR bumping the version in `Info.plist`.
