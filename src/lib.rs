#![deny(missing_docs)]
#![doc = r#"
Library entrypoints for the `x` command-line client.

Most applications should execute the CLI by calling [`run`] or [`run_with_io`].
The module also re-exports `x-api` backend traits for test injection.
"#]

/// Command-tree parsing primitives derived from the legacy Ruby CLI.
pub mod manifest;
/// Rc/profile loading, migration, and account selection helpers.
pub mod rcfile;
mod runner;

/// Re-exported backend abstractions from `x-api`.
pub use x_api::backend;

use std::ffi::OsString;
use std::io::Write;

/// Runs the CLI with custom output streams.
pub fn run_with_io<I, T>(args: I, out: &mut dyn Write, err: &mut dyn Write) -> i32
where
    I: IntoIterator<Item = T>,
    T: Into<OsString> + Clone,
{
    runner::run_with_io(args, out, err)
}

/// Runs the CLI with a caller-provided backend implementation.
///
/// This is primarily used by tests to avoid live network calls.
pub fn run_with_backend<I, T>(
    args: I,
    out: &mut dyn Write,
    err: &mut dyn Write,
    backend: &mut dyn backend::Backend,
) -> i32
where
    I: IntoIterator<Item = T>,
    T: Into<OsString> + Clone,
{
    runner::run_with_backend(args, out, err, backend)
}

/// Runs the CLI using process arguments, stdout, and stderr.
pub fn run() -> i32 {
    let mut stdout = std::io::stdout();
    let mut stderr = std::io::stderr();
    run_with_io(std::env::args_os(), &mut stdout, &mut stderr)
}
