use assert_cmd::cargo::cargo_bin_cmd;
use predicates::prelude::*;
use std::fs;
use std::path::{Path, PathBuf};

fn write_sample_rcfile(path: &std::path::Path) {
    let yaml = r#"
configuration:
  default_profile:
    - erik
    - key_b
profiles:
  alice:
    key_c:
      username: alice
      consumer_key: key_c
  erik:
    key_a:
      username: erik
      consumer_key: key_a
    key_b:
      username: erik
      consumer_key: key_b
"#;

    fs::write(path, yaml.trim_start()).expect("sample rcfile should be written");
}

fn utf8_path(path: &Path) -> &str {
    path.to_str().expect("utf8 path expected")
}

fn sample_profile() -> (tempfile::TempDir, PathBuf) {
    let temp = tempfile::tempdir().expect("tempdir should be created");
    let profile = temp.path().join(".trc");
    write_sample_rcfile(&profile);
    (temp, profile)
}

#[test]
fn version_command_and_flag_work() {
    let mut by_command = cargo_bin_cmd!("x");
    by_command
        .arg("version")
        .assert()
        .success()
        .stdout(predicate::str::contains(env!("CARGO_PKG_VERSION")));

    let mut by_flag = cargo_bin_cmd!("x");
    by_flag
        .arg("-v")
        .assert()
        .success()
        .stdout(predicate::str::contains(env!("CARGO_PKG_VERSION")));
}

#[test]
fn ruler_respects_indent_option() {
    let mut cmd = cargo_bin_cmd!("x");
    let assert = cmd.args(["ruler", "--indent", "2"]).assert().success();
    let output =
        String::from_utf8(assert.get_output().stdout.clone()).expect("stdout should be utf8");
    let lines = output.lines().collect::<Vec<_>>();

    assert_eq!(lines.len(), 1);
    assert!(lines[0].starts_with("  "));

    let ruler = &lines[0][2..];
    assert_eq!(ruler.len(), 280);
    for marker in (20usize..=280usize).step_by(20) {
        let label = marker.to_string();
        let start = marker - (label.len() + 1);
        assert_eq!(&ruler[start..start + label.len()], label);
        assert_eq!(&ruler[marker - 1..marker], "|");
    }
}

#[test]
fn accounts_marks_active_consumer_key() {
    let (_temp, profile) = sample_profile();

    let mut cmd = cargo_bin_cmd!("x");
    cmd.args(["accounts", "--profile", utf8_path(&profile)])
        .assert()
        .success()
        .stdout(predicate::str::contains("erik"))
        .stdout(predicate::str::contains("key_b (active)"));
}

#[test]
fn set_active_updates_default_profile() {
    let (_temp, profile) = sample_profile();

    let mut cmd = cargo_bin_cmd!("x");
    cmd.args([
        "set",
        "active",
        "erik",
        "key_a",
        "--profile",
        utf8_path(&profile),
    ])
    .assert()
    .success()
    .stdout(predicate::str::contains(
        "Active account has been updated to erik.",
    ));

    let updated = fs::read_to_string(&profile).expect("profile should be readable");
    assert!(updated.contains("- erik"));
    assert!(updated.contains("- key_a"));
}

#[test]
fn delete_account_removes_only_key_when_multiple_consumer_keys_exist() {
    let (_temp, profile) = sample_profile();

    let mut cmd = cargo_bin_cmd!("x");
    cmd.args([
        "delete",
        "account",
        "erik",
        "key_a",
        "--profile",
        utf8_path(&profile),
    ])
    .assert()
    .success();

    let updated = fs::read_to_string(&profile).expect("profile should be readable");
    assert!(!updated.contains("key_a"));
    assert!(updated.contains("key_b"));
    assert!(updated.contains("erik"));
}

#[test]
fn timeline_without_credentials_returns_authorization_error() {
    let temp = tempfile::tempdir().expect("tempdir should be created");
    let profile = temp.path().join("empty.trc");
    let mut cmd = cargo_bin_cmd!("x");
    cmd.args(["timeline", "--profile", utf8_path(&profile)])
        .assert()
        .code(1)
        .stderr(predicate::str::contains(
            "No active credentials found in profile",
        ));
}
