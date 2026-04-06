use crate::manifest::{clap_command, legacy_app_spec};
use crate::rcfile::{Credentials, RcFile, RcFileError, default_profile_path};
use base64::Engine;
use chrono::{DateTime, Duration, Local, TimeZone, Utc};
use clap::{ArgMatches, Command as ClapCommand};
use reqwest::Url;
use ring::digest::{SHA256, digest};
use ring::rand::{SecureRandom, SystemRandom};
use serde_json::Value;
use std::collections::{BTreeSet, HashMap};
use std::ffi::OsString;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};
use x_api::backend::{
    AuthScheme, Backend, BackendError, OAuth2UserContext, TwitterBackend,
    delete_json_oauth2_user_with_retry, format_api_error, get_json_oauth2_user_with_retry,
    get_json_oauth2_with_retry, get_json_with_retry,
    post_json_body_oauth2_user_with_retry as post_json_oauth2_user_with_retry,
    post_json_body_oauth2_with_retry as post_json_oauth2_with_retry, post_json_with_retry,
};
use x_api::oauth1::{self, ParamList, Token};

const DEFAULT_NUM_RESULTS: usize = 20;
const MAX_SEARCH_RESULTS: usize = 100;
const MAX_PAGE: usize = 51;
const V2_TWEET_FIELDS: &str = "author_id,created_at,entities,geo,id,in_reply_to_user_id,public_metrics,referenced_tweets,source,text";
const V2_USER_FIELDS: &str =
    "created_at,description,id,location,name,protected,public_metrics,url,username,verified";
const V2_LIST_FIELDS: &str =
    "created_at,description,follower_count,id,member_count,name,owner_id,private";
const V2_TWEET_EXPANSIONS: &str = "author_id,geo.place_id";
const V2_USER_EXPANSIONS: &str = "pinned_tweet_id";
const V2_PLACE_FIELDS: &str =
    "contained_within,country,country_code,full_name,geo,id,name,place_type";
const DEFAULT_OAUTH2_REDIRECT_URI: &str = "http://127.0.0.1:8080/callback";
const OAUTH2_DEFAULT_SCOPES: [&str; 5] = [
    "tweet.read",
    "users.read",
    "bookmark.read",
    "bookmark.write",
    "offline.access",
];
const TWEET_HEADINGS: [&str; 4] = ["ID", "Posted at", "Screen name", "Text"];
const DIRECT_MESSAGE_HEADINGS: [&str; 4] = ["ID", "Posted at", "Screen name", "Text"];
const LIST_HEADINGS: [&str; 8] = [
    "ID",
    "Created at",
    "Screen name",
    "Slug",
    "Members",
    "Subscribers",
    "Mode",
    "Description",
];
const COLLECTION_HEADINGS: [&str; 4] = ["ID", "Name", "Description", "URL"];
const PLACE_HEADINGS: [&str; 4] = ["ID", "Type", "Name", "Country"];
const TREND_HEADINGS: [&str; 5] = ["WOEID", "Parent ID", "Type", "Name", "Country"];
const USER_HEADINGS: [&str; 16] = [
    "ID",
    "Since",
    "Last tweeted at",
    "Tweets",
    "Favorites",
    "Listed",
    "Following",
    "Followers",
    "Screen name",
    "Name",
    "Verified",
    "Protected",
    "Bio",
    "Status",
    "Location",
    "URL",
];

pub fn run_with_io<I, T>(args: I, out: &mut dyn Write, err: &mut dyn Write) -> i32
where
    I: IntoIterator<Item = T>,
    T: Into<OsString> + Clone,
{
    run_with_optional_backend(args, out, err, None)
}

pub fn run_with_backend<I, T>(
    args: I,
    out: &mut dyn Write,
    err: &mut dyn Write,
    backend: &mut dyn Backend,
) -> i32
where
    I: IntoIterator<Item = T>,
    T: Into<OsString> + Clone,
{
    run_with_optional_backend(args, out, err, Some(backend))
}

fn run_with_optional_backend<I, T>(
    args: I,
    out: &mut dyn Write,
    err: &mut dyn Write,
    backend_override: Option<&mut dyn Backend>,
) -> i32
where
    I: IntoIterator<Item = T>,
    T: Into<OsString> + Clone,
{
    let app_spec = legacy_app_spec();
    let matches = match clap_command(&app_spec).try_get_matches_from(args) {
        Ok(matches) => matches,
        Err(parse_error) => {
            let rendered = parse_error.render().to_string();
            let _ = if parse_error.use_stderr() {
                writeln!(err, "{}", rendered.trim_end())
            } else {
                writeln!(out, "{}", rendered.trim_end())
            };
            return parse_error.exit_code();
        }
    };

    if matches
        .try_get_one::<bool>("version_flag")
        .ok()
        .flatten()
        .copied()
        .unwrap_or(false)
        && matches.subcommand_name().is_none()
    {
        let _ = writeln!(out, "{}", env!("CARGO_PKG_VERSION"));
        return 0;
    }

    let Some((path, leaf)) = leaf_path(&matches) else {
        let mut help = clap_command(&app_spec);
        let mut rendered_help = Vec::new();
        let _ = help.write_help(&mut rendered_help);
        let _ = out.write_all(&rendered_help);
        return 0;
    };

    if let Some(exit_code) =
        maybe_render_group_help_without_subcommand(&app_spec, &path, leaf, out, err)
    {
        return exit_code;
    }

    let context = CommandContext {
        profile_path: matches
            .get_one::<String>("profile")
            .map(PathBuf::from)
            .unwrap_or_else(default_profile_path),
        color: matches
            .get_one::<String>("color")
            .cloned()
            .unwrap_or_else(|| "auto".to_string()),
    };

    let args = leaf
        .get_many::<String>("args")
        .map(|values| values.cloned().collect::<Vec<_>>())
        .unwrap_or_default();

    let result = match execute_local_command(&path, leaf, &args, &context, out) {
        Ok(Some(exit_code)) => Ok(exit_code),
        Ok(None) => match backend_override {
            Some(backend) => {
                execute_remote_command(&path, leaf, &args, &context, backend, out, err)
            }
            None => execute_remote_with_profile_backend(&path, leaf, &args, &context, out, err),
        },
        Err(error) => Err(error),
    };

    match result {
        Ok(code) => code,
        Err(error) => {
            let program = std::env::args().next().unwrap_or_else(|| "x".to_string());
            let _ = writeln!(err, "{program}: {}", format_error_for_display(&error));
            if let Some(hint) = backend_error_hint(&error) {
                let _ = writeln!(err, "{hint}");
            }
            1
        }
    }
}

fn execute_remote_with_profile_backend(
    path: &[String],
    leaf: &ArgMatches,
    args: &[String],
    context: &CommandContext,
    out: &mut dyn Write,
    err: &mut dyn Write,
) -> Result<i32, CommandError> {
    let mut rcfile = RcFile::load(&context.profile_path)?;
    let active_profile = rcfile
        .active_profile()
        .map(|(username, key)| (username.to_string(), key.to_string()));
    let Some(credentials) = rcfile.active_credentials().cloned() else {
        return Err(CommandError::Backend(BackendError::MissingCredentials));
    };
    let original_credentials = credentials.clone();

    let mut backend = TwitterBackend::from_credentials(credentials)?;
    let result = execute_remote_command(path, leaf, args, context, &mut backend, out, err);

    // Always persist refreshed credentials, even when the command itself fails.
    // X/Twitter uses refresh-token rotation: once a refresh token is exchanged,
    // the previous one is permanently invalidated. Saving only on success meant
    // that any post-refresh failure (API error, broken pipe, etc.) would discard
    // the new tokens, leaving the now-invalid old refresh token on disk and
    // causing `invalid_request` on the next run.
    if backend.credentials() != &original_credentials
        && let Some((username, key)) = active_profile
    {
        rcfile.upsert_profile_credentials(&username, &key, backend.credentials().clone());
        // Best-effort: don't let a save failure mask the original command result.
        let _ = rcfile.save(&context.profile_path);
    }

    result
}

struct CommandContext {
    profile_path: PathBuf,
    color: String,
}

#[derive(Debug, thiserror::Error)]
enum CommandError {
    #[error(transparent)]
    RcFile(#[from] RcFileError),
    #[error(transparent)]
    Backend(#[from] BackendError),
    #[error("I/O error: {0}")]
    Io(#[from] io::Error),
    #[error(
        "Missing required argument for command {command}: expected at least {expected} arguments"
    )]
    MissingArguments { command: String, expected: usize },
    #[error("{0}")]
    Other(String),
}

/// Formats an error for user-facing display.
///
/// For HTTP API errors, strips the internal `"NNN: "` status prefix so the output
/// reads like `"x: CreditsDepleted: Your enrolled account..."` instead of
/// `"x: 402: CreditsDepleted: ..."`.
fn format_error_for_display(error: &CommandError) -> String {
    if let CommandError::Backend(BackendError::Http(message)) = error {
        // Strip leading "NNN: " prefix added by format_api_error
        if let Some(rest) = message
            .strip_prefix(|c: char| c.is_ascii_digit())
            .and_then(|s| s.strip_prefix(|c: char| c.is_ascii_digit()))
            .and_then(|s| s.strip_prefix(|c: char| c.is_ascii_digit()))
            .and_then(|s| s.strip_prefix(": "))
        {
            return rest.to_string();
        }
    }
    error.to_string()
}

fn backend_error_hint(error: &CommandError) -> Option<&'static str> {
    let CommandError::Backend(BackendError::Http(message)) = error else {
        return None;
    };

    let has_429 = message.contains("429:");
    let has_403 = message.contains("403:");

    if has_429 && has_403 {
        return Some(
            "Hint: X API access appears limited by both permissions and rate limits. \
Confirm endpoint access for this account/app and retry after the rate-limit window resets.",
        );
    }

    if has_429 {
        return Some(
            "Hint: X API rate limit reached. Wait for the limit window to reset and retry.",
        );
    }

    if has_403 {
        return None;
    }

    None
}

fn overlay_text(line: &mut Vec<char>, start: usize, text: &str) {
    let needed = start + text.chars().count();
    if line.len() < needed {
        line.resize(needed, ' ');
    }
    for (index, ch) in text.chars().enumerate() {
        line[start + index] = ch;
    }
}

fn numbered_ruler_line() -> String {
    let width = 280usize;
    let mut line = (1..=width)
        .map(|position| {
            if position % 10 == 0 {
                '|'
            } else if position % 5 == 0 {
                ':'
            } else {
                '.'
            }
        })
        .collect::<Vec<_>>();

    for marker in (20..=width).step_by(20) {
        line[marker - 1] = '|';
        let label = marker.to_string();
        let start = marker - (label.len() + 1);
        overlay_text(&mut line, start, &label);
    }

    line.into_iter().collect()
}

fn execute_local_command(
    path: &[String],
    leaf: &ArgMatches,
    args: &[String],
    context: &CommandContext,
    out: &mut dyn Write,
) -> Result<Option<i32>, CommandError> {
    match path {
        [single] if single == "version" => {
            writeln!(out, "{}", env!("CARGO_PKG_VERSION")).ok();
            Ok(Some(0))
        }
        [single] if single == "ruler" => {
            let indent = leaf
                .get_one::<String>("indent")
                .and_then(|value| value.parse::<usize>().ok())
                .unwrap_or(0);
            writeln!(out, "{}{}", " ".repeat(indent), numbered_ruler_line()).ok();
            Ok(Some(0))
        }
        [single] if single == "accounts" => {
            let rcfile = RcFile::load(&context.profile_path)?;
            let active_profile = rcfile
                .active_profile()
                .map(|(username, key)| (username.to_ascii_lowercase(), key.to_ascii_lowercase()));

            for (profile_name, keys) in rcfile.profiles() {
                writeln!(out, "{}", profile_name).ok();
                for key in keys.keys() {
                    let active = active_profile
                        .as_ref()
                        .map(|(active_name, active_key)| {
                            active_name.eq_ignore_ascii_case(profile_name)
                                && active_key.eq_ignore_ascii_case(key)
                        })
                        .unwrap_or(false);
                    if active {
                        writeln!(out, "  {} (active)", key).ok();
                    } else {
                        writeln!(out, "  {}", key).ok();
                    }
                }
            }
            Ok(Some(0))
        }
        [first, second] if first == "set" && second == "active" => {
            ensure_min_args(path, args, 1)?;
            let username = &args[0];
            let consumer_key = args.get(1).map(String::as_str);

            let mut rcfile = RcFile::load(&context.profile_path)?;
            let active = rcfile.set_active(username, consumer_key)?;
            rcfile.save(&context.profile_path)?;
            writeln!(out, "Active account has been updated to {}.", active).ok();
            Ok(Some(0))
        }
        [first, second] if first == "delete" && second == "account" => {
            ensure_min_args(path, args, 1)?;
            let account = &args[0];
            let key = args.get(1).map(String::as_str);

            let mut rcfile = RcFile::load(&context.profile_path)?;
            rcfile.delete_account(account, key)?;
            rcfile.save(&context.profile_path)?;
            Ok(Some(0))
        }
        _ => Ok(None),
    }
}

