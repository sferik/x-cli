use serde_json::Value;
use std::fs;
use x::backend::{AuthScheme, Backend, MockBackend};
use x::run_with_backend;

fn fixture_path(name: &str) -> String {
    format!("{}/legacy/test/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

fn fixture_json(name: &str) -> Value {
    let content = std::fs::read_to_string(fixture_path(name)).expect("fixture should be readable");
    serde_json::from_str(&content).expect("fixture should be valid json")
}

fn trc_path() -> String {
    fixture_path(".trc")
}

fn me_fixture() -> Value {
    serde_json::json!({
        "data": {
            "id": "7505382",
            "username": "testcli"
        }
    })
}

fn run_cmd(args: &[&str], backend: &mut MockBackend) -> (i32, String, String) {
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let argv = std::iter::once("x")
        .chain(args.iter().copied())
        .map(str::to_string)
        .collect::<Vec<_>>();

    let code = run_with_backend(argv, &mut stdout, &mut stderr, backend);
    (
        code,
        String::from_utf8(stdout).expect("stdout should be utf8"),
        String::from_utf8(stderr).expect("stderr should be utf8"),
    )
}

fn run_cmd_with_profile(args: &[&str], backend: &mut MockBackend) -> (i32, String, String) {
    let profile = trc_path();
    let mut argv = args.to_vec();
    argv.extend(["--profile", profile.as_str()]);
    run_cmd(&argv, backend)
}

fn assert_success(code: i32, err: &str) {
    assert_eq!(code, 0, "stderr was: {err}");
}

#[test]
fn timeline_csv_matches_legacy_header_and_first_row() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response("GET", "/2/users/me", me_fixture());
    backend.enqueue_json_response(
        "GET",
        "/2/users/7505382/timelines/reverse_chronological",
        fixture_json("statuses.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["timeline", "--csv"], &mut backend);

    assert_success(code, &err);
    let expected = [
        "ID,Posted at,Screen name,Text",
        "4611686018427387904,2012-09-07 16:35:24 +0000,mutgoff,Happy Birthday @imdane. Watch out for those @rally pranksters!",
    ]
    .join("\n");
    assert!(
        out.starts_with(&expected),
        "output did not match expected prefix: {out}"
    );
}

#[test]
fn timeline_decode_uris_contains_expanded_urls_like_legacy() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response("GET", "/2/users/me", me_fixture());
    backend.enqueue_json_response(
        "GET",
        "/2/users/7505382/timelines/reverse_chronological",
        fixture_json("statuses.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["timeline", "--decode_uris"], &mut backend);

    assert_success(code, &err);
    assert!(
        out.contains("https://twitter.com/sferik/status/243988000076337152"),
        "decoded output did not contain expanded url"
    );
}

#[test]
fn search_all_prefers_oauth2_backend() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/tweets/search/recent",
        fixture_json("search.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["search", "all", "house", "--csv"], &mut backend);

    assert_success(code, &err);
    assert!(out.contains("ID,Posted at,Screen name,Text"));
    assert!(
        backend
            .calls()
            .iter()
            .any(|call| call.method == "GET_OAUTH2" && call.path == "/2/tweets/search/recent")
    );
}

#[test]
fn users_csv_matches_legacy_rows() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response("GET_OAUTH2", "/2/users/by", fixture_json("users.json"));

    let (code, out, err) =
        run_cmd_with_profile(&["users", "sferik", "pengwynn", "--csv"], &mut backend);

    assert_success(code, &err);
    assert!(out.contains("ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL"));
    assert!(out.contains("14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn"));
    assert!(out.contains(
        "7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik"
    ));
}

#[test]
fn status_csv_matches_legacy_snapshot() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/tweets/55709764298092545",
        fixture_json("status.json"),
    );

    let (code, out, err) =
        run_cmd_with_profile(&["status", "55709764298092545", "--csv"], &mut backend);

    assert_success(code, &err);
    let expected = [
        "ID,Posted at,Screen name,Text,Retweets,Favorites,Source,Location",
        "55709764298092545,2011-04-06 19:13:37 +0000,sferik,The problem with your code is that it's doing exactly what you told it to do.,320,50,Twitter for iPhone,\"Blowfish Sushi To Die For, 2170 Bryant St, San Francisco, California, United States\"",
    ]
    .join("\n");
    assert_eq!(out.trim_end(), expected);
}

#[test]
fn status_default_format_uses_column_layout_like_legacy() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/tweets/55709764298092545",
        fixture_json("status.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["status", "55709764298092545"], &mut backend);

    assert_success(code, &err);
    // Ruby output uses left-aligned labels padded to max width + 2 spaces gap:
    // ID           55709764298092545
    // Text         The problem with your code...
    // Screen name  @sferik
    // Posted at    Apr  6  2011 (X ago)
    // Retweets     320
    // Favorites    50
    // Source       Twitter for iPhone
    // Location     Blowfish Sushi To Die For, ...
    assert!(
        out.contains("ID           55709764298092545"),
        "ID row missing: {out}"
    );
    assert!(
        out.contains("Screen name  @sferik"),
        "Screen name row missing: {out}"
    );
    assert!(
        out.contains("Retweets     320"),
        "Retweets row missing: {out}"
    );
    assert!(
        out.contains("Favorites    50"),
        "Favorites row missing: {out}"
    );
    assert!(
        out.contains("Source       Twitter for iPhone"),
        "Source row missing: {out}"
    );
    assert!(
        out.contains("Location     Blowfish Sushi To Die For"),
        "Location row missing: {out}"
    );
    // Posted at should contain absolute date + relative time in parentheses
    assert!(
        out.contains("Posted at    "),
        "Posted at row missing: {out}"
    );
    assert!(
        out.contains("ago)"),
        "Posted at should contain relative time: {out}"
    );
    // Should NOT use colon format
    assert!(!out.contains("ID: "), "Should not use colon format: {out}");
}

#[test]
fn whois_default_format_uses_column_layout_with_last_update() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users/by/username/sferik",
        fixture_json("v2/sferik.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["whois", "sferik"], &mut backend);

    assert_success(code, &err);
    // Ruby output:
    // ID           7505382
    // Since        Jul 16  2007 (X ago)
    // Last update  @goldman You're near my home town! ... (X ago)
    // Screen name  @sferik
    // Name         Erik Michaels-Ober
    // Tweets       7,890
    // Favorites    3,755
    // Listed       118
    // Following    212
    // Followers    2,262
    // Bio          Vagabond.
    // Location     San Francisco
    // URL          https://github.com/sferik
    assert!(
        out.contains("ID           7505382"),
        "ID row missing: {out}"
    );
    assert!(
        out.contains("Screen name  @sferik"),
        "Screen name row missing: {out}"
    );
    assert!(
        out.contains("Name         Erik Michaels-Ober"),
        "Name row missing: {out}"
    );
    assert!(
        out.contains("Tweets       7,890"),
        "Tweets row missing: {out}"
    );
    assert!(
        out.contains("Favorites    3,755"),
        "Favorites row missing: {out}"
    );
    assert!(
        out.contains("Listed       118"),
        "Listed row missing: {out}"
    );
    assert!(
        out.contains("Following    212"),
        "Following row missing: {out}"
    );
    assert!(
        out.contains("Followers    2,262"),
        "Followers row missing: {out}"
    );
    assert!(
        out.contains("Bio          Vagabond."),
        "Bio row missing: {out}"
    );
    assert!(
        out.contains("Location     San Francisco"),
        "Location row missing: {out}"
    );
    assert!(
        out.contains("URL          https://github.com/sferik"),
        "URL row missing: {out}"
    );
    // Last update field should be present (from pinned tweet)
    assert!(
        out.contains("Last update  "),
        "Last update row missing: {out}"
    );
    assert!(
        out.contains("You're near my home town"),
        "Last update should contain tweet text: {out}"
    );
    // Since should contain relative time
    assert!(out.contains("Since        "), "Since row missing: {out}");
    assert!(out.contains("ago)"), "Should contain relative time: {out}");
    // Should NOT use colon format
    assert!(!out.contains("ID: "), "Should not use colon format: {out}");
}

#[test]
fn whois_no_status_excludes_last_update() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users/by/username/sferik",
        fixture_json("v2/user_no_status.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["whois", "sferik"], &mut backend);

    assert_success(code, &err);
    assert!(
        out.contains("ID           7505382"),
        "ID row missing: {out}"
    );
    assert!(
        !out.contains("Last update"),
        "Last update should not appear without status: {out}"
    );
}

#[test]
fn whois_verified_user_shows_name_verified_label() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users/by/username/sferik",
        fixture_json("v2/user_verified.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["whois", "sferik"], &mut backend);

    assert_success(code, &err);
    assert!(
        out.contains("Name (Verified)"),
        "Verified label should appear: {out}"
    );
}

#[test]
fn direct_messages_csv_matches_legacy_prefix() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET",
        "/2/dm_events",
        fixture_json("direct_message_events.json"),
    );
    backend.enqueue_json_response("GET", "/2/users/me", me_fixture());
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users",
        fixture_json("direct_message_users.json"),
    );

    let (code, out, err) = run_cmd_with_profile(&["direct_messages", "--csv"], &mut backend);

    assert_success(code, &err);
    assert!(out.contains("ID,Posted at,Screen name,Text"));
}

