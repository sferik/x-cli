# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.0.0] - 2026-03-02

### Added

- Rust rewrite of the t Twitter CLI with legacy-compatible command surface
- X API client library (x-api) for HTTP, auth, and retry primitives
- OAuth 1.0a and OAuth 2.0 authentication support
- Automatic retry with backoff for transient API errors
- V1.1 and V2 Twitter API support with automatic fallback
- Streaming support for filtered and sampled streams
- Column-aligned output format matching legacy Ruby CLI
- YAML configuration file support
- Bash completion support

[6.0.0]: https://github.com/sferik/x-cli/releases/tag/v6.0.0