fn execute_remote_command(
    path: &[String],
    leaf: &ArgMatches,
    args: &[String],
    context: &CommandContext,
    backend: &mut dyn Backend,
    out: &mut dyn Write,
    err: &mut dyn Write,
) -> Result<i32, CommandError> {
    let rcfile = RcFile::load(&context.profile_path)?;
    let active_name = rcfile
        .active_profile()
        .map(|(name, _)| name.to_string())
        .unwrap_or_else(|| "unknown".to_string());
    let active_credentials = rcfile.active_credentials().cloned();

    match path {
        [single] if single == "authorize" => {
            run_authorize(
                leaf,
                &context.profile_path,
                active_credentials.as_ref(),
                out,
                err,
            )?;
            Ok(0)
        }
        [single] if single == "bookmark" => {
            ensure_min_args(path, args, 1)?;
            let me_id = authenticated_user_id_for_bookmarks(backend)?;
            let ids = resolve_id_list(args);
            for id in &ids {
                let _ = post_json_oauth2_user_with_retry(
                    backend,
                    &format!("/2/users/{me_id}/bookmarks"),
                    serde_json::json!({ "tweet_id": id }),
                )?;
            }
            writeln!(
                out,
                "@{} bookmarked {}.",
                active_name,
                pluralize(ids.len(), "post", None)
            )
            .ok();
            Ok(0)
        }
        [single] if single == "bookmarks" => {
            let me_id = authenticated_user_id_for_bookmarks(backend)?;
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = collect_tweets_paginated(
                backend,
                &format!("/2/users/{me_id}/bookmarks"),
                bookmark_v2_params(leaf),
                AuthScheme::OAuth2User,
                number,
            )?;
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [single] if single == "open" => {
            ensure_min_args(path, args, 1)?;
            if opt_bool(leaf, "status") {
                writeln!(out, "https://twitter.com/i/web/status/{}", args[0]).ok();
            } else if opt_bool(leaf, "id") {
                writeln!(out, "https://twitter.com/i/user/{}", args[0]).ok();
            } else {
                writeln!(out, "https://twitter.com/{}", strip_at(&args[0])).ok();
            }
            Ok(0)
        }
        [single] if single == "block" => {
            ensure_min_args(path, args, 1)?;
            let users = resolve_user_list(args, opt_bool(leaf, "id"));
            let me_id = authenticated_user_id(backend)?;
            let mut blocked = Vec::new();
            for user in users {
                let target_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
                let response = backend.post_json_body(
                    &format!("/2/users/{me_id}/blocking"),
                    serde_json::json!({ "target_user_id": target_id }),
                )?;
                blocked.push(display_user_from_response(&response, &user));
            }
            writeln!(
                out,
                "@{} blocked {}.",
                active_name,
                pluralize(blocked.len(), "user", None)
            )
            .ok();
            if !blocked.is_empty() {
                writeln!(out).ok();
                writeln!(
                    out,
                    "Run `x delete block {}` to unblock.",
                    blocked
                        .iter()
                        .map(|user| format!("@{user}"))
                        .collect::<Vec<_>>()
                        .join(" ")
                )
                .ok();
            }
            Ok(0)
        }
        [single] if single == "mute" => {
            ensure_min_args(path, args, 1)?;
            let users = resolve_user_list(args, opt_bool(leaf, "id"));
            let me_id = authenticated_user_id(backend)?;
            let mut muted = Vec::new();
            for user in users {
                let target_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
                let response = backend.post_json_body(
                    &format!("/2/users/{me_id}/muting"),
                    serde_json::json!({ "target_user_id": target_id }),
                )?;
                muted.push(display_user_from_response(&response, &user));
            }
            writeln!(
                out,
                "@{} muted {}.",
                active_name,
                pluralize(muted.len(), "user", None)
            )
            .ok();
            Ok(0)
        }
        [single] if single == "follow" => {
            ensure_min_args(path, args, 1)?;
            let users = resolve_user_list(args, opt_bool(leaf, "id"));
            let me_id = authenticated_user_id(backend)?;
            let mut followed = Vec::new();
            for user in users {
                let target_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
                let response = backend.post_json_body(
                    &format!("/2/users/{me_id}/following"),
                    serde_json::json!({ "target_user_id": target_id }),
                )?;
                followed.push(display_user_from_response(&response, &user));
            }
            writeln!(
                out,
                "@{} is now following {}.",
                active_name,
                pluralize(followed.len(), "more user", Some("more users"))
            )
            .ok();
            Ok(0)
        }
        [single] if single == "unfollow" => {
            ensure_min_args(path, args, 1)?;
            let users = resolve_user_list(args, opt_bool(leaf, "id"));
            let me_id = authenticated_user_id(backend)?;
            let mut unfollowed = Vec::new();
            for user in users {
                let target_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
                let response = backend.delete_json(
                    &format!("/2/users/{me_id}/following/{target_id}"),
                    Vec::new(),
                )?;
                unfollowed.push(display_user_from_response(&response, &user));
            }
            writeln!(
                out,
                "@{} is no longer following {}.",
                active_name,
                pluralize(unfollowed.len(), "user", None)
            )
            .ok();
            Ok(0)
        }
        [single] if single == "unbookmark" => {
            ensure_min_args(path, args, 1)?;
            let me_id = authenticated_user_id_for_bookmarks(backend)?;
            let ids = resolve_id_list(args);
            for id in &ids {
                let _ = delete_json_oauth2_user_with_retry(
                    backend,
                    &format!("/2/users/{me_id}/bookmarks/{id}"),
                    Vec::new(),
                )?;
            }
            writeln!(
                out,
                "@{} removed {}.",
                active_name,
                pluralize(ids.len(), "bookmark", None)
            )
            .ok();
            Ok(0)
        }
        [single] if single == "report_spam" => {
            ensure_min_args(path, args, 1)?;
            let users = resolve_user_list(args, opt_bool(leaf, "id"));
            for user in &users {
                let _ = backend.post_json(
                    "/1.1/users/report_spam.json",
                    vec![user_query_param(opt_bool(leaf, "id"), user)],
                )?;
            }
            writeln!(
                out,
                "@{} reported {}.",
                active_name,
                pluralize(users.len(), "user", None)
            )
            .ok();
            Ok(0)
        }
        [single] if single == "favorite" => {
            ensure_min_args(path, args, 1)?;
            let ids = resolve_id_list(args);
            let me_id = authenticated_user_id(backend)?;
            for id in &ids {
                let _ = backend.post_json_body(
                    &format!("/2/users/{me_id}/likes"),
                    serde_json::json!({ "tweet_id": id }),
                )?;
            }
            writeln!(
                out,
                "@{} favorited {}.",
                active_name,
                pluralize(ids.len(), "tweet", None)
            )
            .ok();
            Ok(0)
        }
        [single] if single == "retweet" => {
            ensure_min_args(path, args, 1)?;
            let ids = resolve_id_list(args);
            let me_id = authenticated_user_id(backend)?;
            for id in &ids {
                let _ = backend.post_json_body(
                    &format!("/2/users/{me_id}/retweets"),
                    serde_json::json!({ "tweet_id": id }),
                )?;
            }
            writeln!(
                out,
                "@{} retweeted {}.",
                active_name,
                pluralize(ids.len(), "tweet", None)
            )
            .ok();
            Ok(0)
        }
        [single] if single == "dm" => {
            ensure_min_args(path, args, 2)?;
            let target = if opt_bool(leaf, "id") {
                args[0].clone()
            } else {
                let user = fetch_user(backend, &args[0], false)?;
                value_id(&user).unwrap_or_else(|| args[0].clone())
            };
            let message = args[1..].join(" ");
            let _ = backend.post_json_body(
                &format!("/2/dm_conversations/with/{target}/messages"),
                serde_json::json!({ "text": message }),
            )?;
            writeln!(
                out,
                "Direct Message sent from @{} to @{}.",
                active_name,
                strip_at(&args[0])
            )
            .ok();
            Ok(0)
        }
        [single] if single == "update" => {
            let message = args.join(" ");
            let mut body = serde_json::json!({ "text": message });
            if let Some(file) = opt_string(leaf, "file") {
                let media_id = upload_media(backend, file)?;
                body["media"] = serde_json::json!({ "media_ids": [media_id] });
            } else if args.is_empty() {
                ensure_min_args(path, args, 1)?;
            }
            let response = backend.post_json_body("/2/tweets", body)?;
            let id = value_id(&response)
                .or_else(|| response.get("data").and_then(value_id))
                .unwrap_or_default();
            writeln!(out, "Tweet posted by @{}.", active_name).ok();
            if !id.is_empty() {
                writeln!(out).ok();
                writeln!(out, "Run `x delete status {id}` to delete.").ok();
            }
            Ok(0)
        }
        [single] if single == "reply" => {
            ensure_min_args(path, args, 1)?;
            let status_id = args[0].clone();
            let status =
                backend.get_json_oauth2(&format!("/2/tweets/{status_id}"), v2_tweet_params())?;
            let status = extract_tweets(&status).into_iter().next().unwrap_or(status);
            let mut users = vec![
                status
                    .get("user")
                    .and_then(|user| user.get("screen_name"))
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string(),
            ];
            if opt_bool(leaf, "all") {
                users.extend(extract_mentions(&tweet_text(&status, false)));
                users.sort();
                users.dedup();
            }
            users.retain(|user| !user.eq_ignore_ascii_case(&active_name));
            let prefix = users
                .iter()
                .map(|user| format!("@{}", strip_at(user)))
                .collect::<Vec<_>>()
                .join(" ");

            let message = if args.len() >= 2 {
                args[1..].join(" ")
            } else {
                String::new()
            };
            let reply_text = format!("{} {}", prefix, message).trim().to_string();
            let mut body = serde_json::json!({
                "text": reply_text,
                "reply": { "in_reply_to_tweet_id": status_id }
            });
            if let Some(file) = opt_string(leaf, "file") {
                let media_id = upload_media(backend, file)?;
                body["media"] = serde_json::json!({ "media_ids": [media_id] });
            }
            let response = backend.post_json_body("/2/tweets", body)?;
            let id = value_id(&response)
                .or_else(|| response.get("data").and_then(value_id))
                .unwrap_or_default();
            writeln!(out, "Reply posted by @{} to {}.", active_name, prefix).ok();
            if !id.is_empty() {
                writeln!(out).ok();
                writeln!(out, "Run `x delete status {id}` to delete.").ok();
            }
            Ok(0)
        }
        [single] if single == "does_follow" => {
            ensure_min_args(path, args, 1)?;
            let user1 = normalize_user_arg(&args[0], opt_bool(leaf, "id"));
            let user2 = args
                .get(1)
                .map(|user| normalize_user_arg(user, opt_bool(leaf, "id")))
                .unwrap_or_else(|| active_name.clone());
            let user1_id = resolve_user_id(backend, &user1, opt_bool(leaf, "id"))?;
            let user2_id = resolve_user_id(backend, &user2, opt_bool(leaf, "id"))?;
            let follows = fetch_relationship_ids_v2(backend, &user1_id, "following")?
                .into_iter()
                .any(|id| id == user2_id);

            if follows {
                writeln!(
                    out,
                    "Yes, @{} follows @{}.",
                    strip_at(&user1),
                    strip_at(&user2)
                )
                .ok();
                Ok(0)
            } else {
                writeln!(
                    err,
                    "No, @{} does not follow @{}.",
                    strip_at(&user1),
                    strip_at(&user2)
                )
                .ok();
                Ok(1)
            }
        }
        [single] if single == "does_contain" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id = resolve_list_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let list_name = if opt_bool(leaf, "id") {
                args[0].clone()
            } else {
                extract_owner_and_list(&args[0], false, default_owner).1
            };
            let user = args
                .get(1)
                .map(|candidate| normalize_user_arg(candidate, opt_bool(leaf, "id")))
                .unwrap_or_else(|| active_name.clone());
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let contains = fetch_list_member_ids_v2(backend, &list_id)?
                .into_iter()
                .any(|member_id| member_id == user_id);

            if contains {
                writeln!(out, "Yes, {} contains @{}.", list_name, strip_at(&user)).ok();
                Ok(0)
            } else {
                writeln!(
                    err,
                    "No, {} does not contain @{}.",
                    list_name,
                    strip_at(&user)
                )
                .ok();
                Ok(1)
            }
        }
        [single] if single == "reach" => {
            ensure_min_args(path, args, 1)?;
            let status = backend.get_json(
                &format!("/2/tweets/{}", args[0]),
                [
                    v2_tweet_params(),
                    vec![
                        ("expansions".to_string(), "author_id".to_string()),
                        ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
                    ],
                ]
                .concat(),
            )?;
            let tweet = extract_tweets(&status).into_iter().next().unwrap_or(status);
            let author_id = tweet
                .get("user")
                .and_then(value_id)
                .or_else(|| {
                    tweet
                        .get("author_id")
                        .and_then(Value::as_str)
                        .map(ToString::to_string)
                })
                .unwrap_or_default();
            let retweeters = backend.get_json_oauth2(
                &format!("/2/tweets/{}/retweeted_by", args[0]),
                vec![("max_results".to_string(), "100".to_string())],
            )?;
            let mut ids = extract_ids(&retweeters)
                .into_iter()
                .collect::<BTreeSet<_>>();
            ids.insert(author_id.clone());

            let mut audience = BTreeSet::new();
            for user_id in ids {
                for follower in fetch_relationship_ids_v2(backend, &user_id, "followers")? {
                    audience.insert(follower);
                }
            }
            audience.remove(&author_id);
            writeln!(out, "{}", number_with_delimiter(audience.len() as i64, ',')).ok();
            Ok(0)
        }
        [single] if single == "matrix" => {
            run_matrix_stream(backend, out)?;
            Ok(0)
        }
        [single] if single == "direct_messages" => {
            handle_direct_messages(backend, leaf, out, false)?;
            Ok(0)
        }
        [single] if single == "direct_messages_sent" => {
            handle_direct_messages(backend, leaf, out, true)?;
            Ok(0)
        }
        [single] if single == "favorites" => {
            let mut params = timeline_like_v2_params(leaf);
            params.extend(v2_tweet_params());
            let user = arg_or_active_name(args, &active_name);
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = collect_tweets_paginated(
                backend,
                &format!("/2/users/{user_id}/liked_tweets"),
                params,
                AuthScheme::OAuth1User,
                number,
            )?;
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [single] if single == "mentions" => {
            let me = fetch_current_user_with_credentials(backend, active_credentials.as_ref())?;
            let me_id = value_id(&me).unwrap_or_default();
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = collect_tweets_paginated(
                backend,
                &format!("/2/users/{me_id}/mentions"),
                timeline_v2_params(leaf),
                AuthScheme::OAuth1User,
                number,
            )?;
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [single] if single == "retweets" => {
            let params = timeline_v2_params(leaf);
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let mut tweets = if let Some(user) = args.first() {
                let user_id = resolve_user_id(backend, user, opt_bool(leaf, "id"))?;
                collect_tweets_paginated(
                    backend,
                    &format!("/2/users/{user_id}/tweets"),
                    params,
                    AuthScheme::OAuth2Bearer,
                    number,
                )?
            } else {
                collect_tweets_paginated(
                    backend,
                    "/2/users/reposts_of_me",
                    params,
                    AuthScheme::OAuth1User,
                    number,
                )?
            };
            if !args.is_empty() {
                tweets.retain(|tweet| tweet_text(tweet, false).starts_with("RT @"));
            }
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [single] if single == "retweets_of_me" => {
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = collect_tweets_paginated(
                backend,
                "/2/users/reposts_of_me",
                timeline_v2_params(leaf),
                AuthScheme::OAuth1User,
                number,
            )?;
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [single] if single == "timeline" => {
            let params = timeline_v2_params(leaf);
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = if let Some(user) = args.first() {
                let user_id = resolve_user_id(backend, user, opt_bool(leaf, "id"))?;
                collect_tweets_paginated(
                    backend,
                    &format!("/2/users/{user_id}/tweets"),
                    params,
                    AuthScheme::OAuth2Bearer,
                    number,
                )?
            } else {
                let me = fetch_current_user_with_credentials(backend, active_credentials.as_ref())?;
                let me_id = value_id(&me).unwrap_or_default();
                collect_tweets_paginated(
                    backend,
                    &format!("/2/users/{me_id}/timelines/reverse_chronological"),
                    params,
                    AuthScheme::OAuth1User,
                    number,
                )?
            };
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [single] if single == "status" => {
            ensure_min_args(path, args, 1)?;
            let response =
                backend.get_json_oauth2(&format!("/2/tweets/{}", args[0]), v2_tweet_params())?;
            let status = extract_tweets(&response)
                .into_iter()
                .next()
                .unwrap_or(response);
            print_status(&status, leaf, out);
            let mut chain = Vec::new();
            let mut current = status;
            for _ in 0..10 {
                let parent_id = match current.get("in_reply_to_status_id").and_then(Value::as_str) {
                    Some(id) => id.to_string(),
                    None => break,
                };
                let parent_response = backend
                    .get_json_oauth2(&format!("/2/tweets/{}", parent_id), v2_tweet_params())?;
                match extract_tweets(&parent_response).into_iter().next() {
                    Some(p) => {
                        current = p.clone();
                        chain.push(p);
                    }
                    None => break,
                }
            }
            if !chain.is_empty() {
                writeln!(out).ok();
                writeln!(out, "In reply to:").ok();
                print_tweets(&chain, leaf, out, &context.color);
            }
            Ok(0)
        }
        [single] if single == "users" => {
            ensure_min_args(path, args, 1)?;
            let response = backend.get_json_oauth2(
                if opt_bool(leaf, "id") {
                    "/2/users"
                } else {
                    "/2/users/by"
                },
                vec![
                    if opt_bool(leaf, "id") {
                        (
                            "ids".to_string(),
                            args.iter()
                                .map(String::as_str)
                                .collect::<Vec<_>>()
                                .join(","),
                        )
                    } else {
                        (
                            "usernames".to_string(),
                            args.iter()
                                .map(|user| strip_at(user))
                                .collect::<Vec<_>>()
                                .join(","),
                        )
                    },
                    ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
                    ("expansions".to_string(), V2_USER_EXPANSIONS.to_string()),
                    ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
                ],
            )?;
            print_users(&extract_users(&response), leaf, out);
            Ok(0)
        }
        [single] if single == "whois" => {
            ensure_min_args(path, args, 1)?;
            let user = fetch_user(backend, &args[0], opt_bool(leaf, "id"))?;
            print_whois(&user, leaf, out);
            Ok(0)
        }
        [single] if single == "whoami" => {
            if let Some((_username, _)) = rcfile.active_profile() {
                let user =
                    fetch_current_user_with_credentials(backend, active_credentials.as_ref())?;
                print_whois(&user, leaf, out);
            } else {
                writeln!(
                    err,
                    "You haven't authorized an account, run `x authorize` to get started."
                )
                .ok();
            }
            Ok(0)
        }
        [single] if single == "followings" => {
            let user = arg_or_active_name(args, &active_name);
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let ids = fetch_relationship_ids_v2(backend, &user_id, "following")?;
            let users = lookup_users_by_ids(backend, &ids)?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "followers" => {
            let user = arg_or_active_name(args, &active_name);
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let ids = fetch_relationship_ids_v2(backend, &user_id, "followers")?;
            let users = lookup_users_by_ids(backend, &ids)?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "friends" => {
            let user = arg_or_active_name(args, &active_name);
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let friend_ids = fetch_relationship_ids_v2(backend, &user_id, "following")?;
            let follower_ids = fetch_relationship_ids_v2(backend, &user_id, "followers")?;
            let set = friend_ids
                .into_iter()
                .collect::<BTreeSet<_>>()
                .intersection(&follower_ids.into_iter().collect())
                .cloned()
                .collect::<Vec<_>>();
            let users = lookup_users_by_ids(backend, &set)?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "groupies" => {
            let user = arg_or_active_name(args, &active_name);
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let friend_ids = fetch_relationship_ids_v2(backend, &user_id, "following")?;
            let follower_ids = fetch_relationship_ids_v2(backend, &user_id, "followers")?;
            let set = follower_ids
                .into_iter()
                .collect::<BTreeSet<_>>()
                .difference(&friend_ids.into_iter().collect())
                .cloned()
                .collect::<Vec<_>>();
            let users = lookup_users_by_ids(backend, &set)?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "leaders" => {
            let user = arg_or_active_name(args, &active_name);
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let friend_ids = fetch_relationship_ids_v2(backend, &user_id, "following")?;
            let follower_ids = fetch_relationship_ids_v2(backend, &user_id, "followers")?;
            let set = friend_ids
                .into_iter()
                .collect::<BTreeSet<_>>()
                .difference(&follower_ids.into_iter().collect())
                .cloned()
                .collect::<Vec<_>>();
            let users = lookup_users_by_ids(backend, &set)?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "followings_following" => {
            ensure_min_args(path, args, 1)?;
            let user1 = resolve_user_id(backend, &args[0], opt_bool(leaf, "id"))?;
            let user2_id = if let Some(candidate) = args.get(1) {
                resolve_user_id(backend, candidate, opt_bool(leaf, "id"))?
            } else {
                value_id(&fetch_current_user(backend)?).unwrap_or_default()
            };
            let follower_ids = fetch_relationship_ids_v2(backend, &user1, "followers")?;
            let following_ids = fetch_relationship_ids_v2(backend, &user2_id, "following")?;
            let set = follower_ids
                .into_iter()
                .collect::<BTreeSet<_>>()
                .intersection(&following_ids.into_iter().collect())
                .cloned()
                .collect::<Vec<_>>();
            let users = lookup_users_by_ids(backend, &set)?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "intersection" => {
            ensure_min_args(path, args, 1)?;
            let mut users = args
                .iter()
                .map(|arg| resolve_user_id(backend, arg, opt_bool(leaf, "id")))
                .collect::<Result<Vec<_>, _>>()?;
            if users.is_empty() {
                users = Vec::new();
            }
            if users.len() == 1 {
                users.push(resolve_user_id(backend, &active_name, false)?);
            }
            let intersection_type = opt_string(leaf, "type").unwrap_or("followings");
            let mut sets = Vec::new();
            for user_id in users {
                let ids = if intersection_type == "followers" {
                    fetch_relationship_ids_v2(backend, &user_id, "followers")?
                } else {
                    fetch_relationship_ids_v2(backend, &user_id, "following")?
                };
                sets.push(ids.into_iter().collect::<BTreeSet<_>>());
            }
            let mut iter = sets.into_iter();
            let mut intersection = iter.next().unwrap_or_default();
            for set in iter {
                intersection = intersection.intersection(&set).cloned().collect();
            }
            let users =
                lookup_users_by_ids(backend, &intersection.into_iter().collect::<Vec<_>>())?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "blocks" => {
            let me = fetch_current_user(backend)?;
            let me_id = value_id(&me).unwrap_or_default();
            let response = backend.get_json(
                &format!("/2/users/{me_id}/blocking"),
                vec![("user.fields".to_string(), V2_USER_FIELDS.to_string())],
            )?;
            let users = extract_users(&response);
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "muted" => {
            let me = fetch_current_user(backend)?;
            let me_id = value_id(&me).unwrap_or_default();
            let response = backend.get_json(
                &format!("/2/users/{me_id}/muting"),
                vec![("user.fields".to_string(), V2_USER_FIELDS.to_string())],
            )?;
            let users = extract_users(&response);
            print_users(&users, leaf, out);
            Ok(0)
        }
        [single] if single == "lists" => {
            let user = arg_or_active_name(args, &active_name);
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let lists = collect_owned_lists_paginated(backend, &user_id)?;
            print_lists(&lists, leaf, out);
            Ok(0)
        }
        [single] if single == "collections" => {
            let user = arg_or_active_name(args, &active_name);
            let collections = fetch_user_collections(backend, &user, opt_bool(leaf, "id"))?;
            print_collections(&collections, leaf, out);
            Ok(0)
        }
        [single] if single == "trends" => {
            let mut params = vec![("max_trends".to_string(), "50".to_string())];
            if opt_bool(leaf, "exclude-hashtags") {
                params.push((
                    "trend.fields".to_string(),
                    "trend_name,tweet_count".to_string(),
                ));
            }
            let response = backend.get_json_oauth2(
                &format!(
                    "/2/trends/by/woeid/{}",
                    args.first().cloned().unwrap_or_else(|| "1".to_string())
                ),
                params,
            )?;
            for trend in response
                .get("data")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
            {
                if let Some(name) = trend
                    .get("trend_name")
                    .or_else(|| trend.get("name"))
                    .and_then(Value::as_str)
                    && !(opt_bool(leaf, "exclude-hashtags") && name.starts_with('#'))
                {
                    writeln!(out, "{}", name).ok();
                }
            }
            Ok(0)
        }
        [single] if single == "my_location" => {
            let (_lat, _lng, city, region, country) = ip_geolocation()?;
            let parts: Vec<&str> = [city.as_str(), region.as_str(), country.as_str()]
                .into_iter()
                .filter(|s: &&str| !s.is_empty())
                .collect();
            writeln!(out, "{}", parts.join(", ")).ok();
            Ok(0)
        }
        [single] if single == "nearby_places" => {
            let (lat, lng) = resolve_geo_coordinates(args)?;
            let response = backend.get_json(
                "/1.1/geo/reverse_geocode.json",
                vec![
                    ("lat".to_string(), lat.to_string()),
                    ("long".to_string(), lng.to_string()),
                ],
            )?;
            let mut places = extract_geo_places(&response);
            sort_geo_places(&mut places, leaf);
            format_geo_places(&places, leaf, out);
            Ok(0)
        }
        [single] if single == "place" => {
            ensure_min_args(path, args, 1)?;
            let response =
                backend.get_json(&format!("/1.1/geo/id/{}.json", args[0]), Vec::new())?;
            if opt_bool(leaf, "csv") {
                writeln!(out, "{}", csv_row(PLACE_HEADINGS)).ok();
                writeln!(
                    out,
                    "{}",
                    csv_row([
                        response
                            .get("id")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                        response
                            .get("place_type")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                        response
                            .get("full_name")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                        response
                            .get("country")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                    ])
                )
                .ok();
            } else {
                let rows = vec![
                    (
                        "ID",
                        response
                            .get("id")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                    ),
                    (
                        "Type",
                        response
                            .get("place_type")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                    ),
                    (
                        "Name",
                        response
                            .get("full_name")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                    ),
                    (
                        "Country",
                        response
                            .get("country")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                    ),
                ];
                print_key_value_table(&rows, out);
            }
            Ok(0)
        }
        [single] if single == "places" => {
            ensure_min_args(path, args, 1)?;
            let query = &args[0];
            let (lat, lng) = resolve_geo_coordinates(&args[1..])?;
            let response = backend.get_json(
                "/1.1/geo/search.json",
                vec![
                    ("query".to_string(), query.to_string()),
                    ("lat".to_string(), lat.to_string()),
                    ("long".to_string(), lng.to_string()),
                ],
            )?;
            let mut places = extract_geo_places(&response);
            sort_geo_places(&mut places, leaf);
            format_geo_places(&places, leaf, out);
            Ok(0)
        }
        [single] if single == "trend_locations" => {
            let response = backend.get_json_oauth2("/1.1/trends/available.json", Vec::new())?;
            let mut places = extract_places(&response);
            sort_places(&mut places, leaf);
            if opt_bool(leaf, "csv") {
                writeln!(out, "{}", csv_row(TREND_HEADINGS)).ok();
                for place in places {
                    writeln!(
                        out,
                        "{}",
                        csv_row([
                            place
                                .get("woeid")
                                .and_then(value_to_string)
                                .unwrap_or_default(),
                            place
                                .get("parentid")
                                .or_else(|| place.get("parent_id"))
                                .and_then(value_to_string)
                                .unwrap_or_default(),
                            place
                                .get("placeType")
                                .and_then(|place_type| place_type.get("name"))
                                .and_then(value_to_string)
                                .or_else(|| place.get("place_type").and_then(value_to_string))
                                .unwrap_or_default(),
                            place
                                .get("name")
                                .and_then(value_to_string)
                                .unwrap_or_default(),
                            place
                                .get("country")
                                .and_then(value_to_string)
                                .unwrap_or_default(),
                        ])
                    )
                    .ok();
                }
            } else if opt_bool(leaf, "long") {
                let mut rows = Vec::new();
                for place in places {
                    rows.push(vec![
                        place
                            .get("woeid")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                        place
                            .get("parentid")
                            .or_else(|| place.get("parent_id"))
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                        place
                            .get("placeType")
                            .and_then(|place_type| place_type.get("name"))
                            .and_then(value_to_string)
                            .or_else(|| place.get("place_type").and_then(value_to_string))
                            .unwrap_or_default(),
                        place
                            .get("name")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                        place
                            .get("country")
                            .and_then(value_to_string)
                            .unwrap_or_default(),
                    ]);
                }
                print_table(&TREND_HEADINGS, &rows, out);
            } else {
                for place in places {
                    if let Some(name) = place.get("name").and_then(Value::as_str) {
                        writeln!(out, "{}", name).ok();
                    }
                }
            }
            Ok(0)
        }
        [first, second] if first == "delete" && second == "block" => {
            ensure_min_args(path, args, 1)?;
            let me_id = authenticated_user_id(backend)?;
            for user in resolve_user_list(args, opt_bool(leaf, "id")) {
                let target_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
                let _ = backend.delete_json(
                    &format!("/2/users/{me_id}/blocking/{target_id}"),
                    Vec::new(),
                )?;
            }
            writeln!(
                out,
                "@{} unblocked {}.",
                active_name,
                pluralize(args.len(), "user", None)
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "delete" && second == "mute" => {
            ensure_min_args(path, args, 1)?;
            let me_id = authenticated_user_id(backend)?;
            for user in resolve_user_list(args, opt_bool(leaf, "id")) {
                let target_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
                let _ = backend
                    .delete_json(&format!("/2/users/{me_id}/muting/{target_id}"), Vec::new())?;
            }
            writeln!(
                out,
                "@{} unmuted {}.",
                active_name,
                pluralize(args.len(), "user", None)
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "delete" && second == "favorite" => {
            ensure_min_args(path, args, 1)?;
            let me_id = authenticated_user_id(backend)?;
            for id in resolve_id_list(args) {
                let _ = backend.delete_json(&format!("/2/users/{me_id}/likes/{id}"), Vec::new())?;
            }
            Ok(0)
        }
        [first, second] if first == "delete" && second == "status" => {
            ensure_min_args(path, args, 1)?;
            let force = opt_bool(leaf, "force");
            for id in resolve_id_list(args) {
                if force {
                    let _ = backend.delete_json(&format!("/2/tweets/{id}"), Vec::new())?;
                    writeln!(out, "@{active_name} deleted Tweet {id}.").ok();
                } else {
                    let response =
                        backend.get_json_oauth2(&format!("/2/tweets/{id}"), v2_tweet_params())?;
                    let status = extract_tweets(&response)
                        .into_iter()
                        .next()
                        .unwrap_or(response);
                    let screen_name = status
                        .get("user")
                        .and_then(|u| u.get("screen_name"))
                        .and_then(Value::as_str)
                        .unwrap_or("unknown");
                    let text = tweet_text(&status, false);
                    let answer = prompt(
                        out,
                        &format!(
                            "Are you sure you want to permanently delete @{screen_name}'s status: \"{text}\"? [y/N]"
                        ),
                    )?;
                    if !answer.eq_ignore_ascii_case("y") {
                        continue;
                    }
                    let _ = backend.delete_json(&format!("/2/tweets/{id}"), Vec::new())?;
                    writeln!(out, "@{active_name} deleted the Tweet: \"{text}\"").ok();
                }
            }
            Ok(0)
        }
        [first, second] if first == "delete" && second == "dm" => {
            ensure_min_args(path, args, 1)?;
            for id in resolve_id_list(args) {
                let _ = backend.delete_json(&format!("/2/dm_events/{id}"), Vec::new())?;
            }
            Ok(0)
        }
        [first, second] if first == "delete" && second == "collection" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let collection_id =
                resolve_collection_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let _ = post_json_with_retry(
                backend,
                "/1.1/collections/destroy.json",
                vec![("id".to_string(), collection_id)],
            )?;
            writeln!(out, "@{active_name} deleted the collection.").ok();
            Ok(0)
        }
        [first, second] if first == "delete" && second == "list" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id = resolve_list_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let _ = backend.delete_json(&format!("/2/lists/{list_id}"), Vec::new())?;
            Ok(0)
        }
        [first, second] if first == "collection" && second == "create" => {
            ensure_min_args(path, args, 1)?;
            let mut params = vec![("name".to_string(), args[0].clone())];
            if let Some(desc) = args.get(1) {
                params.push(("description".to_string(), desc.clone()));
            }
            if let Some(url) = opt_string(leaf, "url") {
                params.push(("url".to_string(), url.to_string()));
            }
            if let Some(order) = opt_string(leaf, "timeline_order") {
                params.push(("timeline_order".to_string(), order.to_string()));
            }
            let _ = post_json_with_retry(backend, "/1.1/collections/create.json", params)?;
            writeln!(
                out,
                "@{} created the collection \"{}\".",
                active_name, args[0]
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "collection" && second == "add" => {
            ensure_min_args(path, args, 2)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let collection_id =
                resolve_collection_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let tweet_ids = resolve_id_list(&args[1..]);
            for tweet_id in &tweet_ids {
                let _ = post_json_with_retry(
                    backend,
                    "/1.1/collections/entries/add.json",
                    vec![
                        ("id".to_string(), collection_id.clone()),
                        ("tweet_id".to_string(), tweet_id.clone()),
                    ],
                )?;
            }
            writeln!(
                out,
                "@{active_name} added {} to the collection.",
                pluralize(tweet_ids.len(), "tweet", None)
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "collection" && second == "entries" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let collection_id =
                resolve_collection_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = collect_collection_entries(backend, &collection_id, number)?;
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "collection" && second == "information" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let collection_id =
                resolve_collection_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let response = get_json_with_retry(
                backend,
                "/1.1/collections/show.json",
                vec![("id".to_string(), collection_id.clone())],
            )?;
            let collection = extract_collection_metadata(&response, &collection_id);
            print_collection_information(&collection, leaf, out);
            Ok(0)
        }
        [first, second] if first == "collection" && second == "remove" => {
            ensure_min_args(path, args, 2)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let collection_id =
                resolve_collection_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let tweet_ids = resolve_id_list(&args[1..]);
            for tweet_id in &tweet_ids {
                let _ = post_json_with_retry(
                    backend,
                    "/1.1/collections/entries/remove.json",
                    vec![
                        ("id".to_string(), collection_id.clone()),
                        ("tweet_id".to_string(), tweet_id.clone()),
                    ],
                )?;
            }
            writeln!(
                out,
                "@{active_name} removed {} from the collection.",
                pluralize(tweet_ids.len(), "tweet", None)
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "collection" && second == "update" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let collection_id =
                resolve_collection_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let mut params = vec![("id".to_string(), collection_id)];
            if let Some(name) = opt_string(leaf, "name") {
                params.push(("name".to_string(), name.to_string()));
            }
            if let Some(desc) = opt_string(leaf, "description") {
                params.push(("description".to_string(), desc.to_string()));
            }
            if let Some(url) = opt_string(leaf, "url") {
                params.push(("url".to_string(), url.to_string()));
            }
            let _ = post_json_with_retry(backend, "/1.1/collections/update.json", params)?;
            writeln!(out, "@{active_name} updated the collection.").ok();
            Ok(0)
        }
        [first, second] if first == "list" && second == "create" => {
            ensure_min_args(path, args, 1)?;
            let _ = backend.post_json_body(
                "/2/lists",
                serde_json::json!({
                    "name": args[0],
                    "description": args.get(1).cloned().unwrap_or_default(),
                    "private": opt_bool(leaf, "private"),
                }),
            )?;
            writeln!(out, "@{} created the list \"{}\".", active_name, args[0]).ok();
            Ok(0)
        }
        [first, second] if first == "list" && second == "add" => {
            ensure_min_args(path, args, 2)?;
            let list_name = args[0].clone();
            let users = resolve_user_list(&args[1..], opt_bool(leaf, "id"));
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id =
                resolve_list_id(backend, &list_name, opt_bool(leaf, "id"), default_owner)?;
            for user in &users {
                let user_id = resolve_user_id(backend, user, opt_bool(leaf, "id"))?;
                let _ = backend.post_json_body(
                    &format!("/2/lists/{list_id}/members"),
                    serde_json::json!({ "user_id": user_id }),
                )?;
            }
            writeln!(
                out,
                "@{} added {} to the list \"{}\".",
                active_name,
                pluralize(users.len(), "member", None),
                list_name
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "list" && second == "remove" => {
            ensure_min_args(path, args, 2)?;
            let list_name = args[0].clone();
            let users = resolve_user_list(&args[1..], opt_bool(leaf, "id"));
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id =
                resolve_list_id(backend, &list_name, opt_bool(leaf, "id"), default_owner)?;
            for user in &users {
                let user_id = resolve_user_id(backend, user, opt_bool(leaf, "id"))?;
                let _ = backend
                    .delete_json(&format!("/2/lists/{list_id}/members/{user_id}"), Vec::new())?;
            }
            writeln!(
                out,
                "@{} removed {} from the list \"{}\".",
                active_name,
                pluralize(users.len(), "member", None),
                list_name
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "list" && second == "information" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id = resolve_list_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let response = backend.get_json_oauth2(
                &format!("/2/lists/{list_id}"),
                vec![
                    ("list.fields".to_string(), V2_LIST_FIELDS.to_string()),
                    ("expansions".to_string(), "owner_id".to_string()),
                    ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
                ],
            )?;
            let list = extract_lists(&response)
                .into_iter()
                .next()
                .unwrap_or(response);
            print_list_information(&list, leaf, out);
            Ok(0)
        }
        [first, second] if first == "list" && second == "members" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id = resolve_list_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let members = fetch_list_member_ids_v2(backend, &list_id)?;
            let users = lookup_users_by_ids(backend, &members)?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [first, second] if first == "list" && second == "timeline" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id = resolve_list_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = collect_tweets_paginated(
                backend,
                &format!("/2/lists/{list_id}/tweets"),
                timeline_v2_params(leaf),
                AuthScheme::OAuth2Bearer,
                number,
            )?;
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "search" && second == "all" => {
            ensure_min_args(path, args, 1)?;
            let query = args.join(" ");
            let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
            let tweets = collect_tweets_paginated(
                backend,
                "/2/tweets/search/recent",
                [
                    vec![
                        ("query".to_string(), query),
                        ("max_results".to_string(), MAX_SEARCH_RESULTS.to_string()),
                    ],
                    v2_tweet_params(),
                ]
                .concat(),
                AuthScheme::OAuth2Bearer,
                number,
            )?;
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "search" && second == "timeline" => {
            ensure_min_args(path, args, 1)?;
            let query = args.last().cloned().unwrap_or_default();
            let user = if args.len() > 1 {
                Some(args[0].clone())
            } else {
                None
            };
            let params = timeline_v2_params(leaf);
            let tweets = if let Some(user) = user {
                let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
                collect_tweets_paginated(
                    backend,
                    &format!("/2/users/{user_id}/tweets"),
                    params,
                    AuthScheme::OAuth2Bearer,
                    MAX_SEARCH_RESULTS * MAX_PAGE,
                )?
            } else {
                let me = fetch_current_user_with_credentials(backend, active_credentials.as_ref())?;
                let me_id = value_id(&me).unwrap_or_default();
                collect_tweets_paginated(
                    backend,
                    &format!("/2/users/{me_id}/timelines/reverse_chronological"),
                    params,
                    AuthScheme::OAuth1User,
                    MAX_SEARCH_RESULTS * MAX_PAGE,
                )?
            };
            let tweets = filter_tweets_by_query(&tweets, &query);
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "search" && second == "mentions" => {
            ensure_min_args(path, args, 1)?;
            let me = fetch_current_user_with_credentials(backend, active_credentials.as_ref())?;
            let me_id = value_id(&me).unwrap_or_default();
            let tweets = collect_tweets_paginated(
                backend,
                &format!("/2/users/{me_id}/mentions"),
                timeline_v2_params(leaf),
                AuthScheme::OAuth1User,
                MAX_SEARCH_RESULTS * MAX_PAGE,
            )?;
            let tweets = filter_tweets_by_query(&tweets, &args.join(" "));
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "search" && second == "favorites" => {
            ensure_min_args(path, args, 1)?;
            let query = args.last().cloned().unwrap_or_default();
            let user = if args.len() > 1 {
                args[0].clone()
            } else {
                active_name.clone()
            };
            let user_id = resolve_user_id(backend, &user, opt_bool(leaf, "id"))?;
            let tweets = collect_tweets_paginated(
                backend,
                &format!("/2/users/{user_id}/liked_tweets"),
                timeline_v2_params(leaf),
                AuthScheme::OAuth1User,
                MAX_SEARCH_RESULTS * MAX_PAGE,
            )?;
            let tweets = filter_tweets_by_query(&tweets, &query);
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "search" && second == "retweets" => {
            ensure_min_args(path, args, 1)?;
            let query = args.last().cloned().unwrap_or_default();
            let mut tweets = if args.len() > 1 {
                let user_id = resolve_user_id(backend, &args[0], opt_bool(leaf, "id"))?;
                collect_tweets_paginated(
                    backend,
                    &format!("/2/users/{user_id}/tweets"),
                    timeline_v2_params(leaf),
                    AuthScheme::OAuth2Bearer,
                    MAX_SEARCH_RESULTS * MAX_PAGE,
                )?
            } else {
                collect_tweets_paginated(
                    backend,
                    "/2/users/reposts_of_me",
                    timeline_v2_params(leaf),
                    AuthScheme::OAuth1User,
                    MAX_SEARCH_RESULTS * MAX_PAGE,
                )?
            };
            if args.len() > 1 {
                tweets.retain(|tweet| tweet_text(tweet, false).starts_with("RT @"));
            }
            let tweets = filter_tweets_by_query(&tweets, &query);
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "search" && second == "list" => {
            ensure_min_args(path, args, 2)?;
            let query = args[1..].join(" ");
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id = resolve_list_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let tweets = collect_tweets_paginated(
                backend,
                &format!("/2/lists/{list_id}/tweets"),
                v2_tweet_params(),
                AuthScheme::OAuth2Bearer,
                MAX_SEARCH_RESULTS * MAX_PAGE,
            )?;
            let tweets = filter_tweets_by_query(&tweets, &query);
            print_tweets(&tweets, leaf, out, &context.color);
            Ok(0)
        }
        [first, second] if first == "search" && second == "users" => {
            ensure_min_args(path, args, 1)?;
            let users = collect_user_search_pages(backend, &args.join(" "))?;
            print_users(&users, leaf, out);
            Ok(0)
        }
        [first, second] if first == "set" && second == "bio" => {
            ensure_min_args(path, args, 1)?;
            let _ = backend.post_json(
                "/1.1/account/update_profile.json",
                vec![("description".to_string(), args.join(" "))],
            )?;
            writeln!(out, "@{}'s bio has been updated.", active_name).ok();
            Ok(0)
        }
        [first, second] if first == "set" && second == "language" => {
            ensure_min_args(path, args, 1)?;
            let _ = backend.post_json(
                "/1.1/account/settings.json",
                vec![("lang".to_string(), args[0].clone())],
            )?;
            writeln!(out, "@{}'s language has been updated.", active_name).ok();
            Ok(0)
        }
        [first, second] if first == "set" && second == "location" => {
            ensure_min_args(path, args, 1)?;
            let _ = backend.post_json(
                "/1.1/account/update_profile.json",
                vec![("location".to_string(), args.join(" "))],
            )?;
            writeln!(out, "@{}'s location has been updated.", active_name).ok();
            Ok(0)
        }
        [first, second] if first == "set" && second == "name" => {
            ensure_min_args(path, args, 1)?;
            let _ = backend.post_json(
                "/1.1/account/update_profile.json",
                vec![("name".to_string(), args.join(" "))],
            )?;
            writeln!(out, "@{}'s name has been updated.", active_name).ok();
            Ok(0)
        }
        [first, second] if first == "set" && second == "profile_link_color" => {
            ensure_min_args(path, args, 1)?;
            let _ = backend.post_json(
                "/1.1/account/update_profile.json",
                vec![("profile_link_color".to_string(), args[0].clone())],
            )?;
            writeln!(
                out,
                "@{}'s profile link color has been updated.",
                active_name
            )
            .ok();
            Ok(0)
        }
        [first, second] if first == "set" && second == "website" => {
            ensure_min_args(path, args, 1)?;
            let _ = backend.post_json(
                "/1.1/account/update_profile.json",
                vec![("url".to_string(), args[0].clone())],
            )?;
            writeln!(out, "@{}'s website has been updated.", active_name).ok();
            Ok(0)
        }
        [first, second] if first == "set" && second == "profile_image" => {
            ensure_min_args(path, args, 1)?;
            let image_data = load_file_as_base64(&args[0])?;
            let _ = backend.post_json(
                "/1.1/account/update_profile_image.json",
                vec![("image".to_string(), image_data)],
            )?;
            writeln!(out, "@{}'s image has been updated.", active_name).ok();
            Ok(0)
        }
        [first, second] if first == "set" && second == "profile_background_image" => {
            ensure_min_args(path, args, 1)?;
            let image_data = load_file_as_base64(&args[0])?;
            let mut params = vec![
                ("image".to_string(), image_data),
                ("skip_status".to_string(), "true".to_string()),
            ];
            if opt_bool(leaf, "tile") {
                params.push(("tile".to_string(), "true".to_string()));
            }
            let _ =
                backend.post_json("/1.1/account/update_profile_background_image.json", params)?;
            writeln!(out, "@{}'s background image has been updated.", active_name).ok();
            Ok(0)
        }
        [first, second] if first == "stream" && second == "timeline" => {
            let me = fetch_current_user(backend)?;
            let me_id = value_id(&me).unwrap_or_default();
            let ids = fetch_relationship_ids_v2(backend, &me_id, "following")?;
            if ids.is_empty() {
                return Ok(0);
            }
            let queries = ids
                .into_iter()
                .map(|id| format!("from:{id}"))
                .collect::<Vec<_>>();
            stream_filtered_tweets(backend, queries, leaf, out)?;
            Ok(0)
        }
        [first, second] if first == "stream" && second == "all" => {
            stream_tweets(
                backend,
                "/2/tweets/sample/stream",
                v2_stream_params(),
                AuthScheme::OAuth2Bearer,
                leaf,
                out,
            )?;
            Ok(0)
        }
        [first, second] if first == "stream" && second == "search" => {
            ensure_min_args(path, args, 1)?;
            stream_filtered_tweets(backend, args.to_vec(), leaf, out)?;
            Ok(0)
        }
        [first, second] if first == "stream" && second == "matrix" => {
            run_matrix_stream(backend, out)?;
            Ok(0)
        }
        [first, second] if first == "stream" && second == "users" => {
            ensure_min_args(path, args, 1)?;
            let queries = resolve_id_list(args)
                .into_iter()
                .map(|id| format!("from:{id}"))
                .collect::<Vec<_>>();
            stream_filtered_tweets(backend, queries, leaf, out)?;
            Ok(0)
        }
        [first, second] if first == "stream" && second == "list" => {
            ensure_min_args(path, args, 1)?;
            let default_owner = active_profile_name_or_unknown(&rcfile);
            let list_id = resolve_list_id(backend, &args[0], opt_bool(leaf, "id"), default_owner)?;
            let member_ids = fetch_list_member_ids_v2(backend, &list_id)?;
            if member_ids.is_empty() {
                return Ok(0);
            }
            let queries = member_ids
                .into_iter()
                .map(|id| format!("from:{id}"))
                .collect::<Vec<_>>();
            stream_filtered_tweets(backend, queries, leaf, out)?;
            Ok(0)
        }
        _ => {
            writeln!(
                err,
                "Unsupported command path '{}'. If this is a legacy alias, run `x --help` to inspect available commands.",
                path.join(" ")
            )
            .ok();
            Ok(2)
        }
    }
}

fn handle_direct_messages(
    backend: &mut dyn Backend,
    leaf: &ArgMatches,
    out: &mut dyn Write,
    sent: bool,
) -> Result<(), CommandError> {
    let number = opt_usize(leaf, "number").unwrap_or(DEFAULT_NUM_RESULTS);
    let response = fetch_direct_messages_response(backend, number)?;
    let me = fetch_current_user(backend)?;
    let my_id = me
        .get("id_str")
        .or_else(|| me.get("id"))
        .and_then(value_to_string)
        .unwrap_or_default();

    let mut events = extract_dm_events(&response)
        .into_iter()
        .filter(|event| dm_event_type(event) == "messagecreate")
        .filter(|event| {
            let sender = dm_sender_id(event);
            if sent {
                sender == my_id
            } else {
                sender != my_id
            }
        })
        .collect::<Vec<_>>();

    if opt_bool(leaf, "reverse") {
        events.reverse();
    }

    let mut users_by_id = extract_dm_users_by_id(&response);
    let lookup_ids = events
        .iter()
        .map(|event| dm_peer_id(event, &my_id, sent))
        .filter(|id| !id.is_empty() && !users_by_id.contains_key(id))
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();

    if !lookup_ids.is_empty()
        && let Ok(users) = lookup_users_by_ids(backend, &lookup_ids)
    {
        for user in users {
            if let Some(id) = value_id(&user) {
                users_by_id.insert(id, user);
            }
        }
    }

    if opt_bool(leaf, "csv") {
        writeln!(out, "{}", csv_row(DIRECT_MESSAGE_HEADINGS)).ok();
        for event in events {
            let peer_id = dm_peer_id(&event, &my_id, sent);
            let screen_name = users_by_id
                .get(&peer_id)
                .map(dm_user_screen_name)
                .unwrap_or_default();
            let row = vec![
                dm_event_id(&event),
                dm_csv_time(&event),
                screen_name,
                dm_text(&event, opt_bool(leaf, "decode_uris")),
            ];
            writeln!(out, "{}", csv_row(row)).ok();
        }
    } else if opt_bool(leaf, "long") {
        let mut rows = Vec::new();
        for event in events {
            let peer_id = dm_peer_id(&event, &my_id, sent);
            let screen_name = users_by_id
                .get(&peer_id)
                .map(dm_user_screen_name)
                .unwrap_or_default();
            rows.push(vec![
                dm_event_id(&event),
                dm_ls_time(&event, opt_bool(leaf, "relative_dates")),
                format!("@{}", screen_name),
                dm_text(&event, opt_bool(leaf, "decode_uris")).replace('\n', " "),
            ]);
        }
        print_table(&DIRECT_MESSAGE_HEADINGS, &rows, out);
    } else {
        for event in events {
            let peer_id = dm_peer_id(&event, &my_id, sent);
            let screen_name = users_by_id
                .get(&peer_id)
                .map(dm_user_screen_name)
                .unwrap_or_default();
            print_message(
                out,
                &screen_name,
                &dm_text(&event, opt_bool(leaf, "decode_uris")),
            );
        }
    }

    Ok(())
}

fn fetch_direct_messages_response(
    backend: &mut dyn Backend,
    number: usize,
) -> Result<Value, CommandError> {
    let max_results = number.clamp(1, 50).to_string();
    let v2_params = vec![
        ("max_results".to_string(), max_results.clone()),
        ("event_types".to_string(), "MessageCreate".to_string()),
        (
            "dm_event.fields".to_string(),
            "id,sender_id,text,created_at,dm_conversation_id".to_string(),
        ),
        (
            "expansions".to_string(),
            "sender_id,participant_ids".to_string(),
        ),
        ("user.fields".to_string(), "id,username".to_string()),
    ];

    match backend.get_json("/2/dm_events", v2_params) {
        Ok(response) => Ok(response),
        Err(error) if should_fallback_dm_events(&error) => {
            let v1_params = vec![("count".to_string(), max_results)];
            backend
                .get_json("/1.1/direct_messages/events/list.json", v1_params)
                .map_err(CommandError::from)
        }
        Err(error) => Err(CommandError::from(error)),
    }
}

fn should_fallback_dm_events(error: &BackendError) -> bool {
    let BackendError::Http(message) = error else {
        return false;
    };

    message.contains("403") || message.contains("404")
}

fn print_status(status: &Value, leaf: &ArgMatches, out: &mut dyn Write) {
    let posted = tweet_time(status).map(csv_like_time).unwrap_or_default();
    let screen_name = status
        .get("user")
        .and_then(|user| user.get("screen_name"))
        .and_then(Value::as_str)
        .unwrap_or_default();
    let text = tweet_text(status, opt_bool(leaf, "decode_uris"));
    let retweets = status
        .get("retweet_count")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let favorites = status
        .get("favorite_count")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let source = status
        .get("source")
        .and_then(Value::as_str)
        .map(strip_tags)
        .unwrap_or_default();

    if opt_bool(leaf, "csv") {
        let headings = [
            "ID",
            "Posted at",
            "Screen name",
            "Text",
            "Retweets",
            "Favorites",
            "Source",
            "Location",
        ];
        writeln!(out, "{}", csv_row(headings)).ok();
        writeln!(
            out,
            "{}",
            csv_row([
                value_id(status).unwrap_or_default(),
                posted,
                screen_name.to_string(),
                text,
                retweets.to_string(),
                favorites.to_string(),
                source,
                status_location(status),
            ])
        )
        .ok();
    } else if opt_bool(leaf, "long") {
        let headings = [
            "ID",
            "Posted at",
            "Screen name",
            "Text",
            "Retweets",
            "Favorites",
            "Source",
            "Location",
        ];
        let rows = vec![vec![
            value_id(status).unwrap_or_default(),
            ls_like_time(tweet_time(status), opt_bool(leaf, "relative_dates")),
            format!("@{}", screen_name),
            text.replace('\n', " "),
            retweets.to_string(),
            favorites.to_string(),
            source,
            status_location(status),
        ]];
        print_table(&headings, &rows, out);
    } else {
        let posted_with_ago = if let Some(time) = tweet_time(status) {
            format!(
                "{} ({} ago)",
                ls_like_time(Some(time), false),
                distance_of_time_in_words(time, Utc::now())
            )
        } else {
            String::new()
        };
        let mut rows: Vec<(&str, String)> = Vec::new();
        rows.push(("ID", value_id(status).unwrap_or_default()));
        rows.push(("Text", text.replace('\n', " ")));
        rows.push(("Screen name", format!("@{}", screen_name)));
        rows.push(("Posted at", posted_with_ago));
        rows.push(("Retweets", number_with_delimiter(retweets, ',')));
        rows.push(("Favorites", number_with_delimiter(favorites, ',')));
        rows.push(("Source", source));
        let location = status_location(status);
        if !location.is_empty() {
            rows.push(("Location", location));
        }
        print_key_value_table(&rows, out);
    }
}

fn print_whois(user: &Value, leaf: &ArgMatches, out: &mut dyn Write) {
    if opt_bool(leaf, "csv") || opt_bool(leaf, "long") {
        print_users(std::slice::from_ref(user), leaf, out);
        return;
    }

    let since_with_ago = if let Some(time) = user_time(user) {
        format!(
            "{} ({} ago)",
            ls_like_time(Some(time), false),
            distance_of_time_in_words(time, Utc::now())
        )
    } else {
        String::new()
    };

    let verified = user
        .get("verified")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let name_label = if verified { "Name (Verified)" } else { "Name" };

    let mut rows: Vec<(&str, String)> = Vec::new();
    rows.push(("ID", value_id(user).unwrap_or_default()));
    rows.push(("Since", since_with_ago));

    if let Some(status) = user.get("status") {
        let text = tweet_text(status, opt_bool(leaf, "decode_uris")).replace('\n', " ");
        let time_ago = tweet_time(status)
            .map(|t| format!(" ({} ago)", distance_of_time_in_words(t, Utc::now())))
            .unwrap_or_default();
        rows.push(("Last update", format!("{text}{time_ago}")));
    }

    rows.push(("Screen name", format!("@{}", user_screen_name(user))));

    if let Some(name) = user.get("name").and_then(Value::as_str)
        && !name.is_empty()
    {
        rows.push((name_label, name.to_string()));
    }

    rows.push((
        "Tweets",
        number_with_delimiter(
            user.get("statuses_count")
                .and_then(Value::as_i64)
                .unwrap_or(0),
            ',',
        ),
    ));
    rows.push((
        "Favorites",
        number_with_delimiter(
            user.get("favourites_count")
                .or_else(|| user.get("favorites_count"))
                .and_then(Value::as_i64)
                .unwrap_or(0),
            ',',
        ),
    ));
    rows.push((
        "Listed",
        number_with_delimiter(
            user.get("listed_count")
                .and_then(Value::as_i64)
                .unwrap_or(0),
            ',',
        ),
    ));
    rows.push((
        "Following",
        number_with_delimiter(
            user.get("friends_count")
                .and_then(Value::as_i64)
                .unwrap_or(0),
            ',',
        ),
    ));
    rows.push((
        "Followers",
        number_with_delimiter(
            user.get("followers_count")
                .and_then(Value::as_i64)
                .unwrap_or(0),
            ',',
        ),
    ));

    if let Some(description) = user.get("description").and_then(Value::as_str)
        && !description.is_empty()
    {
        rows.push(("Bio", description.replace('\n', " ")));
    }
    if let Some(location) = user.get("location").and_then(Value::as_str)
        && !location.is_empty()
    {
        rows.push(("Location", location.to_string()));
    }
    if let Some(url) = user.get("url").and_then(Value::as_str)
        && !url.is_empty()
    {
        rows.push(("URL", url.to_string()));
    }

    print_key_value_table(&rows, out);
}

fn print_tweets(tweets: &[Value], leaf: &ArgMatches, out: &mut dyn Write, _color: &str) {
    let mut tweets = tweets.to_vec();
    if opt_bool(leaf, "reverse") {
        tweets.reverse();
    }

    if opt_bool(leaf, "csv") {
        if !tweets.is_empty() {
            writeln!(out, "{}", csv_row(TWEET_HEADINGS)).ok();
        }
        for tweet in tweets {
            let row = vec![
                value_id(&tweet).unwrap_or_default(),
                tweet_time(&tweet).map(csv_like_time).unwrap_or_default(),
                user_screen_name(tweet.get("user").unwrap_or(&Value::Null)),
                tweet_text(&tweet, opt_bool(leaf, "decode_uris")),
            ];
            writeln!(out, "{}", csv_row(row)).ok();
        }
        return;
    }

    if opt_bool(leaf, "long") {
        let mut rows = Vec::new();
        for tweet in tweets {
            rows.push(vec![
                value_id(&tweet).unwrap_or_default(),
                ls_like_time(tweet_time(&tweet), opt_bool(leaf, "relative_dates")),
                format!(
                    "@{}",
                    user_screen_name(tweet.get("user").unwrap_or(&Value::Null))
                ),
                tweet_text(&tweet, opt_bool(leaf, "decode_uris")).replace('\n', " "),
            ]);
        }
        print_table(&TWEET_HEADINGS, &rows, out);
        return;
    }

    for tweet in tweets {
        let user = user_screen_name(tweet.get("user").unwrap_or(&Value::Null));
        print_message(
            out,
            &user,
            &tweet_text(&tweet, opt_bool(leaf, "decode_uris")),
        );
    }
}

fn print_users(users: &[Value], leaf: &ArgMatches, out: &mut dyn Write) {
    let mut users = users.to_vec();
    if !opt_bool(leaf, "unsorted") {
        let sort = opt_string(leaf, "sort").unwrap_or("screen_name");
        match sort {
            "favorites" => users.sort_by_key(|user| {
                user.get("favourites_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            "followers" => users.sort_by_key(|user| {
                user.get("followers_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            "friends" => users.sort_by_key(|user| {
                user.get("friends_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            "listed" => users.sort_by_key(|user| {
                user.get("listed_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            "since" => users.sort_by_key(user_time),
            "tweets" => users.sort_by_key(|user| {
                user.get("statuses_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            "tweeted" => users.sort_by_key(|user| {
                user.get("status").and_then(tweet_time).unwrap_or_else(|| {
                    DateTime::<Utc>::from_timestamp(0, 0).unwrap_or_else(Utc::now)
                })
            }),
            _ => users.sort_by_key(|user| user_screen_name(user).to_ascii_lowercase()),
        }
    }

    if opt_bool(leaf, "reverse") {
        users.reverse();
    }

    if opt_bool(leaf, "csv") {
        if !users.is_empty() {
            writeln!(out, "{}", csv_row(USER_HEADINGS)).ok();
        }
        for user in users {
            let status = user.get("status").cloned().unwrap_or(Value::Null);
            let row = vec![
                value_id(&user).unwrap_or_default(),
                user_time(&user).map(csv_like_time).unwrap_or_default(),
                tweet_time(&status).map(csv_like_time).unwrap_or_default(),
                user.get("statuses_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("favourites_count")
                    .or_else(|| user.get("favorites_count"))
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("listed_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("friends_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("followers_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user_screen_name(&user),
                user.get("name")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                bool_to_yes_no(user.get("verified").and_then(Value::as_bool)),
                bool_to_yes_no(user.get("protected").and_then(Value::as_bool)),
                user.get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                status
                    .get("full_text")
                    .or_else(|| status.get("text"))
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("location")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("url")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ];
            writeln!(out, "{}", csv_row(row)).ok();
        }
        return;
    }

    if opt_bool(leaf, "long") {
        let mut rows = Vec::new();
        for user in users {
            let status = user.get("status").cloned().unwrap_or(Value::Null);
            rows.push(vec![
                value_id(&user).unwrap_or_default(),
                ls_like_time(user_time(&user), opt_bool(leaf, "relative_dates")),
                ls_like_time(tweet_time(&status), opt_bool(leaf, "relative_dates")),
                user.get("statuses_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("favourites_count")
                    .or_else(|| user.get("favorites_count"))
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("listed_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("friends_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("followers_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                format!("@{}", user_screen_name(&user)),
                user.get("name")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                bool_to_yes_no(user.get("verified").and_then(Value::as_bool)),
                bool_to_yes_no(user.get("protected").and_then(Value::as_bool)),
                user.get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                tweet_text(&status, opt_bool(leaf, "decode_uris")).replace('\n', " "),
                user.get("location")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user.get("url")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ]);
        }
        print_table(&USER_HEADINGS, &rows, out);
        return;
    }

    for user in users {
        writeln!(out, "{}", user_screen_name(&user)).ok();
    }
}

fn print_lists(lists: &[Value], leaf: &ArgMatches, out: &mut dyn Write) {
    let mut lists = lists.to_vec();
    if !opt_bool(leaf, "unsorted") {
        let sort = opt_string(leaf, "sort").unwrap_or("slug");
        match sort {
            "members" => lists.sort_by_key(|list| {
                list.get("member_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            "mode" => lists.sort_by_key(|list| {
                list.get("mode")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string()
            }),
            "since" => lists.sort_by_key(list_time),
            "subscribers" => lists.sort_by_key(|list| {
                list.get("subscriber_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            _ => lists.sort_by_key(|list| {
                list.get("slug")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
        }
    }
    if opt_bool(leaf, "reverse") {
        lists.reverse();
    }

    if opt_bool(leaf, "csv") {
        if !lists.is_empty() {
            writeln!(out, "{}", csv_row(LIST_HEADINGS)).ok();
        }
        for list in lists {
            let row = vec![
                value_id(&list).unwrap_or_default(),
                list_time(&list).map(csv_like_time).unwrap_or_default(),
                user_screen_name(list.get("user").unwrap_or(&Value::Null)),
                list.get("slug")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("member_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("subscriber_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("mode")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ];
            writeln!(out, "{}", csv_row(row)).ok();
        }
        return;
    }

    if opt_bool(leaf, "long") {
        let mut rows = Vec::new();
        for list in lists {
            rows.push(vec![
                value_id(&list).unwrap_or_default(),
                ls_like_time(list_time(&list), opt_bool(leaf, "relative_dates")),
                format!(
                    "@{}",
                    user_screen_name(list.get("user").unwrap_or(&Value::Null))
                ),
                list.get("slug")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("member_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("subscriber_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("mode")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ]);
        }
        print_table(&LIST_HEADINGS, &rows, out);
        return;
    }

    for list in lists {
        let full_name = list
            .get("full_name")
            .and_then(Value::as_str)
            .map(ToString::to_string)
            .unwrap_or_else(|| {
                format!(
                    "@{}/{}",
                    user_screen_name(list.get("user").unwrap_or(&Value::Null)),
                    list.get("slug").and_then(Value::as_str).unwrap_or_default()
                )
            });
        writeln!(out, "{}", full_name).ok();
    }
}

fn print_list_information(list: &Value, leaf: &ArgMatches, out: &mut dyn Write) {
    if opt_bool(leaf, "csv") {
        let headings = [
            "ID",
            "Description",
            "Slug",
            "Screen name",
            "Created at",
            "Members",
            "Subscribers",
            "Following",
            "Mode",
            "URL",
        ];
        writeln!(out, "{}", csv_row(headings)).ok();
        writeln!(
            out,
            "{}",
            csv_row([
                value_id(list).unwrap_or_default(),
                list.get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("slug")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                user_screen_name(list.get("user").unwrap_or(&Value::Null)),
                list_time(list).map(csv_like_time).unwrap_or_default(),
                list.get("member_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("subscriber_count")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                bool_to_yes_no(list.get("following").and_then(Value::as_bool)),
                list.get("mode")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                list.get("uri")
                    .or_else(|| list.get("url"))
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ])
        )
        .ok();
        return;
    }

    let rows = [
        ("ID", value_id(list).unwrap_or_default()),
        (
            "Description",
            list.get("description")
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
        (
            "Slug",
            list.get("slug")
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
        (
            "Screen name",
            format!(
                "@{}",
                user_screen_name(list.get("user").unwrap_or(&Value::Null))
            ),
        ),
        (
            "Created at",
            ls_like_time(list_time(list), opt_bool(leaf, "relative_dates")),
        ),
        (
            "Members",
            number_with_delimiter(
                list.get("member_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0),
                ',',
            ),
        ),
        (
            "Subscribers",
            number_with_delimiter(
                list.get("subscriber_count")
                    .and_then(Value::as_i64)
                    .unwrap_or(0),
                ',',
            ),
        ),
        (
            "Status",
            if list
                .get("following")
                .and_then(Value::as_bool)
                .unwrap_or(false)
            {
                "Following".to_string()
            } else {
                "Not following".to_string()
            },
        ),
        (
            "Mode",
            list.get("mode")
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
        (
            "URL",
            list.get("uri")
                .or_else(|| list.get("url"))
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
    ];

    for (key, value) in rows {
        if !value.is_empty() {
            writeln!(out, "{key}: {value}").ok();
        }
    }
}

fn print_collections(collections: &[Value], leaf: &ArgMatches, out: &mut dyn Write) {
    let mut collections = collections.to_vec();
    if !opt_bool(leaf, "unsorted") {
        let sort = opt_string(leaf, "sort").unwrap_or("name");
        match sort {
            "since" => collections.sort_by_key(|c| {
                c.get("created_at")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string()
            }),
            _ => collections.sort_by_key(|c| {
                c.get("name")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
        }
    }
    if opt_bool(leaf, "reverse") {
        collections.reverse();
    }

    if opt_bool(leaf, "csv") {
        if !collections.is_empty() {
            writeln!(out, "{}", csv_row(COLLECTION_HEADINGS)).ok();
        }
        for c in collections {
            let row = vec![
                value_id(&c).unwrap_or_default(),
                c.get("name").and_then(value_to_string).unwrap_or_default(),
                c.get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                c.get("collection_url")
                    .or_else(|| c.get("url"))
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ];
            writeln!(out, "{}", csv_row(row)).ok();
        }
        return;
    }

    if opt_bool(leaf, "long") {
        let mut rows = Vec::new();
        for c in collections {
            rows.push(vec![
                value_id(&c).unwrap_or_default(),
                c.get("name").and_then(value_to_string).unwrap_or_default(),
                c.get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                c.get("collection_url")
                    .or_else(|| c.get("url"))
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ]);
        }
        print_table(&COLLECTION_HEADINGS, &rows, out);
        return;
    }

    for c in collections {
        let name = c.get("name").and_then(Value::as_str).unwrap_or_default();
        let id = value_id(&c).unwrap_or_default();
        writeln!(out, "{name} ({id})").ok();
    }
}

fn print_collection_information(collection: &Value, leaf: &ArgMatches, out: &mut dyn Write) {
    if opt_bool(leaf, "csv") {
        let headings = [
            "ID",
            "Name",
            "Description",
            "URL",
            "Timeline order",
            "Visibility",
        ];
        writeln!(out, "{}", csv_row(headings)).ok();
        writeln!(
            out,
            "{}",
            csv_row([
                value_id(collection).unwrap_or_default(),
                collection
                    .get("name")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                collection
                    .get("description")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                collection
                    .get("collection_url")
                    .or_else(|| collection.get("url"))
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                collection
                    .get("timeline_order")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                collection
                    .get("visibility")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ])
        )
        .ok();
        return;
    }

    let rows = [
        ("ID", value_id(collection).unwrap_or_default()),
        (
            "Name",
            collection
                .get("name")
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
        (
            "Description",
            collection
                .get("description")
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
        (
            "URL",
            collection
                .get("collection_url")
                .or_else(|| collection.get("url"))
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
        (
            "Timeline order",
            collection
                .get("timeline_order")
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
        (
            "Visibility",
            collection
                .get("visibility")
                .and_then(value_to_string)
                .unwrap_or_default(),
        ),
    ];

    for (key, value) in rows {
        if !value.is_empty() {
            writeln!(out, "{key}: {value}").ok();
        }
    }
}

fn print_message(out: &mut dyn Write, from_user: &str, message: &str) {
    writeln!(out, "   @{}", from_user).ok();
    for line in wrap_text(message, 77) {
        writeln!(out, "   {}", line).ok();
    }
    writeln!(out).ok();
}

fn run_authorize(
    leaf: &ArgMatches,
    profile_path: &std::path::Path,
    existing_credentials: Option<&Credentials>,
    out: &mut dyn Write,
    err: &mut dyn Write,
) -> Result<(), CommandError> {
    if opt_bool(leaf, "oauth2") {
        return run_authorize_oauth2(
            profile_path,
            existing_credentials,
            opt_bool(leaf, "display-uri"),
            out,
            err,
        );
    }

    let mut rcfile = RcFile::load(profile_path)?;
    let display_uri = opt_bool(leaf, "display-uri");

    if rcfile.profiles().is_empty() {
        writeln!(
            out,
            "Welcome! Before you can use t, you'll first need to register an"
        )?;
        writeln!(
            out,
            "application with Twitter. Just follow the steps below:"
        )?;
        writeln!(
            out,
            "  1. Sign in to the Twitter Developer site and create an app."
        )?;
        writeln!(out, "  2. Set your app permissions to read and write.")?;
        writeln!(
            out,
            "  3. Copy your API key and API secret and paste them below."
        )?;
    } else {
        writeln!(
            out,
            "It looks like you've already registered an application with Twitter."
        )?;
        writeln!(
            out,
            "To authorize a new account, follow the same app-key flow."
        )?;
    }

    writeln!(out)?;
    prompt(out, "Press [Enter] to open the Twitter Developer site.")?;
    writeln!(out)?;
    open_or_print(
        "https://developer.twitter.com/en/portal/projects-and-apps",
        display_uri,
        out,
        err,
    );

    let key = std::env::var("T_AUTHORIZE_API_KEY")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or(prompt(out, "Enter your API key:")?);
    let secret = std::env::var("T_AUTHORIZE_API_SECRET")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or(prompt(out, "Enter your API secret:")?);

    let (request_token, request_secret) = oauth_request_token(&key, &secret)?;
    let authorize_uri = format!(
        "https://api.twitter.com/oauth/authorize?oauth_token={}",
        oauth1::percent_encode(&request_token)
    );

    writeln!(out)?;
    writeln!(
        out,
        "In a moment, you will be directed to the Twitter app authorization page."
    )?;
    writeln!(out, "Sign in, authorize the app, and copy the PIN.")?;
    writeln!(out)?;
    prompt(
        out,
        "Press [Enter] to open the Twitter app authorization page.",
    )?;
    writeln!(out)?;
    open_or_print(&authorize_uri, display_uri, out, err);

    let pin = std::env::var("T_AUTHORIZE_PIN")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or(prompt(out, "Enter the supplied PIN:")?);

    let (access_token, access_secret, screen_name_hint) =
        oauth_access_token(&key, &secret, &request_token, &request_secret, &pin)?;
    let screen_name = oauth_verify_screen_name(&key, &secret, &access_token, &access_secret)
        .or(screen_name_hint)
        .unwrap_or_else(|| "authorized_user".to_string());

    let credentials = Credentials {
        username: screen_name.clone(),
        consumer_key: key.clone(),
        consumer_secret: secret.clone(),
        token: access_token,
        secret: access_secret,
        bearer_token: None,
        oauth2_user: None,
    };
    rcfile.upsert_profile_credentials(&screen_name, &key, credentials);
    let _ = rcfile.set_active(&screen_name, Some(&key))?;
    rcfile.save(profile_path)?;

    writeln!(out, "Authorization successful.")?;
    Ok(())
}

fn oauth_request_token(key: &str, secret: &str) -> Result<(String, String), CommandError> {
    let consumer = Token::new(key, secret);
    let mut params = ParamList::new();
    params.insert("oauth_callback".into(), "oob".into());

    let body = oauth1::post(
        "https://api.twitter.com/oauth/request_token",
        &consumer,
        None,
        Some(&params),
    )
    .map_err(|error| CommandError::Backend(BackendError::Http(error)))?;

    let map: HashMap<String, String> = serde_urlencoded::from_str(&body)
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;

    let token = map
        .get("oauth_token")
        .filter(|value| !value.is_empty())
        .cloned()
        .ok_or_else(|| {
            CommandError::Backend(BackendError::Http(
                "oauth_token missing from request token response".to_string(),
            ))
        })?;
    let token_secret = map
        .get("oauth_token_secret")
        .filter(|value| !value.is_empty())
        .cloned()
        .ok_or_else(|| {
            CommandError::Backend(BackendError::Http(
                "oauth_token_secret missing from request token response".to_string(),
            ))
        })?;

    Ok((token, token_secret))
}

fn oauth_access_token(
    key: &str,
    secret: &str,
    request_token: &str,
    request_secret: &str,
    pin: &str,
) -> Result<(String, String, Option<String>), CommandError> {
    let consumer = Token::new(key, secret);
    let request = Token::new(request_token, request_secret);
    let mut params = ParamList::new();
    params.insert("oauth_verifier".into(), pin.trim().into());

    let body = oauth1::post(
        "https://api.twitter.com/oauth/access_token",
        &consumer,
        Some(&request),
        Some(&params),
    )
    .map_err(|error| CommandError::Backend(BackendError::Http(error)))?;

    let map: HashMap<String, String> = serde_urlencoded::from_str(&body)
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;

    let token = map
        .get("oauth_token")
        .filter(|value| !value.is_empty())
        .cloned()
        .ok_or_else(|| {
            CommandError::Backend(BackendError::Http(
                "oauth_token missing from access token response".to_string(),
            ))
        })?;
    let token_secret = map
        .get("oauth_token_secret")
        .filter(|value| !value.is_empty())
        .cloned()
        .ok_or_else(|| {
            CommandError::Backend(BackendError::Http(
                "oauth_token_secret missing from access token response".to_string(),
            ))
        })?;
    let screen_name = map
        .get("screen_name")
        .filter(|value| !value.is_empty())
        .cloned();

    Ok((token, token_secret, screen_name))
}

fn oauth_verify_screen_name(
    key: &str,
    secret: &str,
    token: &str,
    token_secret: &str,
) -> Option<String> {
    let consumer = Token::new(key, secret);
    let access = Token::new(token, token_secret);
    let mut params = ParamList::new();
    params.insert("user.fields".into(), "username".into());
    let body = oauth1::get(
        "https://api.twitter.com/2/users/me",
        &consumer,
        Some(&access),
        Some(&params),
    )
    .ok()?;

    let payload = serde_json::from_str::<Value>(&body).ok()?;
    payload
        .get("data")
        .and_then(|data| {
            data.get("username")
                .or_else(|| data.get("screen_name"))
                .and_then(Value::as_str)
        })
        .map(ToString::to_string)
}

fn run_authorize_oauth2(
    profile_path: &std::path::Path,
    existing_credentials: Option<&Credentials>,
    display_uri: bool,
    out: &mut dyn Write,
    err: &mut dyn Write,
) -> Result<(), CommandError> {
    let mut rcfile = RcFile::load(profile_path)?;

    writeln!(
        out,
        "OAuth 2.0 user-context authorization is required for bookmarks."
    )?;
    writeln!(
        out,
        "Configure your X app with OAuth 2.0 enabled and an exact callback URL match."
    )?;
    writeln!(
        out,
        "Recommended scopes: {}",
        OAUTH2_DEFAULT_SCOPES.join(" ")
    )?;
    writeln!(out)?;
    prompt(out, "Press [Enter] to open the X Developer site.")?;
    writeln!(out)?;
    open_or_print(
        "https://developer.twitter.com/en/portal/projects-and-apps",
        display_uri,
        out,
        err,
    );

    let client_id = env_first(&[
        "X_AUTHORIZE_OAUTH2_CLIENT_ID",
        "T_AUTHORIZE_OAUTH2_CLIENT_ID",
    ])
    .unwrap_or(prompt(out, "Enter your OAuth2 client ID:")?);
    let client_secret = env_first(&[
        "X_AUTHORIZE_OAUTH2_CLIENT_SECRET",
        "T_AUTHORIZE_OAUTH2_CLIENT_SECRET",
    ])
    .or({
        let entered = prompt(
            out,
            "Enter your OAuth2 client secret (press Enter for public clients):",
        )?;
        if entered.trim().is_empty() {
            None
        } else {
            Some(entered)
        }
    });
    let redirect_uri = env_first(&[
        "X_AUTHORIZE_OAUTH2_REDIRECT_URI",
        "T_AUTHORIZE_OAUTH2_REDIRECT_URI",
    ])
    .unwrap_or(prompt_with_default(
        out,
        "Enter your OAuth2 redirect URI:",
        DEFAULT_OAUTH2_REDIRECT_URI,
    )?);
    let scopes = oauth2_scopes();

    let state = random_urlsafe_token(24)?;
    let code_verifier = random_urlsafe_token(48)?;
    let authorize_uri =
        build_oauth2_authorize_uri(&client_id, &redirect_uri, &scopes, &state, &code_verifier)?;

    writeln!(out)?;
    writeln!(
        out,
        "Open the authorization page, sign in, and approve the app."
    )?;
    writeln!(
        out,
        "After X redirects to your callback URL, copy the full URL from the browser and paste it below."
    )?;
    writeln!(out)?;
    prompt(
        out,
        "Press [Enter] to open the OAuth 2.0 authorization page.",
    )?;
    writeln!(out)?;
    open_or_print(&authorize_uri, display_uri, out, err);

    let redirected_input = env_first(&[
        "X_AUTHORIZE_OAUTH2_REDIRECTED_URL",
        "T_AUTHORIZE_OAUTH2_REDIRECTED_URL",
    ])
    .unwrap_or(prompt(
        out,
        "Paste the full redirected URL, or just the code value:",
    )?);
    let (code, returned_state) = parse_oauth2_redirect_input(&redirected_input)?;
    if let Some(returned_state) = returned_state
        && returned_state != state
    {
        return Err(CommandError::Other(
            "OAuth2 state mismatch; authorization response could not be verified".to_string(),
        ));
    }

    let oauth2_user = oauth2_exchange_authorization_code(
        &client_id,
        client_secret.as_deref(),
        &redirect_uri,
        &code,
        &code_verifier,
        &scopes,
    )?;
    let screen_name = oauth2_fetch_screen_name(&oauth2_user.access_token)?;

    let storage_key = existing_credentials
        .filter(|credentials| credentials.username.eq_ignore_ascii_case(&screen_name))
        .map(|credentials| credentials.consumer_key.clone())
        .filter(|key| !key.trim().is_empty())
        .unwrap_or_else(|| client_id.clone());

    let mut credentials = existing_credentials
        .filter(|credentials| credentials.username.eq_ignore_ascii_case(&screen_name))
        .cloned()
        .unwrap_or_else(|| Credentials {
            username: screen_name.clone(),
            consumer_key: storage_key.clone(),
            consumer_secret: String::new(),
            token: String::new(),
            secret: String::new(),
            bearer_token: None,
            oauth2_user: None,
        });
    credentials.username = screen_name.clone();
    if credentials.consumer_key.trim().is_empty() {
        credentials.consumer_key = storage_key.clone();
    }
    credentials.oauth2_user = Some(oauth2_user);

    rcfile.upsert_profile_credentials(&screen_name, &storage_key, credentials);
    let _ = rcfile.set_active(&screen_name, Some(&storage_key))?;
    rcfile.save(profile_path)?;

    writeln!(out, "OAuth2 authorization successful.")?;
    Ok(())
}

fn env_first(names: &[&str]) -> Option<String> {
    names.iter().find_map(|name| {
        std::env::var(name)
            .ok()
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty())
    })
}

fn prompt_with_default(
    out: &mut dyn Write,
    label: &str,
    default: &str,
) -> Result<String, io::Error> {
    let value = prompt(out, &format!("{label} [{default}]"))?;
    if value.trim().is_empty() {
        Ok(default.to_string())
    } else {
        Ok(value)
    }
}

fn oauth2_scopes() -> Vec<String> {
    let mut scopes = env_first(&["X_AUTHORIZE_OAUTH2_SCOPES", "T_AUTHORIZE_OAUTH2_SCOPES"])
        .map(|value| {
            value
                .split(|ch: char| ch.is_whitespace() || ch == ',')
                .filter(|scope| !scope.is_empty())
                .map(ToString::to_string)
                .collect::<Vec<_>>()
        })
        .unwrap_or_else(|| {
            OAUTH2_DEFAULT_SCOPES
                .iter()
                .map(|scope| (*scope).to_string())
                .collect()
        });

    for required in [
        "tweet.read",
        "users.read",
        "bookmark.read",
        "bookmark.write",
    ] {
        ensure_scope(&mut scopes, required);
    }

    scopes
}

fn ensure_scope(scopes: &mut Vec<String>, scope: &str) {
    if !scopes.iter().any(|candidate| candidate == scope) {
        scopes.push(scope.to_string());
    }
}

fn random_urlsafe_token(len: usize) -> Result<String, CommandError> {
    let rng = SystemRandom::new();
    let mut bytes = vec![0u8; len];
    rng.fill(&mut bytes)
        .map_err(|_| CommandError::Other("Failed to generate secure random bytes".to_string()))?;
    Ok(base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes))
}

fn pkce_s256_challenge(code_verifier: &str) -> String {
    let hash = digest(&SHA256, code_verifier.as_bytes());
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(hash.as_ref())
}

fn build_oauth2_authorize_uri(
    client_id: &str,
    redirect_uri: &str,
    scopes: &[String],
    state: &str,
    code_verifier: &str,
) -> Result<String, CommandError> {
    let mut url = Url::parse("https://x.com/i/oauth2/authorize")
        .map_err(|error| CommandError::Other(error.to_string()))?;
    let code_challenge = pkce_s256_challenge(code_verifier);
    url.query_pairs_mut()
        .append_pair("response_type", "code")
        .append_pair("client_id", client_id)
        .append_pair("redirect_uri", redirect_uri)
        .append_pair("scope", &scopes.join(" "))
        .append_pair("state", state)
        .append_pair("code_challenge", &code_challenge)
        .append_pair("code_challenge_method", "S256");
    Ok(url.to_string())
}

fn parse_oauth2_redirect_input(input: &str) -> Result<(String, Option<String>), CommandError> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return Err(CommandError::Other(
            "OAuth2 authorization response was empty".to_string(),
        ));
    }

    if let Ok(url) = Url::parse(trimmed) {
        let query = url.query_pairs().collect::<HashMap<_, _>>();
        if let Some(error) = query.get("error") {
            let description = query
                .get("error_description")
                .map(|value| format!(": {value}"))
                .unwrap_or_default();
            return Err(CommandError::Other(format!(
                "OAuth2 authorization failed with {error}{description}"
            )));
        }

        let code = query
            .get("code")
            .map(|value| value.to_string())
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                CommandError::Other(
                    "OAuth2 redirect URL did not contain a code parameter".to_string(),
                )
            })?;
        let state = query.get("state").map(|value| value.to_string());
        return Ok((code, state));
    }

    Ok((trimmed.to_string(), None))
}

fn oauth2_exchange_authorization_code(
    client_id: &str,
    client_secret: Option<&str>,
    redirect_uri: &str,
    code: &str,
    code_verifier: &str,
    requested_scopes: &[String],
) -> Result<OAuth2UserContext, CommandError> {
    let client = reqwest::blocking::Client::builder()
        .user_agent("x-rust/5.0")
        .build()
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;

    let mut request = client
        .post("https://api.x.com/2/oauth2/token")
        .header("Content-Type", "application/x-www-form-urlencoded");
    let mut form = vec![
        ("code".to_string(), code.to_string()),
        ("grant_type".to_string(), "authorization_code".to_string()),
        ("redirect_uri".to_string(), redirect_uri.to_string()),
        ("code_verifier".to_string(), code_verifier.to_string()),
    ];

    match client_secret.filter(|value| !value.trim().is_empty()) {
        Some(client_secret) => {
            let basic = base64::engine::general_purpose::STANDARD
                .encode(format!("{client_id}:{client_secret}").as_bytes());
            request = request.header("Authorization", format!("Basic {basic}"));
        }
        None => form.push(("client_id".to_string(), client_id.to_string())),
    }

    let response = request
        .form(&form)
        .send()
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;
    let status = response.status();
    let body = response
        .text()
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;
    if !status.is_success() {
        return Err(CommandError::Backend(BackendError::Http(format_api_error(
            status, &body,
        ))));
    }

    let payload: Value = serde_json::from_str(&body).map_err(BackendError::from)?;
    let access_token = payload
        .get("access_token")
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| {
            CommandError::Other("OAuth2 token response did not include access_token".to_string())
        })?
        .to_string();
    let refresh_token = payload
        .get("refresh_token")
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .map(ToString::to_string);
    let expires_at = payload
        .get("expires_in")
        .and_then(Value::as_i64)
        .map(|seconds| {
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|duration| duration.as_secs() as i64 + seconds)
                .unwrap_or(seconds)
        });
    let scopes = payload
        .get("scope")
        .and_then(Value::as_str)
        .map(|value| {
            value
                .split_whitespace()
                .filter(|scope| !scope.is_empty())
                .map(ToString::to_string)
                .collect::<Vec<_>>()
        })
        .unwrap_or_else(|| requested_scopes.to_vec());

    Ok(OAuth2UserContext {
        client_id: client_id.to_string(),
        client_secret: client_secret.map(ToString::to_string),
        access_token,
        refresh_token,
        expires_at,
        scopes,
    })
}

fn oauth2_fetch_screen_name(access_token: &str) -> Result<String, CommandError> {
    let client = reqwest::blocking::Client::builder()
        .user_agent("x-rust/5.0")
        .build()
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;
    let response = client
        .get("https://api.x.com/2/users/me?user.fields=username")
        .bearer_auth(access_token)
        .send()
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;
    let status = response.status();
    let body = response
        .text()
        .map_err(|error| CommandError::Backend(BackendError::Http(error.to_string())))?;
    if !status.is_success() {
        return Err(CommandError::Backend(BackendError::Http(format_api_error(
            status, &body,
        ))));
    }

    let payload: Value = serde_json::from_str(&body).map_err(BackendError::from)?;
    payload
        .get("data")
        .and_then(|data| data.get("username"))
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .ok_or_else(|| {
            CommandError::Other("OAuth2 /2/users/me response did not include username".to_string())
        })
}

fn prompt(out: &mut dyn Write, label: &str) -> Result<String, io::Error> {
    write!(out, "{} ", label)?;
    out.flush()?;
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(input.trim_end_matches(['\r', '\n']).to_string())
}

fn open_or_print(uri: &str, dry_run: bool, out: &mut dyn Write, err: &mut dyn Write) {
    if dry_run {
        let _ = writeln!(out, "Open: {}", uri);
        return;
    }

    if open_in_browser(uri).is_err() {
        let _ = writeln!(err, "Open: {}", uri);
    }
}

fn open_in_browser(uri: &str) -> Result<(), io::Error> {
    #[cfg(target_os = "macos")]
    let mut cmd = {
        let mut cmd = Command::new("open");
        cmd.arg(uri);
        cmd
    };

    #[cfg(all(unix, not(target_os = "macos")))]
    let mut cmd = {
        let mut cmd = Command::new("xdg-open");
        cmd.arg(uri);
        cmd
    };

    #[cfg(windows)]
    let mut cmd = {
        let mut cmd = Command::new("cmd");
        cmd.args(["/C", "start", "", uri]);
        cmd
    };

    let status = cmd.status()?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::other("browser opener command returned non-zero"))
    }
}

fn stream_tweets(
    backend: &mut dyn Backend,
    path: &str,
    params: Vec<(String, String)>,
    auth: AuthScheme,
    leaf: &ArgMatches,
    out: &mut dyn Write,
) -> Result<(), CommandError> {
    print_stream_headings(leaf, out);
    let max_events = stream_max_events();
    let mut seen = 0usize;

    backend.stream_json_lines(path, params, auth, &mut |event| {
        let Some(tweet) = tweet_from_stream_event(event) else {
            return true;
        };

        print_stream_tweet(&tweet, leaf, out);
        out.flush().ok();
        seen += 1;
        max_events.map(|max| seen < max).unwrap_or(true)
    })?;

    Ok(())
}

fn print_stream_headings(leaf: &ArgMatches, out: &mut dyn Write) {
    if opt_bool(leaf, "csv") {
        writeln!(out, "{}", csv_row(TWEET_HEADINGS)).ok();
    } else if opt_bool(leaf, "long") {
        writeln!(
            out,
            "{:<18}  {:<12}  {:<20}  {}",
            TWEET_HEADINGS[0], TWEET_HEADINGS[1], TWEET_HEADINGS[2], TWEET_HEADINGS[3]
        )
        .ok();
    }
}

fn print_stream_tweet(tweet: &Value, leaf: &ArgMatches, out: &mut dyn Write) {
    if opt_bool(leaf, "csv") {
        let row = vec![
            value_id(tweet).unwrap_or_default(),
            tweet_time(tweet).map(csv_like_time).unwrap_or_default(),
            user_screen_name(tweet.get("user").unwrap_or(&Value::Null)),
            tweet_text(tweet, opt_bool(leaf, "decode_uris")),
        ];
        writeln!(out, "{}", csv_row(row)).ok();
    } else if opt_bool(leaf, "long") {
        writeln!(
            out,
            "{:<18}  {:<12}  {:<20}  {}",
            value_id(tweet).unwrap_or_default(),
            ls_like_time(tweet_time(tweet), opt_bool(leaf, "relative_dates")),
            format!(
                "@{}",
                user_screen_name(tweet.get("user").unwrap_or(&Value::Null))
            ),
            tweet_text(tweet, opt_bool(leaf, "decode_uris")).replace('\n', " ")
        )
        .ok();
    } else {
        let user = user_screen_name(tweet.get("user").unwrap_or(&Value::Null));
        print_message(
            out,
            &user,
            &tweet_text(tweet, opt_bool(leaf, "decode_uris")),
        );
    }
}

fn tweet_from_stream_event(event: Value) -> Option<Value> {
    if event.get("text").is_some() {
        return Some(event);
    }

    let data = event.get("data")?;
    let mut text = data.get("text").and_then(Value::as_str)?.to_string();
    let id = data
        .get("id")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let author_id = data
        .get("author_id")
        .and_then(Value::as_str)
        .unwrap_or("unknown")
        .to_string();

    let find_user_name = |uid: &str| -> Option<String> {
        event
            .get("includes")
            .and_then(|includes| includes.get("users"))
            .and_then(Value::as_array)
            .and_then(|users| {
                users.iter().find_map(|user| {
                    if user.get("id").and_then(Value::as_str) == Some(uid) {
                        user.get("username")
                            .or_else(|| user.get("screen_name"))
                            .and_then(Value::as_str)
                            .map(ToString::to_string)
                    } else {
                        None
                    }
                })
            })
    };

    let author_name = find_user_name(&author_id).unwrap_or_else(|| author_id.clone());

    // Expand truncated retweet text from included referenced tweet
    if let Some(rt_id) = data
        .get("referenced_tweets")
        .and_then(Value::as_array)
        .and_then(|refs| {
            refs.iter().find_map(|r| {
                if r.get("type").and_then(Value::as_str) == Some("retweeted") {
                    r.get("id").and_then(Value::as_str).map(ToString::to_string)
                } else {
                    None
                }
            })
        })
        && let Some(rt_tweet) = event
            .get("includes")
            .and_then(|includes| includes.get("tweets"))
            .and_then(Value::as_array)
            .and_then(|tweets| {
                tweets
                    .iter()
                    .find(|t| t.get("id").and_then(Value::as_str) == Some(rt_id.as_str()))
            })
    {
        let rt_author = rt_tweet
            .get("author_id")
            .and_then(Value::as_str)
            .and_then(find_user_name)
            .unwrap_or_default();
        let rt_text = rt_tweet
            .get("text")
            .and_then(Value::as_str)
            .unwrap_or_default();
        text = format!("RT @{rt_author}: {rt_text}");
    }

    let created_at = data
        .get("created_at")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();

    Some(serde_json::json!({
        "id": id,
        "id_str": id,
        "text": text,
        "created_at": created_at,
        "user": {"screen_name": author_name, "id": author_id}
    }))
}

fn stream_max_events() -> Option<usize> {
    std::env::var("X_STREAM_MAX_EVENTS")
        .ok()
        .or_else(|| std::env::var("T_STREAM_MAX_EVENTS").ok())
        .and_then(|value| value.parse::<usize>().ok())
}

fn wrap_text(text: &str, width: usize) -> Vec<String> {
    let mut lines = Vec::new();
    for paragraph in text.split("\n\n") {
        let mut current = String::new();
        for word in paragraph.split_whitespace() {
            if current.is_empty() {
                current.push_str(word);
            } else if current.len() + 1 + word.len() <= width {
                current.push(' ');
                current.push_str(word);
            } else {
                lines.push(current);
                current = word.to_string();
            }
        }
        if !current.is_empty() {
            lines.push(current);
        }
    }
    if lines.is_empty() {
        lines.push(String::new());
    }
    lines
}

fn print_table(headings: &[&str], rows: &[Vec<String>], out: &mut dyn Write) {
    if rows.is_empty() {
        return;
    }

    let column_count = headings.len();
    let mut widths = vec![0usize; column_count];
    for (index, heading) in headings.iter().enumerate() {
        widths[index] = heading.len();
    }
    for row in rows {
        for (index, value) in row.iter().enumerate().take(column_count) {
            widths[index] = widths[index].max(value.len());
        }
    }

    let heading_row = headings
        .iter()
        .enumerate()
        .map(|(index, heading)| format!("{heading:<width$}", width = widths[index]))
        .collect::<Vec<_>>()
        .join("  ");
    writeln!(out, "{}", heading_row).ok();

    for row in rows {
        let line = row
            .iter()
            .enumerate()
            .map(|(index, value)| format!("{value:<width$}", width = widths[index]))
            .collect::<Vec<_>>()
            .join("  ");
        writeln!(out, "{}", line).ok();
    }
}

fn print_key_value_table(rows: &[(&str, String)], out: &mut dyn Write) {
    let max_width = rows.iter().map(|(key, _)| key.len()).max().unwrap_or(0);
    for (key, value) in rows {
        writeln!(out, "{:<width$}  {}", key, value, width = max_width).ok();
    }
}

fn collect_tweets_paginated(
    backend: &mut dyn Backend,
    path: &str,
    mut params: Vec<(String, String)>,
    auth: AuthScheme,
    limit: usize,
) -> Result<Vec<Value>, CommandError> {
    let mut tweets = Vec::new();
    if limit == 0 {
        return Ok(tweets);
    }

    if !params.iter().any(|(key, _)| key == "max_results") {
        params.push((
            "max_results".to_string(),
            limit.min(MAX_SEARCH_RESULTS).to_string(),
        ));
    }

    for _ in 0..MAX_PAGE {
        let response = match auth {
            AuthScheme::OAuth1User => get_json_with_retry(backend, path, params.clone())?,
            AuthScheme::OAuth2Bearer => get_json_oauth2_with_retry(backend, path, params.clone())?,
            AuthScheme::OAuth2User => {
                get_json_oauth2_user_with_retry(backend, path, params.clone())?
            }
        };
        tweets.extend(extract_tweets(&response));
        if tweets.len() >= limit {
            break;
        }

        let Some(next_token) = response
            .get("meta")
            .and_then(|meta| meta.get("next_token"))
            .and_then(Value::as_str)
            .map(ToString::to_string)
        else {
            break;
        };

        params.retain(|(key, _)| key != "pagination_token");
        params.push(("pagination_token".to_string(), next_token));
    }

    tweets.truncate(limit);
    Ok(tweets)
}

fn collect_owned_lists_paginated(
    backend: &mut dyn Backend,
    user_id: &str,
) -> Result<Vec<Value>, CommandError> {
    let endpoint = format!("/2/users/{user_id}/owned_lists");
    let mut params = vec![
        ("max_results".to_string(), "100".to_string()),
        ("list.fields".to_string(), V2_LIST_FIELDS.to_string()),
        ("expansions".to_string(), "owner_id".to_string()),
        ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
    ];
    let mut lists = Vec::new();

    for _ in 0..MAX_PAGE {
        let response = get_json_oauth2_with_retry(backend, &endpoint, params.clone())?;
        lists.extend(extract_lists(&response));

        let Some(next_token) = response
            .get("meta")
            .and_then(|meta| meta.get("next_token"))
            .and_then(Value::as_str)
            .map(ToString::to_string)
        else {
            break;
        };

        params.retain(|(key, _)| key != "pagination_token");
        params.push(("pagination_token".to_string(), next_token));
    }

    Ok(lists)
}

fn collect_user_search_pages(
    backend: &mut dyn Backend,
    query: &str,
) -> Result<Vec<Value>, CommandError> {
    let mut params = vec![
        ("query".to_string(), query.to_string()),
        ("max_results".to_string(), "100".to_string()),
        ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
        ("expansions".to_string(), V2_USER_EXPANSIONS.to_string()),
        ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
    ];
    let mut users = Vec::new();
    let mut previous_page_ids: Option<Vec<String>> = None;

    for _ in 0..MAX_PAGE {
        let response = get_json_with_retry(backend, "/2/users/search", params.clone())?;
        let page_users = extract_users(&response);
        let page_ids = page_users.iter().filter_map(value_id).collect::<Vec<_>>();
        if page_users.is_empty() || previous_page_ids.as_ref() == Some(&page_ids) {
            break;
        }

        users.extend(page_users);
        previous_page_ids = Some(page_ids);

        let Some(next_token) = response
            .get("meta")
            .and_then(|meta| meta.get("next_token"))
            .and_then(Value::as_str)
            .map(ToString::to_string)
        else {
            break;
        };
        params.retain(|(key, _)| key != "next_token");
        params.push(("next_token".to_string(), next_token));
    }

    Ok(users)
}

fn build_stream_rule_values(terms: &[String]) -> Vec<String> {
    let mut rules = Vec::new();
    let mut current = String::new();

    for term in terms {
        if term.trim().is_empty() {
            continue;
        }
        let token = term.trim().to_string();
        let candidate = if current.is_empty() {
            token.clone()
        } else {
            format!("{current} OR {token}")
        };

        if candidate.len() > 512 && !current.is_empty() {
            rules.push(current);
            current = token;
        } else {
            current = candidate;
        }
    }

    if !current.is_empty() {
        rules.push(current);
    }

    rules
}

fn filtered_stream_rule_tag(index: usize) -> String {
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or_default();
    format!("x-rust-{millis}-{index}")
}

fn clear_filtered_stream_rules(backend: &mut dyn Backend) -> Result<(), CommandError> {
    let response =
        get_json_oauth2_with_retry(backend, "/2/tweets/search/stream/rules", Vec::new())?;
    let ids: Vec<String> = response
        .get("data")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|rule| {
            rule.get("id")
                .and_then(Value::as_str)
                .map(ToString::to_string)
        })
        .collect();
    remove_filtered_stream_rules(backend, &ids)
}

fn install_filtered_stream_rules(
    backend: &mut dyn Backend,
    terms: &[String],
) -> Result<Vec<String>, CommandError> {
    clear_filtered_stream_rules(backend)?;

    let rule_values = build_stream_rule_values(terms);
    if rule_values.is_empty() {
        return Ok(Vec::new());
    }

    let add_rules = rule_values
        .iter()
        .enumerate()
        .map(|(index, value)| {
            serde_json::json!({
                "value": value,
                "tag": filtered_stream_rule_tag(index)
            })
        })
        .collect::<Vec<_>>();

    let response = post_json_oauth2_with_retry(
        backend,
        "/2/tweets/search/stream/rules",
        serde_json::json!({ "add": add_rules }),
    )?;

    Ok(response
        .get("data")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|rule| {
            rule.get("id")
                .and_then(Value::as_str)
                .map(ToString::to_string)
        })
        .collect())
}

fn remove_filtered_stream_rules(
    backend: &mut dyn Backend,
    ids: &[String],
) -> Result<(), CommandError> {
    if ids.is_empty() {
        return Ok(());
    }

    let _ = post_json_oauth2_with_retry(
        backend,
        "/2/tweets/search/stream/rules",
        serde_json::json!({ "delete": { "ids": ids } }),
    )?;
    Ok(())
}

fn stream_filtered_tweets(
    backend: &mut dyn Backend,
    terms: Vec<String>,
    leaf: &ArgMatches,
    out: &mut dyn Write,
) -> Result<(), CommandError> {
    let rule_ids = install_filtered_stream_rules(backend, &terms)?;
    let stream_result = stream_tweets(
        backend,
        "/2/tweets/search/stream",
        v2_stream_params(),
        AuthScheme::OAuth2Bearer,
        leaf,
        out,
    );
    let cleanup_result = remove_filtered_stream_rules(backend, &rule_ids);

    stream_result?;
    cleanup_result
}

fn run_matrix_stream(backend: &mut dyn Backend, out: &mut dyn Write) -> Result<(), CommandError> {
    let rule_ids = install_filtered_stream_rules(backend, &["の lang:ja".to_string()])?;
    let max_events = stream_max_events();
    let mut seen = 0usize;
    let stream_result = backend.stream_json_lines(
        "/2/tweets/search/stream",
        vec![("tweet.fields".to_string(), "text".to_string())],
        AuthScheme::OAuth2Bearer,
        &mut |event| {
            let Some(tweet) = tweet_from_stream_event(event) else {
                return true;
            };
            let text = tweet_text(&tweet, false);
            let matrix: String = text
                .chars()
                .filter(|ch| ('\u{3000}'..='\u{309f}').contains(ch))
                .collect::<String>()
                .chars()
                .rev()
                .collect();
            if !matrix.is_empty() {
                write!(out, "\x1b[1;32;40m{}\x1b[0m", matrix).ok();
                out.flush().ok();
                seen += 1;
            }
            max_events.map(|max| seen < max).unwrap_or(true)
        },
    );
    let cleanup_result = remove_filtered_stream_rules(backend, &rule_ids);
    stream_result?;
    cleanup_result?;
    Ok(())
}

fn expand_path(path: &str) -> PathBuf {
    if let Some(suffix) = path.strip_prefix("~/")
        && let Ok(home) = std::env::var("HOME")
    {
        return PathBuf::from(home).join(suffix);
    }
    PathBuf::from(path)
}

fn load_file_as_base64(path: &str) -> Result<String, CommandError> {
    let bytes = fs::read(expand_path(path))?;
    Ok(base64::engine::general_purpose::STANDARD.encode(bytes))
}

fn upload_media(backend: &mut dyn Backend, file_path: &str) -> Result<String, CommandError> {
    let media_data = load_file_as_base64(file_path)?;
    let response = post_json_with_retry(
        backend,
        "/1.1/media/upload.json",
        vec![("media_data".to_string(), media_data.clone())],
    )?;

    let media_id = response
        .get("media_id_string")
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .or_else(|| {
            response
                .get("media_id")
                .and_then(value_to_string)
                .filter(|id| !id.is_empty())
        })
        .unwrap_or_default();

    if media_id.is_empty() {
        return Err(CommandError::Io(io::Error::other(
            "Media upload did not return a media_id",
        )));
    }

    Ok(media_id)
}

fn lookup_users_by_ids(
    backend: &mut dyn Backend,
    ids: &[String],
) -> Result<Vec<Value>, CommandError> {
    if ids.is_empty() {
        return Ok(Vec::new());
    }

    let mut users = Vec::new();
    for chunk in ids.chunks(100) {
        let response = get_json_oauth2_with_retry(
            backend,
            "/2/users",
            vec![
                ("ids".to_string(), chunk.join(",")),
                ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
                ("expansions".to_string(), V2_USER_EXPANSIONS.to_string()),
                ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
            ],
        )?;
        users.extend(extract_users(&response));
    }

    Ok(users)
}

fn fetch_user(backend: &mut dyn Backend, user: &str, by_id: bool) -> Result<Value, CommandError> {
    let response = if by_id {
        get_json_oauth2_with_retry(
            backend,
            &format!("/2/users/{user}"),
            vec![
                ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
                ("expansions".to_string(), V2_USER_EXPANSIONS.to_string()),
                ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
            ],
        )?
    } else {
        get_json_oauth2_with_retry(
            backend,
            &format!("/2/users/by/username/{}", strip_at(user)),
            vec![
                ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
                ("expansions".to_string(), V2_USER_EXPANSIONS.to_string()),
                ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
            ],
        )?
    };

    Ok(extract_users(&response)
        .into_iter()
        .next()
        .unwrap_or(Value::Null))
}

fn fetch_current_user(backend: &mut dyn Backend) -> Result<Value, CommandError> {
    fetch_current_user_with_credentials(backend, None)
}

fn fetch_current_user_with_credentials(
    backend: &mut dyn Backend,
    credentials: Option<&Credentials>,
) -> Result<Value, CommandError> {
    if credentials
        .and_then(|credentials| credentials.oauth2_user.as_ref())
        .is_some()
    {
        let response = get_json_oauth2_user_with_retry(
            backend,
            "/2/users/me",
            vec![
                ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
                ("expansions".to_string(), V2_USER_EXPANSIONS.to_string()),
                ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
            ],
        )?;

        return Ok(extract_users(&response)
            .into_iter()
            .next()
            .unwrap_or(Value::Null));
    }

    let v2_result = get_json_with_retry(
        backend,
        "/2/users/me",
        vec![
            ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
            ("expansions".to_string(), V2_USER_EXPANSIONS.to_string()),
            ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
        ],
    );

    let response = match v2_result {
        Ok(resp) => resp,
        Err(BackendError::Http(ref msg)) if msg.contains("503") => {
            backend.get_json("/1.1/account/verify_credentials.json", vec![])?
        }
        Err(e) => return Err(e.into()),
    };

    Ok(extract_users(&response)
        .into_iter()
        .next()
        .unwrap_or(Value::Null))
}

fn authenticated_user_id(backend: &mut dyn Backend) -> Result<String, CommandError> {
    Ok(value_id(&fetch_current_user(backend)?).unwrap_or_default())
}

fn authenticated_user_id_for_bookmarks(backend: &mut dyn Backend) -> Result<String, CommandError> {
    let response = get_json_oauth2_user_with_retry(
        backend,
        "/2/users/me",
        vec![("user.fields".to_string(), "id,username".to_string())],
    )?;
    Ok(response
        .get("data")
        .and_then(|data| data.get("id"))
        .and_then(value_to_string)
        .unwrap_or_default())
}

fn resolve_user_id(
    backend: &mut dyn Backend,
    user: &str,
    by_id: bool,
) -> Result<String, CommandError> {
    if by_id {
        return Ok(user.to_string());
    }

    let resolved = fetch_user(backend, user, false)?;
    Ok(value_id(&resolved).unwrap_or_else(|| strip_at(user)))
}

fn fetch_relationship_ids_v2(
    backend: &mut dyn Backend,
    user_id: &str,
    relationship: &str,
) -> Result<Vec<String>, CommandError> {
    let endpoint = if relationship == "followers" {
        format!("/2/users/{user_id}/followers")
    } else {
        format!("/2/users/{user_id}/following")
    };

    let mut params = vec![
        ("max_results".to_string(), "1000".to_string()),
        ("user.fields".to_string(), "id,username".to_string()),
    ];
    let mut ids = Vec::new();

    for _ in 0..MAX_PAGE {
        let response = get_json_oauth2_with_retry(backend, &endpoint, params.clone())?;
        ids.extend(extract_ids(&response));

        let Some(next_token) = response
            .get("meta")
            .and_then(|meta| meta.get("next_token"))
            .and_then(Value::as_str)
            .map(ToString::to_string)
        else {
            break;
        };

        params.retain(|(key, _)| key != "pagination_token");
        params.push(("pagination_token".to_string(), next_token));
    }

    Ok(ids)
}

fn slugify_list_name(value: &str) -> String {
    let mut output = String::new();
    let mut previous_dash = false;
    for ch in value.chars() {
        if ch.is_ascii_alphanumeric() || ch == '_' {
            output.push(ch.to_ascii_lowercase());
            previous_dash = false;
        } else if !previous_dash {
            output.push('-');
            previous_dash = true;
        }
    }
    output.trim_matches('-').to_string()
}

fn resolve_list_id(
    backend: &mut dyn Backend,
    user_list: &str,
    by_id: bool,
    default_owner: &str,
) -> Result<String, CommandError> {
    if by_id {
        return Ok(user_list.to_string());
    }

    let (owner, list_name) = extract_owner_and_list(user_list, false, default_owner);
    let owner_id = resolve_user_id(backend, &owner, false)?;
    let lists = collect_owned_lists_paginated(backend, &owner_id)?;

    let desired = slugify_list_name(&list_name);
    let matched = lists.into_iter().find(|list| {
        let slug = list
            .get("slug")
            .or_else(|| list.get("name"))
            .and_then(Value::as_str)
            .unwrap_or_default();
        slug.eq_ignore_ascii_case(&list_name) || slugify_list_name(slug) == desired
    });

    Ok(matched
        .and_then(|list| value_id(&list))
        .unwrap_or(list_name))
}

/// Fetches all collections owned by a user using the v1.1 collections/list endpoint.
fn fetch_user_collections(
    backend: &mut dyn Backend,
    user: &str,
    by_id: bool,
) -> Result<Vec<Value>, CommandError> {
    let mut params = vec![user_query_param(by_id, user)];
    let mut collections = Vec::new();

    for _ in 0..MAX_PAGE {
        let response = get_json_with_retry(backend, "/1.1/collections/list.json", params.clone())?;

        // Extract timelines from objects.timelines map
        let timelines = response
            .get("objects")
            .and_then(|o| o.get("timelines"))
            .and_then(Value::as_object)
            .cloned()
            .unwrap_or_default();

        // Use response.results to get the ordering
        let results = response
            .get("response")
            .and_then(|r| r.get("results"))
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();

        for result in &results {
            let timeline_id = result
                .get("timeline_id")
                .and_then(Value::as_str)
                .unwrap_or_default();
            if let Some(timeline) = timelines.get(timeline_id) {
                let mut obj = timeline.clone();
                if let Some(map) = obj.as_object_mut() {
                    map.insert("id_str".to_string(), Value::String(timeline_id.to_string()));
                }
                collections.push(obj);
            }
        }

        // Check for next cursor
        let next_cursor = response
            .get("response")
            .and_then(|r| r.get("cursors"))
            .and_then(|c| c.get("next_cursor"))
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty());

        let Some(cursor) = next_cursor else {
            break;
        };

        params.retain(|(key, _)| key != "cursor");
        params.push(("cursor".to_string(), cursor.to_string()));
    }

    Ok(collections)
}

/// Resolves a collection name or ID to a collection timeline ID (e.g. "custom-123456").
fn resolve_collection_id(
    backend: &mut dyn Backend,
    name_or_id: &str,
    by_id: bool,
    default_owner: &str,
) -> Result<String, CommandError> {
    if by_id {
        return Ok(name_or_id.to_string());
    }

    let collections = fetch_user_collections(backend, default_owner, false)?;
    let matched = collections.into_iter().find(|c| {
        c.get("name")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .eq_ignore_ascii_case(name_or_id)
    });

    Ok(matched
        .and_then(|c| value_id(&c))
        .unwrap_or_else(|| name_or_id.to_string()))
}

/// Extracts ordered tweets from the v1.1 collections/entries response format.
fn extract_collection_entries(value: &Value) -> Vec<Value> {
    let tweets_map = value
        .get("objects")
        .and_then(|o| o.get("tweets"))
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();

    let users_map = value
        .get("objects")
        .and_then(|o| o.get("users"))
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();

    let timeline = value
        .get("response")
        .and_then(|r| r.get("timeline"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();

    let mut tweets = Vec::new();
    for entry in &timeline {
        let tweet_id = entry
            .get("tweet")
            .and_then(|t| t.get("id"))
            .and_then(Value::as_str)
            .unwrap_or_default();

        if let Some(mut tweet) = tweets_map.get(tweet_id).cloned() {
            // Attach full user object from objects.users if available
            let user_id = tweet
                .get("user")
                .and_then(Value::as_object)
                .and_then(|u| u.get("id_str").or_else(|| u.get("id")))
                .and_then(value_to_string);
            if let Some(uid) = user_id
                && let Some(user) = users_map.get(&uid)
                && let Some(map) = tweet.as_object_mut()
            {
                map.insert("user".to_string(), user.clone());
            }
            tweets.push(tweet);
        }
    }
    tweets
}

/// Collects tweets from a collection, handling pagination via position cursors.
fn collect_collection_entries(
    backend: &mut dyn Backend,
    collection_id: &str,
    limit: usize,
) -> Result<Vec<Value>, CommandError> {
    let mut tweets = Vec::new();
    if limit == 0 {
        return Ok(tweets);
    }

    let mut params = vec![
        ("id".to_string(), collection_id.to_string()),
        ("count".to_string(), limit.min(200).to_string()),
    ];

    for _ in 0..MAX_PAGE {
        let response =
            get_json_with_retry(backend, "/1.1/collections/entries.json", params.clone())?;

        tweets.extend(extract_collection_entries(&response));

        if tweets.len() >= limit {
            break;
        }

        // Check if there are more entries
        let was_truncated = response
            .get("response")
            .and_then(|r| r.get("position"))
            .and_then(|p| p.get("was_truncated"))
            .and_then(Value::as_bool)
            .unwrap_or(false);

        if !was_truncated {
            break;
        }

        let min_position = response
            .get("response")
            .and_then(|r| r.get("position"))
            .and_then(|p| p.get("min_position"))
            .and_then(Value::as_str)
            .map(ToString::to_string);

        let Some(pos) = min_position else {
            break;
        };

        params.retain(|(key, _)| key != "max_position");
        params.push(("max_position".to_string(), pos));
    }

    tweets.truncate(limit);
    Ok(tweets)
}

/// Extracts collection metadata from a collections/show response.
fn extract_collection_metadata(value: &Value, collection_id: &str) -> Value {
    let timelines = value
        .get("objects")
        .and_then(|o| o.get("timelines"))
        .and_then(Value::as_object);

    if let Some(timelines) = timelines
        && let Some(timeline) = timelines.get(collection_id)
    {
        let mut obj = timeline.clone();
        if let Some(map) = obj.as_object_mut() {
            map.insert(
                "id_str".to_string(),
                Value::String(collection_id.to_string()),
            );
        }
        return obj;
    }

    Value::Null
}

fn fetch_list_member_ids_v2(
    backend: &mut dyn Backend,
    list_id: &str,
) -> Result<Vec<String>, CommandError> {
    let endpoint = format!("/2/lists/{list_id}/members");
    let mut params = vec![
        ("max_results".to_string(), "100".to_string()),
        ("user.fields".to_string(), "id,username".to_string()),
    ];
    let mut ids = Vec::new();

    for _ in 0..MAX_PAGE {
        let response = get_json_oauth2_with_retry(backend, &endpoint, params.clone())?;
        ids.extend(extract_ids(&response));

        let Some(next_token) = response
            .get("meta")
            .and_then(|meta| meta.get("next_token"))
            .and_then(Value::as_str)
            .map(ToString::to_string)
        else {
            break;
        };

        params.retain(|(key, _)| key != "pagination_token");
        params.push(("pagination_token".to_string(), next_token));
    }

    Ok(ids)
}

fn v2_tweet_params() -> Vec<(String, String)> {
    vec![
        ("tweet.fields".to_string(), V2_TWEET_FIELDS.to_string()),
        ("expansions".to_string(), V2_TWEET_EXPANSIONS.to_string()),
        ("user.fields".to_string(), V2_USER_FIELDS.to_string()),
        ("place.fields".to_string(), V2_PLACE_FIELDS.to_string()),
    ]
}

fn v2_stream_params() -> Vec<(String, String)> {
    vec![
        (
            "tweet.fields".to_string(),
            "author_id,created_at,referenced_tweets".to_string(),
        ),
        (
            "expansions".to_string(),
            "author_id,referenced_tweets.id".to_string(),
        ),
    ]
}

fn timeline_like_v2_params(leaf: &ArgMatches) -> Vec<(String, String)> {
    let mut params = vec![(
        "max_results".to_string(),
        opt_usize(leaf, "number")
            .unwrap_or(DEFAULT_NUM_RESULTS)
            .min(MAX_SEARCH_RESULTS)
            .to_string(),
    )];

    if let Some(exclude) = opt_string(leaf, "exclude") {
        params.push(("exclude".to_string(), exclude.to_string()));
    }
    if let Some(max_id) = opt_string(leaf, "max_id") {
        params.push(("until_id".to_string(), max_id.to_string()));
    }
    if let Some(since_id) = opt_string(leaf, "since_id") {
        params.push(("since_id".to_string(), since_id.to_string()));
    }

    params
}

fn bookmark_v2_params(leaf: &ArgMatches) -> Vec<(String, String)> {
    let mut params = vec![(
        "max_results".to_string(),
        opt_usize(leaf, "number")
            .unwrap_or(DEFAULT_NUM_RESULTS)
            .min(MAX_SEARCH_RESULTS)
            .to_string(),
    )];
    params.extend(v2_tweet_params());
    params
}

fn timeline_v2_params(leaf: &ArgMatches) -> Vec<(String, String)> {
    [timeline_like_v2_params(leaf), v2_tweet_params()].concat()
}

fn active_profile_name_or_unknown(rcfile: &RcFile) -> &str {
    rcfile
        .active_profile()
        .map(|(name, _)| name)
        .unwrap_or("unknown")
}

fn arg_or_active_name(args: &[String], active_name: &str) -> String {
    args.first()
        .cloned()
        .unwrap_or_else(|| active_name.to_string())
}

fn extract_dm_events(value: &Value) -> Vec<Value> {
    value
        .get("events")
        .or_else(|| value.get("data"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

fn extract_dm_users_by_id(value: &Value) -> HashMap<String, Value> {
    let mut users_by_id = HashMap::new();

    if let Some(users) = value
        .get("includes")
        .and_then(|includes| includes.get("users"))
        .and_then(Value::as_array)
    {
        for user in users {
            if let Some(id) = value_id(user) {
                users_by_id.insert(id, user.clone());
            }
        }
    }

    match value.get("users") {
        Some(Value::Array(users)) => {
            for user in users {
                if let Some(id) = value_id(user) {
                    users_by_id.insert(id, user.clone());
                }
            }
        }
        Some(Value::Object(users)) => {
            for (id, user) in users {
                users_by_id.insert(id.clone(), user.clone());
                if let Some(id_str) = user.get("id_str").and_then(Value::as_str) {
                    users_by_id.insert(id_str.to_string(), user.clone());
                }
            }
        }
        _ => {}
    }

    users_by_id
}

fn dm_user_screen_name(user: &Value) -> String {
    user.get("screen_name")
        .or_else(|| user.get("username"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn dm_event_id(event: &Value) -> String {
    event
        .get("id")
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .unwrap_or_default()
}

fn dm_event_type(event: &Value) -> String {
    event
        .get("type")
        .or_else(|| event.get("event_type"))
        .and_then(Value::as_str)
        .map(|value| value.to_ascii_lowercase().replace('_', ""))
        .unwrap_or_else(|| "messagecreate".to_string())
}

fn dm_sender_id(event: &Value) -> String {
    event
        .get("message_create")
        .and_then(|create| create.get("sender_id"))
        .or_else(|| event.get("sender_id"))
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .unwrap_or_default()
}

fn dm_recipient_id(event: &Value) -> String {
    event
        .get("message_create")
        .and_then(|create| create.get("target"))
        .and_then(|target| target.get("recipient_id"))
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .unwrap_or_default()
}

fn dm_other_participant_id(event: &Value, my_id: &str) -> Option<String> {
    if let Some(conversation_id) = event.get("dm_conversation_id").and_then(Value::as_str) {
        for participant in conversation_id.split('-') {
            if participant != my_id {
                return Some(participant.to_string());
            }
        }
    }
    None
}

fn dm_peer_id(event: &Value, my_id: &str, sent: bool) -> String {
    let sender = dm_sender_id(event);
    if event.get("message_create").is_some() {
        if sent {
            return dm_recipient_id(event);
        }
        return sender;
    }

    if sent {
        dm_other_participant_id(event, my_id).unwrap_or_default()
    } else if sender != my_id {
        sender
    } else {
        dm_other_participant_id(event, my_id).unwrap_or_default()
    }
}

fn dm_text(event: &Value, decode_uris: bool) -> String {
    let text = event
        .get("message_create")
        .and_then(|create| create.get("message_data"))
        .and_then(|message_data| message_data.get("text"))
        .or_else(|| event.get("text"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();

    if !decode_uris {
        return text;
    }

    let mut decoded = text;
    if let Some(urls) = event
        .get("message_create")
        .and_then(|create| create.get("message_data"))
        .and_then(|message_data| message_data.get("entities"))
        .and_then(|entities| entities.get("urls"))
        .or_else(|| event.get("urls"))
        .and_then(Value::as_array)
    {
        for url in urls {
            if let (Some(short), Some(expanded)) = (
                url.get("url").and_then(Value::as_str),
                url.get("expanded_url").and_then(Value::as_str),
            ) {
                decoded = decoded.replace(short, expanded);
            }
        }
    }
    decoded
}

fn dm_time(event: &Value) -> Option<DateTime<Utc>> {
    event
        .get("created_timestamp")
        .and_then(Value::as_str)
        .and_then(|timestamp| timestamp.parse::<i64>().ok())
        .and_then(DateTime::<Utc>::from_timestamp_millis)
        .or_else(|| {
            event
                .get("created_at")
                .and_then(Value::as_str)
                .and_then(parse_twitter_time)
        })
}

fn dm_csv_time(event: &Value) -> String {
    dm_time(event).map(csv_like_time).unwrap_or_default()
}

fn dm_ls_time(event: &Value, relative: bool) -> String {
    ls_like_time(dm_time(event), relative)
}

fn index_items_by_id(values: Option<&[Value]>) -> HashMap<String, Value> {
    let mut indexed = HashMap::new();
    let Some(values) = values else {
        return indexed;
    };

    for value in values {
        if let Some(id) = value_id(value) {
            indexed.insert(id, value.clone());
        }
    }

    indexed
}

fn normalize_v2_tweet(
    tweet: &Value,
    users_by_id: &HashMap<String, Value>,
    places_by_id: &HashMap<String, Value>,
) -> Value {
    if tweet.get("user").is_some() {
        return tweet.clone();
    }

    let mut object = serde_json::Map::new();
    let id = value_id(tweet).unwrap_or_default();
    if !id.is_empty() {
        object.insert("id".to_string(), Value::String(id.clone()));
        object.insert("id_str".to_string(), Value::String(id));
    }

    if let Some(text) = tweet
        .get("full_text")
        .or_else(|| tweet.get("text"))
        .and_then(Value::as_str)
    {
        object.insert("text".to_string(), Value::String(text.to_string()));
        object.insert("full_text".to_string(), Value::String(text.to_string()));
    }

    if let Some(created_at) = tweet.get("created_at").and_then(Value::as_str) {
        object.insert(
            "created_at".to_string(),
            Value::String(created_at.to_string()),
        );
    }
    if let Some(source) = tweet.get("source") {
        object.insert("source".to_string(), source.clone());
    }
    if let Some(refs) = tweet.get("referenced_tweets").and_then(Value::as_array)
        && let Some(replied) = refs
            .iter()
            .find(|r| r.get("type").and_then(Value::as_str) == Some("replied_to"))
        && let Some(id) = replied.get("id").and_then(Value::as_str)
    {
        object.insert(
            "in_reply_to_status_id".to_string(),
            Value::String(id.to_string()),
        );
    }
    if let Some(entities) = tweet.get("entities") {
        object.insert("entities".to_string(), entities.clone());
    }
    if let Some(metrics) = tweet.get("public_metrics") {
        if let Some(retweets) = metrics.get("retweet_count") {
            object.insert("retweet_count".to_string(), retweets.clone());
        }
        if let Some(favorites) = metrics.get("like_count") {
            object.insert("favorite_count".to_string(), favorites.clone());
        }
    }

    if let Some(author_id) = tweet.get("author_id").and_then(Value::as_str) {
        let user = users_by_id
            .get(author_id)
            .map(normalize_v2_user)
            .unwrap_or_else(|| {
                serde_json::json!({
                    "id": author_id,
                    "id_str": author_id,
                    "screen_name": author_id,
                    "username": author_id,
                })
            });
        object.insert("user".to_string(), user);
    }

    if let Some(place_id) = tweet
        .get("geo")
        .and_then(|geo| geo.get("place_id"))
        .and_then(Value::as_str)
        && let Some(place) = places_by_id.get(place_id)
    {
        object.insert("place".to_string(), place.clone());
    }

    Value::Object(object)
}

fn normalize_v2_user(user: &Value) -> Value {
    if user.get("screen_name").is_some() {
        return user.clone();
    }

    let mut object = serde_json::Map::new();
    let id = value_id(user).unwrap_or_default();
    if !id.is_empty() {
        object.insert("id".to_string(), Value::String(id.clone()));
        object.insert("id_str".to_string(), Value::String(id));
    }

    if let Some(username) = user
        .get("username")
        .or_else(|| user.get("screen_name"))
        .and_then(Value::as_str)
    {
        object.insert(
            "screen_name".to_string(),
            Value::String(username.to_string()),
        );
        object.insert("username".to_string(), Value::String(username.to_string()));
    }

    for field in [
        "created_at",
        "name",
        "verified",
        "protected",
        "description",
        "location",
        "url",
    ] {
        if let Some(value) = user.get(field) {
            object.insert(field.to_string(), value.clone());
        }
    }

    if let Some(metrics) = user.get("public_metrics") {
        if let Some(tweet_count) = metrics.get("tweet_count") {
            object.insert("statuses_count".to_string(), tweet_count.clone());
        }
        if let Some(like_count) = metrics.get("like_count") {
            object.insert("favourites_count".to_string(), like_count.clone());
            object.insert("favorites_count".to_string(), like_count.clone());
        }
        if let Some(listed_count) = metrics.get("listed_count") {
            object.insert("listed_count".to_string(), listed_count.clone());
        }
        if let Some(following_count) = metrics.get("following_count") {
            object.insert("friends_count".to_string(), following_count.clone());
        }
        if let Some(followers_count) = metrics.get("followers_count") {
            object.insert("followers_count".to_string(), followers_count.clone());
        }
    }

    Value::Object(object)
}

fn normalize_v2_list(list: &Value, users_by_id: &HashMap<String, Value>) -> Value {
    if list.get("slug").is_some() || list.get("full_name").is_some() {
        return list.clone();
    }

    let mut object = serde_json::Map::new();
    let id = value_id(list).unwrap_or_default();
    if !id.is_empty() {
        object.insert("id".to_string(), Value::String(id.clone()));
        object.insert("id_str".to_string(), Value::String(id.clone()));
    }

    let slug = list
        .get("slug")
        .or_else(|| list.get("name"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    object.insert("slug".to_string(), Value::String(slug.clone()));

    for field in ["created_at", "description"] {
        if let Some(value) = list.get(field) {
            object.insert(field.to_string(), value.clone());
        }
    }

    if let Some(member_count) = list.get("member_count") {
        object.insert("member_count".to_string(), member_count.clone());
    }
    if let Some(subscriber_count) = list
        .get("subscriber_count")
        .or_else(|| list.get("follower_count"))
    {
        object.insert("subscriber_count".to_string(), subscriber_count.clone());
    }
    if let Some(mode) = list.get("mode").cloned().or_else(|| {
        list.get("private")
            .and_then(Value::as_bool)
            .map(|private| Value::String(if private { "private" } else { "public" }.to_string()))
    }) {
        object.insert("mode".to_string(), mode);
    }

    if let Some(owner_id) = list.get("owner_id").and_then(Value::as_str)
        && let Some(owner) = users_by_id.get(owner_id)
    {
        let owner = normalize_v2_user(owner);
        let owner_name = user_screen_name(&owner);
        if !owner_name.is_empty() {
            object.insert(
                "full_name".to_string(),
                Value::String(format!("@{owner_name}/{}", slug)),
            );
        }
        object.insert("user".to_string(), owner);
    }

    object.insert(
        "uri".to_string(),
        Value::String(format!("https://x.com/i/lists/{}", id)),
    );
    Value::Object(object)
}

fn extract_tweets(value: &Value) -> Vec<Value> {
    if let Some(array) = value.as_array() {
        return array.clone();
    }

    if let Some(statuses) = value.get("statuses").and_then(Value::as_array) {
        return statuses.clone();
    }

    let users_by_id = index_items_by_id(
        value
            .get("includes")
            .and_then(|includes| includes.get("users"))
            .and_then(Value::as_array)
            .map(Vec::as_slice),
    );
    let places_by_id = index_items_by_id(
        value
            .get("includes")
            .and_then(|includes| includes.get("places"))
            .and_then(Value::as_array)
            .map(Vec::as_slice),
    );
    if let Some(data) = value.get("data").and_then(Value::as_array) {
        return data
            .iter()
            .map(|tweet| normalize_v2_tweet(tweet, &users_by_id, &places_by_id))
            .collect();
    }
    if let Some(data) = value.get("data")
        && data.is_object()
    {
        return vec![normalize_v2_tweet(data, &users_by_id, &places_by_id)];
    }

    Vec::new()
}

fn extract_users(value: &Value) -> Vec<Value> {
    if let Some(array) = value.as_array() {
        return array.clone();
    }

    if let Some(users) = value.get("users").and_then(Value::as_array) {
        return users.clone();
    }

    let users = value.get("data");
    let includes_tweets = index_items_by_id(
        value
            .get("includes")
            .and_then(|includes| includes.get("tweets"))
            .and_then(Value::as_array)
            .map(Vec::as_slice),
    );
    if let Some(users) = users.and_then(Value::as_array) {
        let empty_users = HashMap::new();
        let empty_places = HashMap::new();
        return users
            .iter()
            .map(|user| {
                let mut normalized = normalize_v2_user(user);
                if let Some(pinned_id) = user.get("pinned_tweet_id").and_then(Value::as_str)
                    && let Some(tweet) = includes_tweets.get(pinned_id)
                    && let Some(obj) = normalized.as_object_mut()
                {
                    obj.insert(
                        "status".to_string(),
                        normalize_v2_tweet(tweet, &empty_users, &empty_places),
                    );
                }
                normalized
            })
            .collect();
    }
    if let Some(user) = users {
        let mut normalized = normalize_v2_user(user);
        if let Some(pinned_id) = user.get("pinned_tweet_id").and_then(Value::as_str)
            && let Some(tweet) = includes_tweets.get(pinned_id)
            && let Some(obj) = normalized.as_object_mut()
        {
            let empty_users = HashMap::new();
            let empty_places = HashMap::new();
            obj.insert(
                "status".to_string(),
                normalize_v2_tweet(tweet, &empty_users, &empty_places),
            );
        }
        return vec![normalized];
    }

    // Bare v1.1 user object (e.g. /1.1/account/verify_credentials.json)
    if value.is_object() && (value.get("screen_name").is_some() || value.get("id").is_some()) {
        return vec![value.clone()];
    }

    Vec::new()
}

fn extract_lists(value: &Value) -> Vec<Value> {
    if let Some(array) = value.as_array() {
        return array.clone();
    }

    if let Some(lists) = value.get("lists").and_then(Value::as_array) {
        return lists.clone();
    }

    let users_by_id = index_items_by_id(
        value
            .get("includes")
            .and_then(|includes| includes.get("users"))
            .and_then(Value::as_array)
            .map(Vec::as_slice),
    );
    value
        .get("data")
        .and_then(Value::as_array)
        .map(|lists| {
            lists
                .iter()
                .map(|list| normalize_v2_list(list, &users_by_id))
                .collect()
        })
        .or_else(|| {
            value
                .get("data")
                .map(|list| vec![normalize_v2_list(list, &users_by_id)])
        })
        .unwrap_or_default()
}

fn extract_places(value: &Value) -> Vec<Value> {
    value.as_array().cloned().unwrap_or_default()
}

fn extract_geo_places(value: &Value) -> Vec<Value> {
    value
        .get("result")
        .and_then(|r| r.get("places"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

fn sort_geo_places(places: &mut [Value], leaf: &ArgMatches) {
    if !opt_bool(leaf, "unsorted") {
        let sort = opt_string(leaf, "sort").unwrap_or("name");
        match sort {
            "country" => places.sort_by_key(|place| {
                place
                    .get("country")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
            "type" => places.sort_by_key(|place| {
                place
                    .get("place_type")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
            _ => places.sort_by_key(|place| {
                place
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
        }
    }

    if opt_bool(leaf, "reverse") {
        places.reverse();
    }
}

fn format_geo_places(places: &[Value], leaf: &ArgMatches, out: &mut dyn Write) {
    if opt_bool(leaf, "csv") {
        writeln!(out, "{}", csv_row(PLACE_HEADINGS)).ok();
        for place in places {
            writeln!(
                out,
                "{}",
                csv_row([
                    place
                        .get("id")
                        .and_then(value_to_string)
                        .unwrap_or_default(),
                    place
                        .get("place_type")
                        .and_then(value_to_string)
                        .unwrap_or_default(),
                    place
                        .get("full_name")
                        .and_then(value_to_string)
                        .unwrap_or_default(),
                    place
                        .get("country")
                        .and_then(value_to_string)
                        .unwrap_or_default(),
                ])
            )
            .ok();
        }
    } else if opt_bool(leaf, "long") {
        let mut rows = Vec::new();
        for place in places {
            rows.push(vec![
                place
                    .get("id")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                place
                    .get("place_type")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                place
                    .get("full_name")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
                place
                    .get("country")
                    .and_then(value_to_string)
                    .unwrap_or_default(),
            ]);
        }
        print_table(&PLACE_HEADINGS, &rows, out);
    } else {
        for place in places {
            if let Some(name) = place.get("full_name").and_then(Value::as_str) {
                writeln!(out, "{}", name).ok();
            }
        }
    }
}

fn ip_geolocation() -> Result<(f64, f64, String, String, String), CommandError> {
    let checkip_body = reqwest::blocking::get("http://checkip.dyndns.org/")
        .map_err(|e| CommandError::Other(format!("Failed to look up IP address: {e}")))?
        .text()
        .map_err(|e| CommandError::Other(format!("Failed to read IP response: {e}")))?;
    let ip = regex::Regex::new(r"(?:\d{1,3}\.){3}\d{1,3}")
        .unwrap()
        .find(&checkip_body)
        .map(|m| m.as_str().to_string())
        .ok_or_else(|| CommandError::Other("Could not parse IP address".to_string()))?;

    let ipinfo_text = reqwest::blocking::get(format!("https://ipinfo.io/{ip}/json"))
        .map_err(|e| CommandError::Other(format!("Failed to geolocate IP: {e}")))?
        .text()
        .map_err(|e| CommandError::Other(format!("Failed to read geolocation response: {e}")))?;
    let ipinfo_body: Value = serde_json::from_str(&ipinfo_text)
        .map_err(|e| CommandError::Other(format!("Failed to parse geolocation response: {e}")))?;

    let loc = ipinfo_body
        .get("loc")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let mut parts = loc.split(',');
    let lat: f64 = parts.next().unwrap_or("0").parse().unwrap_or(0.0);
    let lng: f64 = parts.next().unwrap_or("0").parse().unwrap_or(0.0);
    let city = ipinfo_body
        .get("city")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let region = ipinfo_body
        .get("region")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let country = ipinfo_body
        .get("country")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();

    Ok((lat, lng, city, region, country))
}

fn geocode_address(address: &str) -> Result<(f64, f64), CommandError> {
    let encoded = serde_urlencoded::to_string([("q", address), ("format", "json"), ("limit", "1")])
        .unwrap_or_default();
    let url = format!("https://nominatim.openstreetmap.org/search?{encoded}");
    let body = reqwest::blocking::get(&url)
        .map_err(|e| CommandError::Other(format!("Failed to geocode address: {e}")))?
        .text()
        .map_err(|e| CommandError::Other(format!("Failed to read geocode response: {e}")))?;
    let response: Value = serde_json::from_str(&body)
        .map_err(|e| CommandError::Other(format!("Failed to parse geocode response: {e}")))?;

    let first = response
        .as_array()
        .and_then(|arr: &Vec<Value>| arr.first())
        .ok_or_else(|| CommandError::Other(format!("Could not geocode address: {address}")))?;

    let lat: f64 = first
        .get("lat")
        .and_then(Value::as_str)
        .unwrap_or("0")
        .parse()
        .unwrap_or(0.0);
    let lng: f64 = first
        .get("lon")
        .and_then(Value::as_str)
        .unwrap_or("0")
        .parse()
        .unwrap_or(0.0);

    Ok((lat, lng))
}

fn resolve_geo_coordinates(args: &[String]) -> Result<(f64, f64), CommandError> {
    if args.is_empty() {
        let (lat, lng, _, _, _) = ip_geolocation()?;
        Ok((lat, lng))
    } else {
        let address = args.join(" ");
        if let Some((lat_str, lng_str)) = address.split_once(',')
            && let (Ok(lat), Ok(lng)) =
                (lat_str.trim().parse::<f64>(), lng_str.trim().parse::<f64>())
        {
            return Ok((lat, lng));
        }
        geocode_address(&address)
    }
}

fn sort_places(places: &mut [Value], leaf: &ArgMatches) {
    if !opt_bool(leaf, "unsorted") {
        let sort = opt_string(leaf, "sort").unwrap_or("name");
        match sort {
            "country" => places.sort_by_key(|place| {
                place
                    .get("country")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
            "parent" => places.sort_by_key(|place| {
                place
                    .get("parentid")
                    .or_else(|| place.get("parent_id"))
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
            }),
            "type" => places.sort_by_key(|place| {
                place
                    .get("placeType")
                    .and_then(|place_type| place_type.get("name"))
                    .and_then(Value::as_str)
                    .or_else(|| place.get("place_type").and_then(Value::as_str))
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
            "woeid" => {
                places.sort_by_key(|place| place.get("woeid").and_then(Value::as_i64).unwrap_or(0))
            }
            _ => places.sort_by_key(|place| {
                place
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_ascii_lowercase()
            }),
        }
    }

    if opt_bool(leaf, "reverse") {
        places.reverse();
    }
}

fn filter_tweets_by_query(tweets: &[Value], query: &str) -> Vec<Value> {
    if query.is_empty() {
        return tweets.to_vec();
    }

    let lower = query.to_ascii_lowercase();
    tweets
        .iter()
        .filter(|tweet| {
            tweet_text(tweet, false)
                .to_ascii_lowercase()
                .contains(&lower)
        })
        .cloned()
        .collect()
}

fn extract_ids(value: &Value) -> Vec<String> {
    if let Some(ids) = value.get("ids").and_then(Value::as_array) {
        return ids.iter().filter_map(value_to_string).collect::<Vec<_>>();
    }
    if let Some(data) = value.get("data").and_then(Value::as_array) {
        return data.iter().filter_map(value_id).collect::<Vec<_>>();
    }
    if let Some(data) = value.get("data")
        && let Some(id) = value_id(data)
    {
        return vec![id];
    }
    Vec::new()
}

fn tweet_time(value: &Value) -> Option<DateTime<Utc>> {
    value
        .get("created_at")
        .and_then(Value::as_str)
        .and_then(parse_twitter_time)
}

fn list_time(value: &Value) -> Option<DateTime<Utc>> {
    value
        .get("created_at")
        .and_then(Value::as_str)
        .and_then(parse_twitter_time)
}

fn user_time(value: &Value) -> Option<DateTime<Utc>> {
    value
        .get("created_at")
        .and_then(Value::as_str)
        .and_then(parse_twitter_time)
}

fn parse_twitter_time(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_str(value, "%a %b %d %H:%M:%S %z %Y")
        .map(|time| time.with_timezone(&Utc))
        .or_else(|_| DateTime::parse_from_rfc3339(value).map(|time| time.with_timezone(&Utc)))
        .ok()
}

fn csv_like_time<Tz: TimeZone>(time: DateTime<Tz>) -> String
where
    Tz::Offset: std::fmt::Display,
{
    time.with_timezone(&Utc)
        .format("%Y-%m-%d %H:%M:%S %z")
        .to_string()
}

fn ls_like_time(time: Option<DateTime<Utc>>, relative: bool) -> String {
    let Some(time) = time else {
        return String::new();
    };

    if relative {
        return format!("{} ago", distance_of_time_in_words(time, Utc::now()));
    }

    let local = time.with_timezone(&Local);
    if local > (Local::now() - Duration::days(180)) {
        local.format("%b %e %H:%M").to_string()
    } else {
        local.format("%b %e  %Y").to_string()
    }
}

fn distance_of_time_in_words(from: DateTime<Utc>, to: DateTime<Utc>) -> String {
    let seconds = (to - from).num_seconds().abs();
    let minutes = seconds as f64 / 60.0;
    if minutes < 1.0 {
        if seconds < 1 {
            "a split second".to_string()
        } else if seconds < 2 {
            "a second".to_string()
        } else {
            format!("{seconds} seconds")
        }
    } else if minutes < 2.0 {
        "a minute".to_string()
    } else if minutes < 60.0 {
        format!("{} minutes", minutes.round() as i64)
    } else if minutes < 120.0 {
        "an hour".to_string()
    } else if minutes < 1410.0 {
        format!("{} hours", (minutes / 60.0).round() as i64)
    } else if minutes < 2880.0 {
        "a day".to_string()
    } else if minutes < 42_480.0 {
        format!("{} days", (minutes / 1440.0).round() as i64)
    } else if minutes < 86_400.0 {
        "a month".to_string()
    } else if minutes < 503_700.0 {
        format!("{} months", (minutes / 43_800.0).round() as i64)
    } else if minutes < 1_051_200.0 {
        "a year".to_string()
    } else {
        format!("{} years", (minutes / 525_600.0).round() as i64)
    }
}

fn user_screen_name(user: &Value) -> String {
    user.get("screen_name")
        .or_else(|| user.get("username"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn tweet_text(tweet: &Value, decode_uris: bool) -> String {
    let text = tweet
        .get("full_text")
        .or_else(|| tweet.get("text"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();

    if !decode_uris {
        return text;
    }

    let mut decoded = text;
    if let Some(urls) = tweet
        .get("entities")
        .and_then(|entities| entities.get("urls"))
        .and_then(Value::as_array)
    {
        for url in urls {
            if let (Some(short), Some(expanded)) = (
                url.get("url").and_then(Value::as_str),
                url.get("expanded_url").and_then(Value::as_str),
            ) {
                decoded = decoded.replace(short, expanded);
            }
        }
    }

    decoded
}

fn display_user_from_response(response: &Value, fallback: &str) -> String {
    response
        .get("screen_name")
        .or_else(|| response.get("username"))
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .unwrap_or_else(|| strip_at(fallback))
}

fn normalize_user_arg(value: &str, by_id: bool) -> String {
    if by_id {
        value.to_string()
    } else {
        strip_at(value)
    }
}

fn resolve_user_list(args: &[String], by_id: bool) -> Vec<String> {
    args.iter()
        .map(|arg| normalize_user_arg(arg, by_id))
        .collect()
}

fn resolve_id_list(args: &[String]) -> Vec<String> {
    args.iter()
        .map(|arg| arg.trim().to_string())
        .collect::<Vec<_>>()
}

fn extract_owner_and_list(user_list: &str, by_id: bool, default_owner: &str) -> (String, String) {
    match user_list.split_once('/') {
        Some((owner, list_name)) => {
            if by_id {
                (owner.to_string(), list_name.to_string())
            } else {
                (strip_at(owner), list_name.to_string())
            }
        }
        None => (default_owner.to_string(), user_list.to_string()),
    }
}

fn value_id(value: &Value) -> Option<String> {
    value
        .get("id_str")
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .or_else(|| value.get("id").and_then(value_to_string))
}

fn value_to_string(value: &Value) -> Option<String> {
    if let Some(text) = value.as_str() {
        return Some(text.to_string());
    }
    if let Some(number) = value.as_i64() {
        return Some(number.to_string());
    }
    if let Some(number) = value.as_u64() {
        return Some(number.to_string());
    }
    if let Some(boolean) = value.as_bool() {
        return Some(boolean.to_string());
    }
    None
}

fn strip_tags(input: &str) -> String {
    let mut inside_tag = false;
    let mut output = String::with_capacity(input.len());
    for ch in input.chars() {
        match ch {
            '<' => inside_tag = true,
            '>' => inside_tag = false,
            _ if !inside_tag => output.push(ch),
            _ => {}
        }
    }
    output
}

fn status_location(status: &Value) -> String {
    if let Some(place) = status.get("place") {
        let name = place
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let full = place
            .get("full_name")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let country = place
            .get("country")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let attributes = place.get("attributes");
        let street = attributes
            .and_then(|attrs| attrs.get("street_address"))
            .and_then(Value::as_str)
            .unwrap_or_default();
        let locality = attributes
            .and_then(|attrs| attrs.get("locality"))
            .and_then(Value::as_str)
            .unwrap_or_default();
        let region = attributes
            .and_then(|attrs| attrs.get("region"))
            .and_then(Value::as_str)
            .unwrap_or_default();

        if !name.is_empty()
            && !street.is_empty()
            && !locality.is_empty()
            && !region.is_empty()
            && !country.is_empty()
        {
            return format!("{name}, {street}, {locality}, {region}, {country}");
        }
        if !name.is_empty() && !locality.is_empty() && !region.is_empty() && !country.is_empty() {
            return format!("{name}, {locality}, {region}, {country}");
        }
        if !full.is_empty() && !region.is_empty() && !country.is_empty() {
            return format!("{full}, {region}, {country}");
        }
        if !full.is_empty() && !country.is_empty() {
            return format!("{full}, {country}");
        }
        if !full.is_empty() {
            return full.to_string();
        }
        return name.to_string();
    }
    String::new()
}

fn opt_bool(matches: &ArgMatches, key: &str) -> bool {
    matches
        .try_get_one::<bool>(key)
        .ok()
        .flatten()
        .copied()
        .unwrap_or(false)
}

fn opt_string<'a>(matches: &'a ArgMatches, key: &str) -> Option<&'a str> {
    matches
        .try_get_one::<String>(key)
        .ok()
        .flatten()
        .map(String::as_str)
}

fn opt_usize(matches: &ArgMatches, key: &str) -> Option<usize> {
    matches
        .try_get_one::<String>(key)
        .ok()
        .flatten()
        .and_then(|value| value.parse::<usize>().ok())
}

fn user_query_param(by_id: bool, user: &str) -> (String, String) {
    if by_id {
        ("user_id".to_string(), user.to_string())
    } else {
        ("screen_name".to_string(), strip_at(user))
    }
}

fn bool_to_yes_no(value: Option<bool>) -> String {
    if value.unwrap_or(false) {
        "Yes".to_string()
    } else {
        "No".to_string()
    }
}

fn number_with_delimiter(number: i64, delimiter: char) -> String {
    let is_negative = number.is_negative();
    let digits = number.abs().to_string();
    let mut grouped = String::new();
    for (index, ch) in digits.chars().rev().enumerate() {
        if index > 0 && index % 3 == 0 {
            grouped.push(delimiter);
        }
        grouped.push(ch);
    }
    let mut output = grouped.chars().rev().collect::<String>();
    if is_negative {
        output.insert(0, '-');
    }
    output
}

fn pluralize(count: usize, singular: &str, plural: Option<&str>) -> String {
    if count == 1 {
        format!("{count} {singular}")
    } else {
        format!("{count} {}", plural.unwrap_or(&format!("{singular}s")))
    }
}

fn csv_row<I, S>(values: I) -> String
where
    I: IntoIterator<Item = S>,
    S: ToString,
{
    values
        .into_iter()
        .map(|value| {
            let value = value.to_string();
            if value.contains(',') || value.contains('"') || value.contains('\n') {
                format!("\"{}\"", value.replace('"', "\"\""))
            } else {
                value
            }
        })
        .collect::<Vec<_>>()
        .join(",")
}

fn strip_at(value: &str) -> String {
    value.trim_start_matches('@').to_string()
}

fn extract_mentions(text: &str) -> Vec<String> {
    let mut mentions = Vec::new();
    for token in text.split_whitespace() {
        let candidate =
            token.trim_matches(|ch: char| !ch.is_ascii_alphanumeric() && ch != '_' && ch != '@');
        if let Some(stripped) = candidate.strip_prefix('@')
            && !stripped.is_empty()
        {
            mentions.push(stripped.to_string());
        }
    }
    mentions
}

fn ensure_min_args(path: &[String], args: &[String], expected: usize) -> Result<(), CommandError> {
    if args.len() >= expected {
        return Ok(());
    }

    Err(CommandError::MissingArguments {
        command: path.join(" "),
        expected,
    })
}

fn leaf_path(matches: &ArgMatches) -> Option<(Vec<String>, &ArgMatches)> {
    let mut path = Vec::new();
    let mut current = matches;

    while let Some((name, subcommand_matches)) = current.subcommand() {
        path.push(name.to_string());
        current = subcommand_matches;
    }

    if path.is_empty() {
        None
    } else {
        Some((path, current))
    }
}

fn maybe_render_group_help_without_subcommand(
    app_spec: &crate::manifest::AppSpec,
    path: &[String],
    leaf: &ArgMatches,
    out: &mut dyn Write,
    err: &mut dyn Write,
) -> Option<i32> {
    if leaf.subcommand_name().is_some() {
        return None;
    }

    let command = command_for_path(app_spec, path)?;

    command.get_subcommands().next()?;

    let help_args = std::iter::once("x".to_string())
        .chain(path.iter().cloned())
        .chain(std::iter::once("--help".to_string()))
        .collect::<Vec<_>>();

    if let Err(parse_error) = clap_command(app_spec).try_get_matches_from(help_args) {
        let rendered = parse_error.render().to_string();
        let _ = if parse_error.use_stderr() {
            writeln!(err, "{}", rendered.trim_end())
        } else {
            writeln!(out, "{}", rendered.trim_end())
        };
        return Some(parse_error.exit_code());
    }

    Some(0)
}

fn command_for_path(app_spec: &crate::manifest::AppSpec, path: &[String]) -> Option<ClapCommand> {
    let mut command = clap_command(app_spec);

    for segment in path {
        command = command.find_subcommand(segment).cloned()?;
    }

    Some(command)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::backend::{AuthScheme, CallRecord, MockBackend};
    use serde_json::json;

    #[derive(Debug)]
    struct FailingBackend {
        error_message: String,
        calls: Vec<CallRecord>,
    }

    impl FailingBackend {
        fn new(error_message: &str) -> Self {
            Self {
                error_message: error_message.to_string(),
                calls: Vec::new(),
            }
        }

        fn fail(&self) -> BackendError {
            BackendError::Http(self.error_message.clone())
        }
    }

    impl Backend for FailingBackend {
        fn get_json(
            &mut self,
            _path: &str,
            _params: Vec<(String, String)>,
        ) -> Result<Value, BackendError> {
            Err(self.fail())
        }

        fn post_json(
            &mut self,
            _path: &str,
            _params: Vec<(String, String)>,
        ) -> Result<Value, BackendError> {
            Err(self.fail())
        }

        fn post_json_body(&mut self, _path: &str, _body: Value) -> Result<Value, BackendError> {
            Err(self.fail())
        }

        fn post_json_body_oauth2(
            &mut self,
            _path: &str,
            _body: Value,
        ) -> Result<Value, BackendError> {
            Err(self.fail())
        }

        fn delete_json(
            &mut self,
            _path: &str,
            _params: Vec<(String, String)>,
        ) -> Result<Value, BackendError> {
            Err(self.fail())
        }

        fn get_json_oauth2(
            &mut self,
            _path: &str,
            _params: Vec<(String, String)>,
        ) -> Result<Value, BackendError> {
            Err(self.fail())
        }

        fn stream_json_lines(
            &mut self,
            _path: &str,
            _params: Vec<(String, String)>,
            _auth: AuthScheme,
            _on_event: &mut dyn FnMut(Value) -> bool,
        ) -> Result<(), BackendError> {
            Err(self.fail())
        }

        fn calls(&self) -> &[CallRecord] {
            &self.calls
        }
    }

    #[test]
    fn supports_version_flag_without_subcommand() {
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_io(["x", "-v"], &mut stdout, &mut stderr);

        assert_eq!(code, 0);
        assert!(stderr.is_empty());
        let output = String::from_utf8(stdout).expect("valid utf8");
        assert_eq!(output.trim(), env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn timeline_is_wired_to_backend() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/2/users/me",
            json!({
                "data": {
                    "id": "99",
                    "username": "testcli"
                }
            }),
        );
        backend.enqueue_json_response(
            "GET",
            "/2/users/99/timelines/reverse_chronological",
            json!({
                "data": [{
                    "id": "1",
                    "created_at": "2011-04-06T19:13:37.000Z",
                    "text": "hello",
                    "author_id": "42"
                }],
                "includes": {
                    "users": [{
                        "id": "42",
                        "username": "alice"
                    }]
                }
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_backend(["x", "timeline"], &mut stdout, &mut stderr, &mut backend);

        assert_eq!(code, 0);
        assert!(stderr.is_empty());
        assert!(String::from_utf8(stdout).expect("utf8").contains("@alice"));
        assert_eq!(backend.calls()[0].path, "/2/users/me");
        assert_eq!(
            backend.calls()[1].path,
            "/2/users/99/timelines/reverse_chronological"
        );
    }

    #[test]
    fn stream_without_subcommand_prints_stream_help() {
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_io(["x", "stream"], &mut stdout, &mut stderr);

        assert_eq!(code, 0);
        assert!(stderr.is_empty());
        let output = String::from_utf8(stdout).expect("valid utf8");
        assert!(output.contains("Usage: x stream"));
        assert!(output.contains("Stream posts in real time."));
    }

    #[test]
    fn dm_event_type_normalizes_legacy_and_v2_values() {
        assert_eq!(
            dm_event_type(&json!({"type": "message_create"})),
            "messagecreate"
        );
        assert_eq!(
            dm_event_type(&json!({"event_type": "MessageCreate"})),
            "messagecreate"
        );
    }

    #[test]
    fn direct_messages_falls_back_to_v1_when_v2_dm_endpoint_is_forbidden() {
        #[derive(Debug, Default)]
        struct DmFallbackBackend {
            calls: Vec<CallRecord>,
        }

        impl Backend for DmFallbackBackend {
            fn get_json(
                &mut self,
                path: &str,
                params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                self.calls.push(CallRecord {
                    method: "GET".to_string(),
                    path: path.to_string(),
                    params,
                });
                match path {
                    "/2/dm_events" => Err(BackendError::Http("403: Forbidden".to_string())),
                    "/1.1/direct_messages/events/list.json" => Ok(json!({
                        "events": [{
                            "type": "message_create",
                            "id": "10",
                            "created_timestamp": "1493058197715",
                            "message_create": {
                                "sender_id": "2",
                                "target": { "recipient_id": "1" },
                                "message_data": { "text": "hello" }
                            }
                        }],
                        "users": {
                            "2": {
                                "id_str": "2",
                                "screen_name": "alice"
                            }
                        }
                    })),
                    "/2/users/me" => Ok(json!({
                        "data": {
                            "id": "1",
                            "username": "me"
                        }
                    })),
                    _ => Err(BackendError::MissingMockResponse {
                        method: "GET".to_string(),
                        path: path.to_string(),
                    }),
                }
            }

            fn post_json(
                &mut self,
                path: &str,
                _params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "POST".to_string(),
                    path: path.to_string(),
                })
            }

            fn post_json_body(&mut self, path: &str, _body: Value) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "POST_JSON".to_string(),
                    path: path.to_string(),
                })
            }

            fn post_json_body_oauth2(
                &mut self,
                path: &str,
                _body: Value,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "POST_JSON_OAUTH2".to_string(),
                    path: path.to_string(),
                })
            }

            fn delete_json(
                &mut self,
                path: &str,
                _params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "DELETE".to_string(),
                    path: path.to_string(),
                })
            }

            fn get_json_oauth2(
                &mut self,
                path: &str,
                _params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "GET_OAUTH2".to_string(),
                    path: path.to_string(),
                })
            }

            fn stream_json_lines(
                &mut self,
                _path: &str,
                _params: Vec<(String, String)>,
                _auth: AuthScheme,
                _on_event: &mut dyn FnMut(Value) -> bool,
            ) -> Result<(), BackendError> {
                Ok(())
            }

            fn calls(&self) -> &[CallRecord] {
                &self.calls
            }
        }

        let mut backend = DmFallbackBackend::default();
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_backend(
            ["x", "direct_messages", "--csv"],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0, "stderr was: {}", String::from_utf8_lossy(&stderr));
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("ID,Posted at,Screen name,Text"));
        assert!(output.contains(",alice,hello"));
        assert!(
            backend
                .calls()
                .iter()
                .any(|call| call.path == "/2/dm_events")
        );
        assert!(
            backend
                .calls()
                .iter()
                .any(|call| call.path == "/1.1/direct_messages/events/list.json")
        );
    }

    #[test]
    fn matrix_streams_from_filtered_stream() {
        let mut backend = MockBackend::new();
        // clear_filtered_stream_rules: GET existing rules (none)
        backend.enqueue_json_response(
            "GET_OAUTH2",
            "/2/tweets/search/stream/rules",
            json!({"data": []}),
        );
        // install_filtered_stream_rules: POST to rules endpoint, returns rule ID
        backend.enqueue_json_response(
            "POST_JSON_OAUTH2",
            "/2/tweets/search/stream/rules",
            json!({"data": [{"id": "rule-1", "value": "の lang:ja"}]}),
        );
        // Stream events from filtered stream
        backend.enqueue_stream_events(
            "/2/tweets/search/stream",
            AuthScheme::OAuth2Bearer,
            vec![json!({"data": {"id": "1", "text": "abcあいう"}})],
        );
        // remove_filtered_stream_rules: POST to rules endpoint to delete
        backend.enqueue_json_response(
            "POST_JSON_OAUTH2",
            "/2/tweets/search/stream/rules",
            json!({}),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(["x", "matrix"], &mut stdout, &mut stderr, &mut backend);

        assert_eq!(code, 0, "stderr was: {}", String::from_utf8_lossy(&stderr));
        assert_eq!(
            String::from_utf8(stdout).expect("utf8"),
            "\x1b[1;32;40mういあ\x1b[0m"
        );
        assert!(
            backend
                .calls()
                .iter()
                .any(|call| call.method == "STREAM" && call.path == "/2/tweets/search/stream")
        );
    }

    #[test]
    fn prints_hint_for_429_errors() {
        let mut backend = FailingBackend::new("429: Too Many Requests");
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_backend(["x", "timeline"], &mut stdout, &mut stderr, &mut backend);

        assert_eq!(code, 1);
        let output = String::from_utf8(stderr).expect("utf8");
        assert!(
            output.contains("Too Many Requests"),
            "error message should appear: {output}"
        );
        assert!(output.contains("Hint: X API rate limit reached."));
    }

    #[test]
    fn does_not_print_hint_for_403_errors() {
        let mut backend = FailingBackend::new("403: Forbidden");
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_backend(["x", "timeline"], &mut stdout, &mut stderr, &mut backend);

        assert_eq!(code, 1);
        let output = String::from_utf8(stderr).expect("utf8");
        assert!(
            output.contains("Forbidden"),
            "error message should appear: {output}"
        );
        assert!(!output.contains("Hint:"));
    }

    #[test]
    fn extract_users_handles_bare_v1_user_object() {
        let bare_user = json!({
            "id": 12345,
            "id_str": "12345",
            "screen_name": "testuser",
            "name": "Test User",
            "location": "Earth",
            "description": "A test account"
        });

        let users = extract_users(&bare_user);

        assert_eq!(users.len(), 1);
        assert_eq!(users[0]["screen_name"], "testuser");
        assert_eq!(users[0]["id"], 12345);
    }

    #[test]
    fn extract_users_handles_bare_v1_user_with_only_id() {
        let bare_user = json!({
            "id": 99,
            "id_str": "99"
        });

        let users = extract_users(&bare_user);

        assert_eq!(users.len(), 1);
        assert_eq!(users[0]["id"], 99);
    }

    #[test]
    fn extract_users_handles_bare_v1_user_with_only_screen_name() {
        let bare_user = json!({
            "screen_name": "alice"
        });

        let users = extract_users(&bare_user);

        assert_eq!(users.len(), 1);
        assert_eq!(users[0]["screen_name"], "alice");
    }

    #[test]
    fn extract_users_returns_empty_for_unrecognized_object() {
        let unknown = json!({
            "some_unrelated_key": "value"
        });

        let users = extract_users(&unknown);

        assert!(users.is_empty());
    }

    #[test]
    fn fetch_current_user_falls_back_to_v1_on_503() {
        #[derive(Debug, Default)]
        struct V2UnavailableBackend {
            calls: Vec<CallRecord>,
        }

        impl Backend for V2UnavailableBackend {
            fn get_json(
                &mut self,
                path: &str,
                params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                self.calls.push(CallRecord {
                    method: "GET".to_string(),
                    path: path.to_string(),
                    params,
                });
                match path {
                    "/2/users/me" => {
                        Err(BackendError::Http("503: Service Unavailable".to_string()))
                    }
                    "/1.1/account/verify_credentials.json" => Ok(json!({
                        "id": 42,
                        "id_str": "42",
                        "screen_name": "fallbackuser",
                        "name": "Fallback User"
                    })),
                    _ => Err(BackendError::MissingMockResponse {
                        method: "GET".to_string(),
                        path: path.to_string(),
                    }),
                }
            }

            fn post_json(
                &mut self,
                path: &str,
                _params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "POST".to_string(),
                    path: path.to_string(),
                })
            }

            fn post_json_body(&mut self, path: &str, _body: Value) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "POST_JSON".to_string(),
                    path: path.to_string(),
                })
            }

            fn post_json_body_oauth2(
                &mut self,
                path: &str,
                _body: Value,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "POST_JSON_OAUTH2".to_string(),
                    path: path.to_string(),
                })
            }

            fn delete_json(
                &mut self,
                path: &str,
                _params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "DELETE".to_string(),
                    path: path.to_string(),
                })
            }

            fn get_json_oauth2(
                &mut self,
                path: &str,
                _params: Vec<(String, String)>,
            ) -> Result<Value, BackendError> {
                Err(BackendError::MissingMockResponse {
                    method: "GET_OAUTH2".to_string(),
                    path: path.to_string(),
                })
            }

            fn stream_json_lines(
                &mut self,
                _path: &str,
                _params: Vec<(String, String)>,
                _auth: AuthScheme,
                _on_event: &mut dyn FnMut(Value) -> bool,
            ) -> Result<(), BackendError> {
                Ok(())
            }

            fn calls(&self) -> &[CallRecord] {
                &self.calls
            }
        }

        let mut backend = V2UnavailableBackend::default();
        let user = fetch_current_user(&mut backend).expect("should fall back to v1.1");

        assert_eq!(user["screen_name"], "fallbackuser");
        assert_eq!(
            backend.calls().len(),
            // 3 retries for /2/users/me (all fail with 503) +
            // 1 for /1.1/account/verify_credentials.json (succeeds first try)
            3 + 1,
            "calls: {:?}",
            backend.calls()
        );
        assert!(
            backend
                .calls()
                .iter()
                .any(|call| call.path == "/2/users/me"),
            "v2 endpoint should be attempted"
        );
        assert!(
            backend
                .calls()
                .iter()
                .any(|call| call.path == "/1.1/account/verify_credentials.json"),
            "v1.1 fallback should be attempted"
        );
    }

    #[test]
    fn fetch_current_user_does_not_fall_back_on_non_503_errors() {
        let mut backend = FailingBackend::new("401: Unauthorized");
        let result = fetch_current_user(&mut backend);

        assert!(result.is_err());
        let error_msg = format!("{}", result.unwrap_err());
        assert!(
            error_msg.contains("401:"),
            "error should propagate: {error_msg}"
        );
    }

    #[test]
    fn error_messages_with_body_are_surfaced_to_stderr() {
        let mut backend = FailingBackend::new("429: Rate limit exceeded");
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_backend(["x", "timeline"], &mut stdout, &mut stderr, &mut backend);

        assert_eq!(code, 1);
        let output = String::from_utf8(stderr).expect("utf8");
        assert!(
            output.contains("Rate limit exceeded"),
            "parsed message should appear in error: {output}"
        );
        assert!(
            output.contains("Hint: X API rate limit reached."),
            "429 hint should still be triggered: {output}"
        );
    }

    #[test]
    fn format_error_for_display_strips_status_code_prefix() {
        let error = CommandError::Backend(BackendError::Http(
            "402: CreditsDepleted: Account out of credits".to_string(),
        ));
        let displayed = format_error_for_display(&error);
        assert_eq!(displayed, "CreditsDepleted: Account out of credits");
    }

    #[test]
    fn format_error_for_display_passes_through_non_http_errors() {
        let error = CommandError::Backend(BackendError::Http("connection refused".to_string()));
        let displayed = format_error_for_display(&error);
        assert_eq!(displayed, "connection refused");
    }

    #[test]
    fn extract_geo_places_from_result() {
        let response = json!({
            "result": {
                "places": [
                    {"id": "abc", "name": "Place A", "full_name": "Place A, US", "place_type": "city", "country": "United States"},
                    {"id": "def", "name": "Place B", "full_name": "Place B, US", "place_type": "neighborhood", "country": "United States"}
                ]
            }
        });
        let places = extract_geo_places(&response);
        assert_eq!(places.len(), 2);
        assert_eq!(places[0]["id"], "abc");
        assert_eq!(places[1]["id"], "def");
    }

    #[test]
    fn extract_geo_places_handles_missing_result() {
        let response = json!({});
        let places = extract_geo_places(&response);
        assert!(places.is_empty());
    }

    #[test]
    fn resolve_geo_coordinates_parses_lat_lng() {
        let args = vec!["37.7697,-122.3933".to_string()];
        let (lat, lng) = resolve_geo_coordinates(&args).unwrap();
        assert!((lat - 37.7697).abs() < 0.001);
        assert!((lng - (-122.3933)).abs() < 0.001);
    }

    #[test]
    fn place_command_wired_to_backend() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/geo/id/test123.json",
            json!({
                "id": "test123",
                "place_type": "city",
                "name": "Test City",
                "full_name": "Test City, TS",
                "country": "Test Country",
                "country_code": "TC"
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            ["x", "place", "test123", "--profile", &profile_path()],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("test123"));
        assert!(output.contains("Test City, TS"));
    }

    #[test]
    fn collection_create_calls_v1_api() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "POST",
            "/1.1/collections/create.json",
            json!({"response": {"timeline_id": "custom-123"}}),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "create",
                "My Collection",
                "A test collection",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        assert_eq!(backend.calls()[0].path, "/1.1/collections/create.json");
        assert!(
            backend.calls()[0]
                .params
                .contains(&("name".to_string(), "My Collection".to_string()))
        );
        assert!(
            backend.calls()[0]
                .params
                .contains(&("description".to_string(), "A test collection".to_string()))
        );
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("created the collection"));
    }

    #[test]
    fn collection_add_calls_entries_add() {
        let mut backend = MockBackend::new();
        // Enqueue for resolve_collection_id -> fetch_user_collections
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/list.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-999": {"name": "My Coll"}
                    }
                },
                "response": {
                    "results": [{"timeline_id": "custom-999"}],
                    "cursors": {}
                }
            }),
        );
        backend.enqueue_json_response(
            "POST",
            "/1.1/collections/entries/add.json",
            json!({"response": {"errors": []}}),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "add",
                "--id",
                "custom-999",
                "12345",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        assert_eq!(backend.calls()[0].path, "/1.1/collections/entries/add.json");
        assert!(
            backend.calls()[0]
                .params
                .contains(&("tweet_id".to_string(), "12345".to_string()))
        );
    }

    #[test]
    fn collection_entries_extracts_v1_tweets() {
        let response = json!({
            "objects": {
                "tweets": {
                    "111": {
                        "id_str": "111",
                        "text": "Hello world",
                        "created_at": "Mon Apr 06 19:13:37 +0000 2011",
                        "user": {"id_str": "42"}
                    }
                },
                "users": {
                    "42": {
                        "id_str": "42",
                        "screen_name": "alice"
                    }
                }
            },
            "response": {
                "timeline": [
                    {"tweet": {"id": "111", "sort_index": "0"}}
                ],
                "position": {"min_position": "0", "max_position": "0", "was_truncated": false}
            }
        });

        let tweets = extract_collection_entries(&response);
        assert_eq!(tweets.len(), 1);
        assert_eq!(tweets[0].get("id_str").and_then(Value::as_str), Some("111"));
        assert_eq!(
            tweets[0].get("text").and_then(Value::as_str),
            Some("Hello world")
        );
    }

    #[test]
    fn collections_lists_user_collections() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/list.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-100": {"name": "First Collection", "description": "desc1"},
                        "custom-200": {"name": "Second Collection", "description": "desc2"}
                    }
                },
                "response": {
                    "results": [
                        {"timeline_id": "custom-100"},
                        {"timeline_id": "custom-200"}
                    ],
                    "cursors": {}
                }
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collections",
                "--id",
                "99",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("First Collection"));
        assert!(output.contains("Second Collection"));
        assert_eq!(backend.calls()[0].path, "/1.1/collections/list.json");
    }

    #[test]
    fn collection_without_subcommand_prints_help() {
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();

        let code = run_with_io(["x", "collection"], &mut stdout, &mut stderr);

        assert_eq!(code, 0);
        assert!(stderr.is_empty());
        let output = String::from_utf8(stdout).expect("valid utf8");
        assert!(output.contains("collection"));
    }

    #[test]
    fn delete_collection_calls_destroy() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "POST",
            "/1.1/collections/destroy.json",
            json!({"destroyed": true}),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "delete",
                "collection",
                "--id",
                "custom-123",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        assert_eq!(backend.calls()[0].path, "/1.1/collections/destroy.json");
        assert!(
            backend.calls()[0]
                .params
                .contains(&("id".to_string(), "custom-123".to_string()))
        );
    }

    #[test]
    fn collection_entries_command_wired_to_backend() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/entries.json",
            json!({
                "objects": {
                    "tweets": {
                        "555": {
                            "id_str": "555",
                            "text": "Hello from collection",
                            "created_at": "Mon Apr 06 19:13:37 +0000 2011",
                            "user": {"id_str": "42"}
                        }
                    },
                    "users": {
                        "42": {"id_str": "42", "screen_name": "alice"}
                    }
                },
                "response": {
                    "timeline": [{"tweet": {"id": "555", "sort_index": "0"}}],
                    "position": {"min_position": "0", "max_position": "0", "was_truncated": false}
                }
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "entries",
                "--id",
                "custom-999",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        assert_eq!(backend.calls()[0].path, "/1.1/collections/entries.json");
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("Hello from collection"));
    }

    #[test]
    fn collection_information_command_wired_to_backend() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/show.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-777": {
                            "name": "My Timeline",
                            "description": "A great collection",
                            "collection_url": "https://x.com/test/timelines/777",
                            "timeline_order": "curation_reverse_chron",
                            "visibility": "public"
                        }
                    }
                },
                "response": {"timeline_id": "custom-777"}
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "information",
                "--id",
                "custom-777",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        assert_eq!(backend.calls()[0].path, "/1.1/collections/show.json");
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("My Timeline"));
        assert!(output.contains("A great collection"));
    }

    #[test]
    fn collection_information_csv_mode() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/show.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-777": {
                            "name": "My Timeline",
                            "description": "desc",
                            "collection_url": "https://x.com/test/timelines/777",
                            "timeline_order": "curation_reverse_chron",
                            "visibility": "public"
                        }
                    }
                },
                "response": {"timeline_id": "custom-777"}
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "information",
                "--id",
                "custom-777",
                "--csv",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("ID,Name,Description"));
        assert!(output.contains("My Timeline"));
    }

    #[test]
    fn collection_remove_calls_entries_remove() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "POST",
            "/1.1/collections/entries/remove.json",
            json!({"response": {"errors": []}}),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "remove",
                "--id",
                "custom-999",
                "12345",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        assert_eq!(
            backend.calls()[0].path,
            "/1.1/collections/entries/remove.json"
        );
        assert!(
            backend.calls()[0]
                .params
                .contains(&("tweet_id".to_string(), "12345".to_string()))
        );
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("removed"));
    }

    #[test]
    fn collection_update_calls_update_endpoint() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "POST",
            "/1.1/collections/update.json",
            json!({"response": {"timeline_id": "custom-999"}}),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "update",
                "--id",
                "custom-999",
                "--name",
                "New Name",
                "--description",
                "New Desc",
                "--url",
                "https://example.com",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        assert_eq!(backend.calls()[0].path, "/1.1/collections/update.json");
        assert!(
            backend.calls()[0]
                .params
                .contains(&("name".to_string(), "New Name".to_string()))
        );
        assert!(
            backend.calls()[0]
                .params
                .contains(&("description".to_string(), "New Desc".to_string()))
        );
        assert!(
            backend.calls()[0]
                .params
                .contains(&("url".to_string(), "https://example.com".to_string()))
        );
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("updated"));
    }

    #[test]
    fn collections_csv_mode() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/list.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-100": {"name": "Coll A", "description": "d1", "collection_url": "https://x.com/a"}
                    }
                },
                "response": {
                    "results": [{"timeline_id": "custom-100"}],
                    "cursors": {}
                }
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collections",
                "--id",
                "99",
                "--csv",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("ID,Name,Description,URL"));
        assert!(output.contains("Coll A"));
    }

    #[test]
    fn collections_long_mode() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/list.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-100": {"name": "Coll A", "description": "d1"}
                    }
                },
                "response": {
                    "results": [{"timeline_id": "custom-100"}],
                    "cursors": {}
                }
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collections",
                "--id",
                "99",
                "--long",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        let output = String::from_utf8(stdout).expect("utf8");
        assert!(output.contains("Coll A"));
        assert!(output.contains("ID"));
    }

    #[test]
    fn collections_reverse_mode() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/list.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-100": {"name": "AAA", "description": ""},
                        "custom-200": {"name": "ZZZ", "description": ""}
                    }
                },
                "response": {
                    "results": [
                        {"timeline_id": "custom-100"},
                        {"timeline_id": "custom-200"}
                    ],
                    "cursors": {}
                }
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collections",
                "--id",
                "99",
                "--reverse",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        let output = String::from_utf8(stdout).expect("utf8");
        let aaa_pos = output.find("AAA").unwrap();
        let zzz_pos = output.find("ZZZ").unwrap();
        assert!(
            zzz_pos < aaa_pos,
            "ZZZ should appear before AAA when reversed"
        );
    }

    #[test]
    fn resolve_collection_id_by_name() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/list.json",
            json!({
                "objects": {
                    "timelines": {
                        "custom-42": {"name": "My Coll"}
                    }
                },
                "response": {
                    "results": [{"timeline_id": "custom-42"}],
                    "cursors": {}
                }
            }),
        );
        // Add the entries response for the actual command
        backend.enqueue_json_response(
            "GET",
            "/1.1/collections/entries.json",
            json!({
                "objects": {"tweets": {}, "users": {}},
                "response": {
                    "timeline": [],
                    "position": {"min_position": "0", "max_position": "0", "was_truncated": false}
                }
            }),
        );

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let code = run_with_backend(
            [
                "x",
                "collection",
                "entries",
                "My Coll",
                "--profile",
                &profile_path(),
            ],
            &mut stdout,
            &mut stderr,
            &mut backend,
        );

        assert_eq!(code, 0);
        // First call resolves the name via collections/list
        assert_eq!(backend.calls()[0].path, "/1.1/collections/list.json");
        // Second call fetches entries with the resolved ID
        assert_eq!(backend.calls()[1].path, "/1.1/collections/entries.json");
        assert!(
            backend.calls()[1]
                .params
                .contains(&("id".to_string(), "custom-42".to_string()))
        );
    }

    fn profile_path() -> String {
        format!("{}/legacy/test/fixtures/.trc", env!("CARGO_MANIFEST_DIR"))
    }
}