#[test]
fn trends_and_trend_locations_match_legacy_values() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/trends/by/woeid/1",
        serde_json::json!({
            "data": [
                { "trend_name": "#sevenwordsaftersex", "tweet_count": 1 },
                { "trend_name": "Walkman", "tweet_count": 1 },
                { "trend_name": "Allen Iverson", "tweet_count": 1 }
            ]
        }),
    );
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/1.1/trends/available.json",
        fixture_json("locations.json"),
    );

    let (code_trends, out_trends, err_trends) = run_cmd_with_profile(&["trends"], &mut backend);
    assert_success(code_trends, &err_trends);
    assert!(out_trends.contains("#sevenwordsaftersex"));
    assert!(out_trends.contains("Walkman"));
    assert!(out_trends.contains("Allen Iverson"));

    let (code_locations, out_locations, err_locations) =
        run_cmd_with_profile(&["trend_locations", "--csv"], &mut backend);
    assert_success(code_locations, &err_locations);
    assert_eq!(
        out_locations.trim_end(),
        [
            "WOEID,Parent ID,Type,Name,Country",
            "2487956,23424977,Town,San Francisco,United States",
            "1587677,23424942,Unknown,Soweto,South Africa",
            "23424977,1,Country,United States,United States",
            "1,0,Supername,Worldwide,",
        ]
        .join("\n")
    );
}

