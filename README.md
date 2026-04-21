# x

A command-line interface for the X API.

## Features

- Full command tree with aliases and options
- X API client library (x-api) for HTTP, auth, and retry primitives
- OAuth 1.0a and OAuth 2.0 authentication
- Automatic retry with backoff for transient API errors
- V1.1 and V2 API support with automatic fallback
- Streaming support for filtered and sampled streams
- Column-aligned output formatting
- YAML configuration file support
- Bash completion support

## Status

- Command families: `cli`, `delete`, `list`, `search`, `set`, `stream`
- Local account/profile commands: `accounts`, `set active`, `delete account`, `version`, `ruler`
- Bookmark commands: `bookmarks`, `bookmark <id>`, `unbookmark <id>`
- Stream commands use persistent HTTP streaming:
  - `stream all` and `stream matrix` use OAuth2 sample stream
  - `stream search`, `stream users`, `stream list`, and `stream timeline` use v2 filtered stream rules + stream
- `X_STREAM_MAX_EVENTS` can be set to limit emitted events (useful for tests/automation)
- Default profile config is `~/.xrc`. If `~/.xrc` is missing, `~/.trc` is used as a read fallback and migrated on write.

## Bookmark Auth

X bookmarks require OAuth 2.0 user context with PKCE. The CLI now supports:

```bash
x authorize --oauth2
```

The OAuth 2.0 flow expects an app with OAuth 2.0 enabled, an exact callback URL match, and bookmark-capable scopes. By default the CLI requests:

```text
tweet.read users.read bookmark.read bookmark.write offline.access
```

Environment variables can prefill the OAuth 2.0 prompts:

```text
X_AUTHORIZE_OAUTH2_CLIENT_ID
X_AUTHORIZE_OAUTH2_CLIENT_SECRET
X_AUTHORIZE_OAUTH2_REDIRECT_URI
X_AUTHORIZE_OAUTH2_SCOPES
X_AUTHORIZE_OAUTH2_REDIRECTED_URL
```

`T_AUTHORIZE_OAUTH2_*` aliases are also accepted for compatibility with the existing authorize flow.

## Development

```bash
cargo test
cargo run -- version
cargo run -- accounts --profile /path/to/.xrc
```

## Releasing

Tagging a new `v*` release triggers GitHub Actions to build and publish binaries for:

- Linux (`x86_64-unknown-linux-gnu`)
- Linux ARM64 (`aarch64-unknown-linux-gnu`)
- macOS Intel (`x86_64-apple-darwin`)
- macOS Apple Silicon (`aarch64-apple-darwin`)
- Windows (`x86_64-pc-windows-msvc`)
- Windows ARM64 (`aarch64-pc-windows-msvc`)

Install `cargo-release`:

```bash
cargo install cargo-release --locked
```

Then tag and push the current `Cargo.toml` version:

```bash
cargo release-tag
```

Tag messages come from `Cargo.toml` release metadata (`tag-message`).
