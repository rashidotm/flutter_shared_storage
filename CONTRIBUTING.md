# Contributing

Thanks for wanting to contribute. This is a monorepo of four Flutter packages
published to pub.dev. The rules below keep things predictable across all four.

## Prerequisites

- Flutter **3.19+** (`flutter --version`)
- Dart **3.3+** (bundled with the above)
- **Melos** for workspace orchestration:
  ```bash
  dart pub global activate melos
  ```

## First-time setup

```bash
git clone https://github.com/rashidotm/flutter_shared_storage.git
cd flutter_shared_storage
melos bootstrap
```

`melos bootstrap` runs `flutter pub get` in every package and wires up the
`dependency_overrides` so sibling packages resolve to local sources rather
than the versions on pub.dev. Re-run it whenever you touch a `pubspec.yaml`.

## Repo layout

```
packages/
  cloud_storage_platform_interface/  # backend-agnostic contract
  cloud_storage_firebase/            # Firestore + Storage implementation
  cloud_storage/                     # umbrella re-exporting interface + firebase
  cloud_storage_gallery/             # Flutter widgets (grid, viewer, etc.)
example/                             # standalone app for manual testing
.github/workflows/                   # CI (analyze, format, test)
```

Every published package has:

- `lib/` — public surface via `<package>.dart`, internals under `lib/src/`.
- `test/` — unit + widget tests.
- `CHANGELOG.md` — one section per version, newest on top.
- `README.md` — package overview + usage snippet.
- `LICENSE` — MIT (mirrored from the repo root).

## Development workflow

Work on a feature branch, keep commits focused. Before opening a PR:

```bash
melos run analyze         # dart analyze in every package
melos run format-check    # dart format --set-exit-if-changed
melos run test            # every package's test suite
```

CI runs the same three commands — the analyze job and the test job are both
required for merge. Getting these green locally saves round-trips.

To auto-format your changes:

```bash
melos run format
```

## Testing policy

We test the code we own. We do NOT re-test third-party plugin behavior.

- ✅ Write tests for anything we add under `packages/*/lib/`.
- ✅ Use `test/support/fake_cloud_storage.dart` (in the gallery package) or
  `fake_cloud_firestore` / `firebase_storage_mocks` / `mocktail` for stubs.
- ❌ Don't write tests that exercise `file_picker`, `share_plus`,
  `video_player`, `photo_view`, `chewie`, `open_filex`, `url_launcher`,
  `image_picker`, or `cached_network_image` behavior — those plugins are
  their maintainers' responsibility.

If a change adds a new widget or public function, it should come with the
tests in the same PR. `melos run test` in CI will fail otherwise.

## Code style

- Follow `flutter_lints` — CI enforces this via `melos run analyze`.
- Format with `dart format` (via `melos run format`).
- Comments: only where the *why* is non-obvious. Don't restate what the code
  already says with well-named identifiers.
- Widgets derive **all** colors, text styles, and directionality from the
  ambient `Theme` / `Directionality`. No hardcoded colors, no inline
  `TextStyle` overrides. Icons inherit from `IconTheme`.

## Commit messages

- Subject line: imperative mood, under ~70 characters.
- Body: explain the *why* — hidden constraints, prior incidents, non-obvious
  trade-offs. Wrap around 72 characters.
- Reference issues where relevant.

## Pull requests

Before opening:

- [ ] Rebased on latest `master`.
- [ ] `melos run analyze` clean.
- [ ] `melos run format-check` clean.
- [ ] `melos run test` all pass.
- [ ] New public API includes doc comments.
- [ ] New public widget / function includes tests.
- [ ] `CHANGELOG.md` entry added under an `# Unreleased` heading in the
  affected package(s) (a maintainer will bump it into a versioned section
  at release time).

The PR description should explain what and why — reviewers should be able to
decide "is this the right change" without reading every line of the diff.

## Adding a new dependency

Weigh it carefully. Each `dependencies:` entry becomes part of the transitive
closure every consumer of our packages ships. Prefer:

1. A workspace-local implementation, if the surface is small.
2. A widely-adopted, actively-maintained package with no native code.
3. A native-code package only when strictly necessary — those constrain the
   supported Flutter version and platform matrix.

Dev-only deps have looser rules. Add them under `dev_dependencies:`.

## Publishing (maintainers)

Packages are published independently on pub.dev, versioned per-package. The
current versions live in each package's `pubspec.yaml`. Tags follow
`<package>-vX.Y.Z` (e.g. `cloud_storage_gallery-v0.5.0`).

Release order matters because of dependency chains:

1. `cloud_storage_platform_interface`
2. `cloud_storage_firebase` and `cloud_storage_gallery` (both depend on the
   interface, can be parallel)
3. `cloud_storage` (depends on interface + firebase)

Wait ~60 seconds between rounds for pub.dev to index the previous upload
before dependents can resolve their version constraints.

## Questions

Open an issue at
https://github.com/rashidotm/flutter_shared_storage/issues.