#[test]
fn set_and_delete_subcommands_preserve_legacy_messages() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "POST",
        "/1.1/account/update_profile.json",
        serde_json::json!({}),
    );
    backend.enqueue_json_response("GET", "/2/users/me", me_fixture());
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users/by/username/sferik",
        serde_json::json!({
            "data": { "id": "7505382", "username": "sferik" }
        }),
    );
    backend.enqueue_json_response(
        "DELETE",
        "/2/users/7505382/blocking/7505382",
        serde_json::json!({ "data": { "blocking": false } }),
    );

    let (set_code, set_out, set_err) =
        run_cmd_with_profile(&["set", "bio", "Vagabond."], &mut backend);
    assert_success(set_code, &set_err);
    assert_eq!(set_out.trim_end(), "@testcli's bio has been updated.");

    let (delete_code, delete_out, delete_err) =
        run_cmd_with_profile(&["delete", "block", "sferik"], &mut backend);
    assert_success(delete_code, &delete_err);
    assert!(delete_out.starts_with("@testcli unblocked 1 user."));
}

#[test]
fn list_and_search_subcommands_are_fixture_driven() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users/by/username/sferik",
        serde_json::json!({
            "data": {
                "id": "7505382",
                "username": "sferik"
            }
        }),
    );
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users/7505382/owned_lists",
        serde_json::json!({
            "data": [{
                "id": "8863586",
                "name": "presidents",
                "owner_id": "7505382",
                "member_count": 2,
                "follower_count": 3,
                "private": false
            }]
        }),
    );
    backend.enqueue_json_response("GET_OAUTH2", "/2/lists/8863586", fixture_json("list.json"));
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/tweets/search/recent",
        fixture_json("search.json"),
    );

    let (list_code, list_out, list_err) =
        run_cmd_with_profile(&["list", "information", "sferik/presidents"], &mut backend);
    assert_success(list_code, &list_err);
    assert!(list_out.contains("ID: 8863586"));
    assert!(list_out.contains("Slug: presidents"));

    let (search_code, search_out, search_err) =
        run_cmd_with_profile(&["search", "all", "house", "--csv"], &mut backend);
    assert_success(search_code, &search_err);
    assert!(search_out.contains("ID,Posted at,Screen name,Text"));
    assert!(search_out.contains("RT @heartCOBOYJR"));
}

