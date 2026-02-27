# x (Rust Rewrite)

This repository now contains a Rust reimplementation of the legacy `t` CLI as `x`, with the original Ruby implementation preserved under `legacy/`.

## Migration Note

`t` has been renamed to `x` and rewritten from scratch in Rust (instead of Ruby).

The main reason for the rewrite is distribution and support: Rust binaries are much easier to compile and ship reliably. The previous Ruby version required users to set up and maintain a compatible Ruby environment and install runtime dependencies, which was brittle and hard to support across systems.

If you are interested in the previous implementation, it is preserved in the `legacy/` directory.

## Goals

- Preserve the legacy command and flag interface as closely as possible.
- Provide a modern Rust codebase and test suite.
- Keep the old Ruby implementation available for reference and compatibility validation.

## Status

- Command tree, aliases, and option definitions are parsed from `legacy/lib/t/*.rb` and exposed through the Rust CLI.
- API concerns (HTTP, auth, retry helpers, rcfile profile storage) live in the `x-api` package (`x-api/src`).
- Legacy command families (`cli`, `delete`, `list`, `search`, `set`, `stream`) are wired in the Rust runner.
- Local account/profile commands are still fully supported (`accounts`, `set active`, `delete account`, `version`, `ruler`).
- Stream commands now use persistent HTTP streaming:
  - `stream all` and `stream matrix` use OAuth2 sample stream.
  - `stream search`, `stream users`, `stream list`, and `stream timeline` use v2 filtered stream rules + stream.
- `X_STREAM_MAX_EVENTS` (or legacy `T_STREAM_MAX_EVENTS`) can be set to limit emitted events (useful for tests/automation).
- Default profile config is `~/.xrc`. If `~/.xrc` is missing, `~/.trc` is used as a read fallback and migrated on write.
- Fixture-driven behavioral parity tests are included under `tests/parity_fixtures.rs` and validated against fixtures from `legacy/spec/fixtures`.

## Toolchain

The project is pinned to Rust `1.93.1` via `rust-toolchain.toml`.

## Development

```bash
cargo test
cargo run -- version
cargo run -- accounts --profile /path/to/.xrc
```

## Releasing

Tagging a new `v*` release triggers GitHub Actions to build and publish binaries for:

- Linux (`x86_64-unknown-linux-gnu`)
- macOS Intel (`x86_64-apple-darwin`)
- macOS Apple Silicon (`aarch64-apple-darwin`)
- Windows (`x86_64-pc-windows-msvc`)

Install `cargo-release`:

```bash
cargo install cargo-release --locked
```

Then tag and push the current `Cargo.toml` version:

```bash
cargo release-tag
```

Tag messages come from `Cargo.toml` release metadata (`tag-message`).

## Legacy Ruby Code

The full original Ruby project is in `legacy/`.
