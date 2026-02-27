#![deny(missing_docs)]
#![doc = r#"
`x-api` exposes the transport and authentication primitives used by the `x` CLI.

The crate focuses on:

- HTTP backends for live and test usage.
- OAuth1/OAuth2 authentication support.
- Retry wrappers for common JSON operations.
"#]

/// Backend traits and implementations used to call X/Twitter APIs.
pub mod backend;
