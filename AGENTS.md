# AGENTS.md

## Project Overview

OpenHours is a public Elixir package published on [Hex.pm](https://hex.pm/packages/open_hours). It provides business hours calculations: checking if a DateTime falls within working hours, generating time slots, and handling holidays, shifts, breaks, and timezones.

## Elixir Package Development

### Code Style and Formatting

- Run `mix format` before committing. The project uses a line length of 100 characters (see `.formatter.exs`).
- Follow the official [Elixir naming conventions](https://hexdocs.pm/elixir/naming-conventions.html): `snake_case` for functions and variables, `PascalCase` for modules.
- Use pattern matching and guard clauses over conditional branching when possible.
- Prefer pipeline (`|>`) style when transforming data through multiple steps.
- Keep functions short and focused. Extract private helpers with `defp` when a function grows beyond a single responsibility.

### Module and API Design

- Public API functions must have `@doc` and `@spec` typespecs. Every public function should be documented with at least one usage example in its `@doc` (these serve as doctests).
- Use `@moduledoc` at the top of every module to describe its purpose.
- Keep the public API surface small. Expose only what users need; use `defp` for implementation details.
- The schedule struct (`OpenHours.Schedule`) is always passed as the first argument to public functions, making the API pipe-friendly.

### Testing

- Run tests with `mix test`.
- Write tests in `test/` mirroring the `lib/` directory structure (e.g., `lib/open_hours/schedule.ex` -> `test/open_hours/schedule_test.exs`).
- Use `doctest` in test modules to validate documentation examples. Add `doctest ModuleName` to the corresponding test file when a module has documented examples.
- Cover edge cases: boundaries of time intervals, midnight crossings, DST transitions, holidays falling on shift days, empty schedules.
- Use descriptive test names that explain the scenario, not the implementation.

### Dependencies

- Keep dependencies minimal. This is a library — every dependency is inherited by users.
- Runtime dependencies must be justified. Development-only dependencies go in the `:dev` or `:test` environments.
- After adding or updating dependencies, run `mix deps.get` and verify `mix.lock` is consistent.

### Documentation

- Generate docs with `mix docs` and review them locally before publishing.
- Use `ex_doc` features: link to other modules with `Module`, link to functions with `function/arity`.
- Keep the README focused on getting started. Detailed API docs belong in `@doc`/`@moduledoc`.

### Publishing

- The package is published to Hex.pm automatically when a GitHub release is created (via `.github/workflows/publish.yml`).
- Never publish manually. Let the release automation handle it (see Release Workflow below).
- The version in `mix.exs` is managed by release-please. Do not bump it manually.

## Commit Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Every commit message must follow this format:

```
<type>(<optional scope>): <description>

[optional body]
```

### Commit Types

| Type | Purpose | Appears in changelog? |
|---|---|---|
| `feat` | New feature or functionality | Yes (Features) |
| `fix` | Bug fix | Yes (Bug Fixes) |
| `perf` | Performance improvement | Yes (Performance Improvements) |
| `revert` | Reverts a previous commit | Yes (Reverts) |
| `docs` | Documentation changes only | Yes (Documentation) |
| `deps` | Dependency updates | Yes (Dependencies) |
| `chore` | Maintenance, config, non-deps housekeeping | No (hidden) |
| `refactor` | Code restructuring, no behavior change | No (hidden) |
| `test` | Adding or updating tests | No (hidden) |
| `ci` | CI/CD pipeline changes | No (hidden) |

### Breaking Changes

- Add `!` after the type for breaking changes: `feat!: remove deprecated function`
- Or add a `BREAKING CHANGE:` footer in the commit body.
- Breaking changes trigger a minor version bump (pre-1.0) or major version bump (post-1.0).

### Examples

```
feat: add duration calculation between two DateTimes
fix: handle DST transition in time slot generation
docs: add examples for schedule configuration
deps: bump tzdata from 1.1.1 to 1.1.2
refactor: extract interval walking into shared helper
test: cover midnight crossing edge case in TimeSlot.between
```

## Release Workflow (release-please)

This project uses [release-please](https://github.com/googleapis/release-please) for automated versioning and changelog generation.

### How it works

1. Commits land on `main` following conventional commit format.
2. Release-please automatically creates/updates a "Release PR" that:
   - Bumps the version in `mix.exs` based on commit types (`feat` = minor, `fix` = patch).
   - Updates `CHANGELOG.md` with entries grouped by commit type.
   - Updates `.release-please-manifest.json` with the new version.
3. When the Release PR is merged, release-please creates a GitHub Release.
4. The GitHub Release triggers `.github/workflows/publish.yml`, which publishes to Hex.pm.

### Important rules

- Never edit `CHANGELOG.md` manually — release-please owns it.
- Never bump the version in `mix.exs` manually — release-please owns it.
- Never create GitHub releases manually — release-please owns them.
- The release type is `elixir` (configured in `release-please-config.json`).

## Dependency Management (Dependabot)

Dependabot is configured (`.github/dependabot.yml`) to check for updates daily on two ecosystems:

- **Mix dependencies** — uses `deps` commit prefix so updates appear in the changelog under "Dependencies".
- **GitHub Actions** — uses `ci` commit prefix (hidden from changelog).

### Handling Dependabot PRs

- Review dependency update PRs for breaking changes before merging.
- Ensure CI passes on Dependabot PRs before merging.
- Prefer merging Dependabot PRs promptly to avoid falling behind on security patches.


## CI Pipeline

CI runs on every pull request and push to `main` (`.github/workflows/ci.yml`):

- **Tests**: Run on two Elixir/OTP version pairs (1.16/26.2 and 1.18/27.1).
- **Linting** (runs on 1.16/26.2 only):
  - `mix format --check-formatted`
  - `mix deps.unlock --check-unused`

All checks must pass before merging. If format check fails, run `mix format` locally and commit the changes.