#[test]
fn stream_subcommand_streams_events() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response("GET", "/2/users/me", me_fixture());
    backend.enqueue_json_response(
        "GET_OAUTH2",
        "/2/users/7505382/following",
        fixture_json("friends_ids.json"),
    );
    backend.enqueue_json_response(
        "POST_JSON_OAUTH2",
        "/2/tweets/search/stream/rules",
        serde_json::json!({
            "data": [
                { "id": "rule-1", "value": "from:14100886", "tag": "t-rust-test" }
            ]
        }),
    );
    let stream_events = fixture_json("statuses.json")
        .as_array()
        .cloned()
        .expect("statuses fixture should be array")
        .into_iter()
        .take(2)
        .collect::<Vec<_>>();
    backend.enqueue_stream_events(
        "/2/tweets/search/stream",
        AuthScheme::OAuth2Bearer,
        stream_events,
    );
    backend.enqueue_json_response(
        "POST_JSON_OAUTH2",
        "/2/tweets/search/stream/rules",
        serde_json::json!({"meta":{"summary":{"deleted":1}}}),
    );

    let (code, out, err) = run_cmd_with_profile(&["stream", "timeline", "--csv"], &mut backend);

    assert_success(code, &err);
    assert!(out.contains("ID,Posted at,Screen name,Text"));
    assert!(out.contains("mutgoff"));
}

#[test]
fn update_with_file_uploads_media_before_creating_tweet() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "POST",
        "/1.1/media/upload.json",
        serde_json::json!({"media_id_string":"999"}),
    );
    backend.enqueue_json_response(
        "POST_JSON",
        "/2/tweets",
        serde_json::json!({"data":{"id":"42"}}),
    );

    let file_path = std::env::temp_dir().join("t-media-upload-test.txt");
    fs::write(&file_path, "hello media").expect("test media file should be written");

    let file_arg = file_path
        .to_str()
        .expect("temp path should be valid utf8")
        .to_string();
    let (code, _out, err) =
        run_cmd_with_profile(&["update", "hello", "--file", &file_arg], &mut backend);

    assert_success(code, &err);
    assert!(
        backend
            .calls()
            .iter()
            .any(|call| call.method == "POST" && call.path == "/1.1/media/upload.json")
    );
    let tweet_call = backend
        .calls()
        .iter()
        .find(|call| call.method == "POST_JSON" && call.path == "/2/tweets")
        .expect("tweet create call should be present");
    let payload = serde_json::from_str::<Value>(&tweet_call.params[0].1)
        .expect("tweet payload should be valid json");
    assert_eq!(
        payload
            .get("media")
            .and_then(|media| media.get("media_ids"))
            .and_then(Value::as_array)
            .and_then(|ids| ids.first())
            .and_then(Value::as_str),
        Some("999")
    );
}

#[test]
fn timeline_paginates_when_number_exceeds_single_page() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response("GET", "/2/users/me", me_fixture());
    backend.enqueue_json_response(
        "GET",
        "/2/users/7505382/timelines/reverse_chronological",
        paged_tweets(1, 100, Some("next-page")),
    );
    backend.enqueue_json_response(
        "GET",
        "/2/users/7505382/timelines/reverse_chronological",
        paged_tweets(101, 60, None),
    );

    let (code, out, err) =
        run_cmd_with_profile(&["timeline", "--number", "150", "--csv"], &mut backend);

    assert_success(code, &err);
    assert_eq!(out.lines().count(), 151);

    let timeline_calls = backend
        .calls()
        .iter()
        .filter(|call| call.path == "/2/users/7505382/timelines/reverse_chronological")
        .collect::<Vec<_>>();
    assert_eq!(timeline_calls.len(), 2);
    assert!(
        timeline_calls[1]
            .params
            .iter()
            .any(|(key, value)| key == "pagination_token" && value == "next-page")
    );
}

#[test]
fn stream_search_uses_v2_filtered_stream_rules_lifecycle() {
    let mut backend = MockBackend::new();
    backend.enqueue_json_response(
        "POST_JSON_OAUTH2",
        "/2/tweets/search/stream/rules",
        serde_json::json!({
            "data": [{ "id": "rule-search-1", "value": "rust OR ruby", "tag": "test" }]
        }),
    );
    backend.enqueue_stream_events(
        "/2/tweets/search/stream",
        AuthScheme::OAuth2Bearer,
        vec![serde_json::json!({
            "data": {
                "id": "1",
                "author_id": "100",
                "text": "hello rust",
                "created_at": "2012-09-07T16:35:24Z"
            },
            "includes": {
                "users": [{ "id": "100", "username": "alice" }]
            }
        })],
    );
    backend.enqueue_json_response(
        "POST_JSON_OAUTH2",
        "/2/tweets/search/stream/rules",
        serde_json::json!({"meta":{"summary":{"deleted":1}}}),
    );

    let (code, out, err) =
        run_cmd_with_profile(&["stream", "search", "rust", "ruby", "--csv"], &mut backend);

    assert_success(code, &err);
    assert!(out.contains("ID,Posted at,Screen name,Text"));

    let calls = backend.calls();
    assert_eq!(calls[0].method, "POST_JSON_OAUTH2");
    assert_eq!(calls[0].path, "/2/tweets/search/stream/rules");
    assert_eq!(calls[1].method, "STREAM");
    assert_eq!(calls[1].path, "/2/tweets/search/stream");
    assert_eq!(calls[2].method, "POST_JSON_OAUTH2");
    assert_eq!(calls[2].path, "/2/tweets/search/stream/rules");

    let add_payload = serde_json::from_str::<Value>(&calls[0].params[0].1)
        .expect("rule add payload should be valid json");
    let first_rule = add_payload
        .get("add")
        .and_then(Value::as_array)
        .and_then(|rules| rules.first())
        .and_then(|rule| rule.get("value"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    assert!(
        first_rule.contains("rust") && first_rule.contains("ruby"),
        "rule value should include both terms: {first_rule}"
    );
}

fn paged_tweets(start: u64, count: usize, next_token: Option<&str>) -> Value {
    let data = (0..count)
        .map(|offset| {
            let id = (start + offset as u64).to_string();
            serde_json::json!({
                "id": id,
                "text": format!("tweet-{id}"),
                "author_id": "u1",
                "created_at": "2012-09-07T16:35:24Z"
            })
        })
        .collect::<Vec<_>>();

    let mut payload = serde_json::json!({
        "data": data,
        "includes": {
            "users": [
                { "id": "u1", "username": "tester" }
            ]
        },
        "meta": {}
    });
    if let Some(token) = next_token {
        payload["meta"]["next_token"] = serde_json::json!(token);
    }
    payload
}
