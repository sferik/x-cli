require "test_helper"
require "tempfile"

# Includes RequestableAPI with a real X::Client, so requests are stubbed with WebMock like the commands' tests
class RequestableAPIProbe
  include T::RequestableAPI

  attr_reader :client

  def initialize
    @client = X::Client.new(api_key: "abc123", api_key_secret: "asdfasd223sd2", access_token: "7505382-cebdct6bwobn", access_token_secret: "epzrjvxtumoc")
  end
end

class TestRequestableAPI < TTestCase
  ME_ID = "7505382".freeze
  PEER_ID = "14100886".freeze

  def setup
    super
    @probe = RequestableAPIProbe.new
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    super
  end

  def json_return(hash)
    {body: JSON.generate(hash), headers: V2_JSON_HEADERS}
  end

  def repost_response(includes, text: "RT @sferik: Hello, Wo...")
    {
      "data" => [{"id" => "1", "text" => text, "author_id" => PEER_ID, "referenced_posts" => [{"type" => "reposted", "id" => "2"}]}],
      "includes" => includes,
    }
  end

  # ---------- setup ----------

  def test_v1_client_shares_the_credentials
    v1_client = @probe.send(:v1_client)

    assert_equal(T::RequestableAPI::BASE_URL_V1, v1_client.base_url)
    assert_equal("7505382-cebdct6bwobn", v1_client.access_token)
  end

  # ---------- users ----------

  def test_x_verify_credentials_presents_the_authenticated_user
    stub_v2_current_user
    user = @probe.x_verify_credentials

    assert_equal(7_505_382, user["id"])
    assert_equal("sferik", user["screen_name"])
    assert_equal(7890, user["statuses_count"])
    assert_equal(3755, user["favorites_count"])
    assert_equal(212, user["friends_count"])
    assert_equal(2262, user["followers_count"])
    assert_equal(Time.utc(2007, 7, 16, 12, 59, 1), user["created_at"])
  end

  def test_x_verify_credentials_presents_the_pinned_post_as_status
    stub_v2_current_user
    status = @probe.x_verify_credentials["status"]

    assert_equal(222_034_648_631_484_416, status["id"])
    assert_equal("@goldman You're near my home town! Say hi to Woodstock for me.", status["full_text"])
  end

  def test_x_verify_credentials_omits_status_without_a_pinned_post
    stub_v2_current_user("v2/user_no_status.json")

    assert_nil(@probe.x_verify_credentials["status"])
  end

  def test_x_verify_credentials_raises_when_there_is_no_authenticated_user
    stub_v2_get("users/me").to_return(v2_return("v2/empty.json"))

    assert_raises(X::ResourceNotFound) { @probe.x_verify_credentials }
  end

  def test_x_user_looks_up_a_string_by_username
    stub_v2_user_by_name("sferik")

    assert_equal("sferik", @probe.x_user("@sferik")["screen_name"])
  end

  def test_x_user_looks_up_an_integer_by_identifier
    stub_v2_user_by_id(ME_ID)

    assert_equal("sferik", @probe.x_user(7_505_382)["screen_name"])
    assert_requested(:get, %r{api\.twitter\.com/2/users/7505382\?})
  end

  def test_x_user_presents_a_resource_without_a_request
    user = X::User.new({"id" => ME_ID, "username" => "sferik"})

    assert_equal("sferik", @probe.x_user(user)["screen_name"])
  end

  def test_x_user_raises_when_the_user_is_not_found
    stub_v2_get("users/by/username/nobody").to_return(v2_return("v2/empty.json"))

    error = assert_raises(X::ResourceNotFound) { @probe.x_user("nobody") }
    assert_match(/nobody/, error.message)
  end

  def test_x_users_looks_up_identifiers_and_usernames_in_separate_batches
    stub_v2_users_lookup.to_return(v2_return("v2/users_pengwynn.json"))
    stub_v2_get("users/by?").to_return(v2_return("v2/users.json"))
    users = @probe.x_users([14_100_886, "@sferik"])

    assert_requested(:get, %r{api\.twitter\.com/2/users\?.*ids=14100886})
    assert_requested(:get, %r{api\.twitter\.com/2/users/by\?.*usernames=sferik})
    assert_equal("pengwynn", users.first["screen_name"])
  end

  def test_x_users_returns_empty_without_requests
    assert_empty(@probe.x_users([]))
  end

  def test_x_user_search_pages_with_next_token
    stub_v2_get("users/search").to_return(json_return({"data" => [{"id" => "1", "username" => "a"}], "meta" => {"next_token" => "abc"}}))
    @probe.x_user_search("ruby", page: 1)
    second = @probe.x_user_search("ruby", page: 2)

    assert_requested(:get, %r{api\.twitter\.com/2/users/search\?.*next_token=abc})
    assert_equal("a", second.first["screen_name"])
  end

  def test_x_user_search_returns_empty_beyond_the_last_page
    stub_v2_get("users/search").to_return(v2_return("v2/empty.json"))
    @probe.x_user_search("ruby", page: 1)

    assert_empty(@probe.x_user_search("ruby", page: 2))
  end

  def test_x_friendship_checks_the_following_list
    stub_v2_get("users/by/username/someone_else").to_return(json_return({"data" => {"id" => "1", "username" => "someone_else"}}))
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_get("users/1/following").to_return(v2_return("v2/follower_ids.json"))

    assert(@probe.x_friendship?("someone_else", "pengwynn"))
  end

  def test_x_friend_ids_returns_integers_for_the_authenticated_user
    stub_v2_current_user
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json"))

    assert_equal([14_100_886, 7_505_382], @probe.x_friend_ids)
  end

  def test_x_follower_ids_requests_only_identifiers
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/follower_ids.json"))

    assert_equal([14_100_886, 7_505_382], @probe.x_follower_ids(7_505_382))
    assert_requested(:get, %r{api\.twitter\.com/2/users/7505382/followers\?max_results=1000&user\.fields=id$})
  end

  # ---------- tweets ----------

  def test_x_status_presents_a_post
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    status = @probe.x_status(55_709_764_298_092_545)

    assert_equal(55_709_764_298_092_545, status["id"])
    assert_equal("sferik", status["user"]["screen_name"])
  end

  def test_x_status_returns_an_empty_hash_when_not_found
    stub_v2_get("tweets/1").to_return(v2_return("v2/empty.json"))

    assert_empty(@probe.x_status(1))
  end

  def test_tweet_hash_expands_a_repost_with_its_author
    includes = {"posts" => [{"id" => "2", "text" => "Hello, World!", "author_id" => ME_ID}], "users" => [{"id" => ME_ID, "username" => "sferik"}]}
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response(includes)))

    assert_equal("RT @sferik: Hello, World!", @probe.x_user_timeline(7_505_382).first["full_text"])
  end

  def test_tweet_hash_keeps_the_prefix_of_the_repost_text_when_the_author_is_not_included
    includes = {"posts" => [{"id" => "2", "text" => "Hello, World!"}]}
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response(includes)))

    assert_equal("RT @sferik: Hello, World!", @probe.x_user_timeline(7_505_382).first["full_text"])
  end

  def test_tweet_hash_builds_a_repost_prefix_from_an_included_author
    includes = {"posts" => [{"id" => "2", "text" => "Hello, World!", "author_id" => ME_ID}], "users" => [{"id" => ME_ID, "username" => "sferik"}]}
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response(includes, text: "Hello, Wo...")))

    assert_equal("RT @sferik: Hello, World!", @probe.x_user_timeline(7_505_382).first["full_text"])
  end

  def test_tweet_hash_builds_a_repost_prefix_from_an_author_that_is_not_included
    includes = {"posts" => [{"id" => "2", "text" => "Hello, World!", "author_id" => ME_ID}]}
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response(includes, text: "Hello, Wo...")))

    assert_equal("RT @7505382: Hello, World!", @probe.x_user_timeline(7_505_382).first["full_text"])
  end

  def test_tweet_hash_builds_a_repost_prefix_without_an_author
    includes = {"posts" => [{"id" => "2", "text" => "Hello, World!"}]}
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response(includes, text: "Hello, Wo...")))

    assert_equal("RT @: Hello, World!", @probe.x_user_timeline(7_505_382).first["full_text"])
  end

  def test_tweet_hash_expands_the_links_of_a_repost
    link = {"url" => "https://t.co/abc", "expanded_url" => "https://github.com/sferik/x-ruby"}
    includes = {"posts" => [{"id" => "2", "text" => "See https://t.co/abc", "author_id" => ME_ID, "entities" => {"urls" => [link]}}],
                "users" => [{"id" => ME_ID, "username" => "sferik"}]}
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response(includes)))
    tweet = @probe.x_user_timeline(7_505_382).first

    assert_equal("RT @sferik: See https://t.co/abc", tweet["full_text"])
    assert_equal("RT @sferik: See https://github.com/sferik/x-ruby", tweet["expanded_text"])
  end

  def test_tweet_hash_expands_the_links_of_a_post
    link = {"url" => "https://t.co/abc", "expanded_url" => "https://github.com/sferik/x-ruby"}
    stub_v2_get("users/7505382/tweets").to_return(json_return({"data" => [{"id" => "1", "text" => "See https://t.co/abc", "entities" => {"urls" => [link]}}]}))
    tweet = @probe.x_user_timeline(7_505_382).first

    assert_equal("See https://t.co/abc", tweet["full_text"])
    assert_equal("See https://github.com/sferik/x-ruby", tweet["expanded_text"])
  end

  def test_tweet_hash_keeps_the_text_of_a_repost_that_is_not_included
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response({})))

    assert_equal("RT @sferik: Hello, Wo...", @probe.x_user_timeline(7_505_382).first["full_text"])
  end

  def test_tweet_hash_names_an_author_that_is_not_included_by_identifier
    stub_v2_get("users/7505382/tweets").to_return(json_return(repost_response({})))

    assert_equal(PEER_ID, @probe.x_user_timeline(7_505_382).first["user"]["screen_name"])
  end

  def test_x_user_timeline_passes_the_options_as_parameters
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/empty.json"))
    @probe.x_user_timeline(7_505_382, exclude: "replies,retweets", until_id: 10, since_id: 5)

    assert_requested(:get, %r{users/7505382/tweets\?.*exclude=replies,retweets.*since_id=5.*until_id=10})
  end

  def test_x_home_timeline_limits_the_results_to_the_count
    stub_v2_current_user
    stub_v2_get("users/7505382/timelines/reverse_chronological").to_return(v2_return("v2/statuses.json"))

    assert_equal(3, @probe.x_home_timeline(count: 3).size)
  end

  def test_x_favorites_treats_a_hash_first_argument_as_options
    stub_v2_current_user
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/favorites.json"))

    assert_equal(1, @probe.x_favorites(count: 1).size)
  end

  def test_x_retweeted_by_user_returns_only_reposts
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    tweets = @probe.x_retweeted_by_user(7_505_382)

    assert_equal(6, tweets.size)
    assert(tweets.all? { |tweet| tweet["full_text"].start_with?("RT @") })
  end

  def test_x_retweeters_ids_returns_integers
    stub_v2_get("tweets/1/retweeted_by").to_return(v2_return("v2/follower_ids.json"))

    assert_equal([14_100_886, 7_505_382], @probe.x_retweeters_ids(1))
  end

  def test_x_search_caps_the_count_at_the_maximum_page_size
    stub_v2_get("tweets/search/recent").to_return(json_return({"data" => (1..150).collect { |id| {"id" => id.to_s, "text" => "ruby"} }}))

    assert_equal(100, @probe.x_search("ruby", count: 500).size)
  end

  def test_x_update_posts_the_reply_and_media
    stub_v2_post("tweets").to_return(v2_return("v2/post_response.json"))
    @probe.x_update("Hello", reply_to: 1, media_ids: [2])

    assert_requested(:post, v2_pattern("tweets"), body: JSON.generate({text: "Hello", reply: {in_reply_to_tweet_id: "1"}, media: {media_ids: ["2"]}}))
  end

  def test_x_update_returns_an_empty_hash_without_a_post
    stub_v2_post("tweets").to_return(json_return({}))

    assert_empty(@probe.x_update("Hello"))
  end

  def test_x_update_with_media_uploads_a_file_by_path
    stub_v2_post("media/upload").to_return(v2_return("v2/media_upload.json"))
    stub_v2_post("tweets").to_return(v2_return("v2/post_response.json"))
    @probe.x_update_with_media("Hello", "#{fixture_path}/long.png")

    assert_requested(:post, v2_pattern("media/upload")) { |request| request.body.include?("tweet_image") }
    assert_requested(:post, v2_pattern("tweets"), body: /"media_ids":\["470030289822314497"\]/)
  end

  def test_upload_media_uploads_a_still_gif_as_an_image
    stub_v2_post("media/upload").to_return(v2_return("v2/media_upload.json"))
    Tempfile.create(["animation", ".gif"]) do |file|
      file.write("GIF89a")
      file.flush

      assert_equal("470030289822314497", @probe.send(:upload_media, file)["id"])
    end
    assert_requested(:post, v2_pattern("media/upload")) { |request| request.body.include?("tweet_image") }
  end

  def test_upload_media_uploads_a_video_in_chunks_and_awaits_processing
    stub_v2_post("media/upload/initialize").to_return(json_return({"data" => {"id" => "123"}}))
    stub_v2_post("media/upload/123/append").to_return(json_return({}))
    stub_v2_post("media/upload/123/finalize").to_return(json_return({"data" => {"id" => "123", "processing_info" => {"state" => "pending"}}}))
    stub_request(:get, %r{api\.twitter\.com/2/media/upload\?command=STATUS&media_id=123}).to_return(json_return({"data" => {"id" => "123", "processing_info" => {"state" => "succeeded"}}}))
    Tempfile.create(["video", ".mp4"]) do |file|
      file.write("mp4")
      file.flush

      assert_equal("123", @probe.send(:upload_media, file)["id"])
    end
    assert_requested(:post, v2_pattern("media/upload/123/finalize"))
  end

  # ---------- mutations ----------

  def test_x_follow_follows_each_user_and_presents_them
    stub_v2_current_user
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_post("users/7505382/following").to_return(v2_return("v2/post_response.json"))

    assert_equal(["pengwynn"], @probe.x_follow(["pengwynn"]).collect { |user| user["screen_name"] })
    assert_requested(:post, v2_pattern("users/7505382/following"), body: JSON.generate({target_user_id: PEER_ID}))
  end

  def test_x_follow_warns_and_skips_a_user_that_is_not_found
    stub_v2_current_user
    stub_v2_get("users/by/username/nobody").to_return(v2_return("v2/empty.json"))

    assert_empty(@probe.x_follow(["nobody"]))
    assert_match(/@nobody: Could not find X::User nobody/, $stderr.string)
  end

  def test_x_block_warns_and_skips_a_forbidden_user
    stub_v2_current_user
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_post("users/7505382/blocking").to_return(status: 403, body: '{"errors":[{"message":"Forbidden"}]}', headers: V2_JSON_HEADERS)

    assert_empty(@probe.x_block(["pengwynn"]))
    assert_match(/@pengwynn: Forbidden/, $stderr.string)
  end

  def test_x_unmute_deletes_the_mute
    stub_v2_current_user
    stub_v2_user_by_id(PEER_ID, "v2/pengwynn.json")
    stub_v2_delete("users/7505382/muting/14100886").to_return(v2_return("v2/post_response.json"))
    @probe.x_unmute([14_100_886])

    assert_requested(:delete, v2_pattern("users/7505382/muting/14100886"))
  end

  def test_x_report_spam_reports_by_identifier_or_username
    stub_v2_user_by_id(PEER_ID, "v2/pengwynn.json")
    stub_v2_user_by_name("sferik")
    stub_post("/1.1/users/report_spam.json").to_return(body: "{}", headers: V2_JSON_HEADERS)
    @probe.x_report_spam([14_100_886, "sferik"])

    assert_requested(:post, "https://api.twitter.com/1.1/users/report_spam.json", body: "user_id=14100886")
    assert_requested(:post, "https://api.twitter.com/1.1/users/report_spam.json", body: "screen_name=sferik")
  end

  def test_x_favorite_returns_a_hash_for_a_single_identifier
    stub_v2_current_user
    stub_v2_post("users/7505382/likes").to_return(v2_return("v2/post_response.json"))

    assert_equal({"id" => 1, "id_str" => "1"}, @probe.x_favorite(1))
  end

  def test_x_unfavorite_returns_an_array_for_identifiers
    stub_v2_current_user
    stub_v2_delete("users/7505382/likes/1").to_return(v2_return("v2/post_response.json"))

    assert_equal([{"id" => 1, "id_str" => "1"}], @probe.x_unfavorite([1]))
  end

  def test_x_retweet_reposts
    stub_v2_current_user
    stub_v2_post("users/7505382/retweets").to_return(v2_return("v2/post_response.json"))
    @probe.x_retweet([1])

    assert_requested(:post, v2_pattern("users/7505382/retweets"), body: JSON.generate({tweet_id: "1"}))
  end

  def test_x_destroy_status_deletes_the_post
    stub_v2_delete("tweets/1").to_return(v2_return("v2/post_response.json"))
    @probe.x_destroy_status(1)

    assert_requested(:delete, v2_pattern("tweets/1"))
  end

  def test_x_blocked_ids_pages_through_the_blocked_users
    stub_v2_current_user
    stub_v2_get("users/7505382/blocking").to_return(json_return({"data" => [{"id" => "1"}], "meta" => {"next_token" => "t"}})).then.to_return(json_return({"data" => [{"id" => "2"}]}))

    assert_equal([1, 2], @probe.x_blocked_ids)
    assert_requested(:get, %r{users/7505382/blocking\?.*pagination_token=t})
  end

  # ---------- direct messages ----------

  def test_x_direct_messages_received_excludes_messages_the_authenticated_user_sent
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(v2_return("v2/direct_message_events.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/dm_users.json"))
    messages = @probe.x_direct_messages_received(count: 50)

    assert_equal(13, messages.size)
    assert(messages.none? { |message| message["sender_id"] == 7_505_382 })
    assert_equal("Araujoselmaa", messages[1]["recipient"]["screen_name"])
  end

  def test_x_direct_messages_sent_returns_the_messages_the_authenticated_user_sent
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(v2_return("v2/direct_message_events.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/dm_users.json"))
    messages = @probe.x_direct_messages_sent(count: 50)

    assert_equal(3, messages.size)
    assert_equal(422_190_131, messages.first["recipient_id"])
    assert_equal("nederfariar", messages.first["recipient"]["screen_name"])
  end

  def test_x_direct_messages_sent_filters_by_until_id
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(v2_return("v2/direct_message_events.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/dm_users.json"))

    assert_equal(2, @probe.x_direct_messages_sent(count: 50, until_id: 856_523_768_910_544_899).size)
  end

  def test_x_direct_message_presents_a_received_message_with_its_included_sender
    stub_v2_current_user
    stub_v2_get("dm_events/1").to_return(json_return({"data" => {"id" => "1", "sender_id" => PEER_ID, "text" => "hi", "dm_conversation_id" => "7505382-14100886"}, "includes" => {"users" => [{"id" => PEER_ID, "username" => "pengwynn"}]}}))
    message = @probe.x_direct_message(1)

    assert_equal("pengwynn", message["recipient"]["screen_name"])
    assert_equal(14_100_886, message["recipient_id"])
  end

  def test_x_direct_message_looks_up_the_recipient_of_a_sent_message
    stub_v2_current_user
    stub_v2_get("dm_events/1773478249").to_return(v2_return("v2/dm_event.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_pengwynn.json"))

    assert_equal("pengwynn", @probe.x_direct_message(1_773_478_249)["recipient"]["screen_name"])
  end

  def test_x_direct_message_has_no_recipient_in_a_group_conversation
    stub_v2_current_user
    stub_v2_get("dm_events/1").to_return(json_return({"data" => {"id" => "1", "sender_id" => ME_ID, "text" => "hi", "dm_conversation_id" => ME_ID}}))
    message = @probe.x_direct_message(1)

    assert_equal(0, message["recipient_id"])
    assert_empty(message["recipient"])
  end

  def test_x_direct_messages_sent_has_no_recipient_in_a_group_conversation
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(json_return({"data" => [{"id" => "1", "sender_id" => ME_ID, "text" => "hi", "dm_conversation_id" => ME_ID}]}))
    messages = @probe.x_direct_messages_sent

    assert_equal([0], messages.collect { |message| message["recipient_id"] })
    assert_equal([{}], messages.collect { |message| message["recipient"] })
  end

  def test_x_direct_message_returns_nil_when_the_message_is_not_found
    stub_v2_get("dm_events/1").to_return(status: 404, body: '{"errors":[{"message":"Not Found"}]}', headers: V2_JSON_HEADERS)

    assert_nil(@probe.x_direct_message(1))
  end

  def test_x_direct_message_returns_nil_without_data
    stub_v2_get("dm_events/1").to_return(v2_return("v2/empty.json"))

    assert_nil(@probe.x_direct_message(1))
  end

  def test_x_create_direct_message_event_resolves_a_username
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_post("dm_conversations/with/14100886/messages").to_return(v2_return("v2/dm_sent.json"))
    message = @probe.x_create_direct_message_event("pengwynn", "hi")

    assert_equal(1_773_478_249, message["id"])
    assert_equal("pengwynn", message["recipient"]["screen_name"])
  end

  def test_x_create_direct_message_event_returns_no_identifier_without_data
    stub_v2_post("dm_conversations/with/14100886/messages").to_return(json_return({}))
    message = @probe.x_create_direct_message_event({"id" => 14_100_886, "screen_name" => "pengwynn"}, "hi")

    assert_nil(message["id"])
    assert_equal(14_100_886, message["recipient_id"])
  end

  def test_x_destroy_direct_message_deletes_each_event
    stub_v2_delete("dm_events/1").to_return(v2_return("v2/post_response.json"))
    stub_v2_delete("dm_events/2").to_return(v2_return("v2/post_response.json"))

    assert(@probe.x_destroy_direct_message(1, [2]))
    assert_requested(:delete, v2_pattern("dm_events/2"))
  end

  # ---------- lists ----------

  def test_x_list_finds_a_list_by_identifier
    stub_v2_get("lists/8863586").to_return(v2_return("v2/list_detail.json"))
    list = @probe.x_list(8_863_586)

    assert_equal("presidents", list["slug"])
    assert_equal("@sferik/presidents", list["full_name"])
    assert_equal("public", list["mode"])
  end

  def test_x_list_raises_when_the_identifier_is_not_found
    stub_v2_get("lists/1").to_return(v2_return("v2/empty.json"))

    assert_raises(X::ResourceNotFound) { @probe.x_list(1) }
  end

  def test_x_list_finds_a_list_by_slug_among_the_owned_lists
    stub_v2_current_user
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))

    assert_equal(8_863_586, @probe.x_list("Presidents")["id"])
  end

  def test_x_list_raises_when_no_owned_list_matches
    stub_v2_current_user
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))

    assert_raises(X::ResourceNotFound) { @probe.x_list("vice-presidents") }
  end

  def test_x_lists_presents_the_lists_a_user_owns
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/lists.json"))
    lists = @probe.x_lists("sferik")

    assert_equal(%w[@pengwynn/rubyists @twitter/team @sferik/test], lists.collect { |list| list["full_name"] })
    assert_equal([nil, "private"], [lists[1]["mode"], lists[2]["mode"]])
  end

  def test_x_create_list_presents_the_created_list_without_an_owner
    stub_v2_post("lists").to_return(v2_return("v2/list_created.json"))
    list = @probe.x_create_list("presidents", description: "POTUS", mode: "private")

    assert_equal(8_863_586, list["id"])
    assert_nil(list["user"])
    assert_requested(:post, v2_pattern("lists"), body: JSON.generate({name: "presidents", description: "POTUS", private: true}))
  end

  def test_x_create_list_returns_an_empty_hash_without_data
    stub_v2_post("lists").to_return(json_return({}))

    assert_empty(@probe.x_create_list("presidents"))
  end

  def test_x_destroy_list_accepts_an_identifier
    stub_v2_delete("lists/8863586").to_return(json_return({"data" => {"deleted" => true}}))

    assert(@probe.x_destroy_list(8_863_586))
    assert_requested(:delete, v2_pattern("lists/8863586"))
  end

  def test_x_add_list_members_adds_each_user
    stub_v2_current_user
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_post("lists/8863586/members").to_return(v2_return("v2/post_response.json"))

    assert(@probe.x_add_list_members("presidents", [14_100_886]))
    assert_requested(:post, v2_pattern("lists/8863586/members"), body: JSON.generate({user_id: PEER_ID}))
  end

  def test_x_list_member_checks_the_members_by_identifier
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_listed_count(14_100_886, 100_000)
    stub_listed_count(1, 100_000)
    stub_v2_get("lists/8863586/members").to_return(v2_return("v2/follower_ids.json"))

    assert(@probe.x_list_member?("sferik", "presidents", 14_100_886))
    refute(@probe.x_list_member?("sferik", "presidents", 1))
  end

  def test_x_list_member_scans_the_fewer_lists_a_user_is_on
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_listed_count(14_100_886, 1)
    stub_v2_get("users/14100886/list_memberships").to_return(json_return({"data" => [{"id" => "8863586"}]}))

    assert(@probe.x_list_member?("sferik", "presidents", 14_100_886))
    assert_not_requested(:get, v2_pattern("lists/8863586/members"))
  end

  def stub_listed_count(id, count)
    stub_request(:get, %r{api\.twitter\.com/2/users/#{id}\?}).to_return(json_return({"data" => {"id" => id.to_s, "public_metrics" => {"listed_count" => count}}}))
  end

  def test_x_list_timeline_presents_the_posts_of_the_list
    stub_v2_user_by_id(ME_ID)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json"))

    assert_equal(2, @probe.x_list_timeline(7_505_382, "presidents", count: 2).size)
  end

  # ---------- account ----------

  def test_x_trends_filters_hashtags_and_nameless_trends
    stub_v2_get("trends/by/woeid/1").to_return(json_return({"data" => [{"trend_name" => "#ruby"}, {"name" => "rails"}, {"tweet_count" => 1}]}))

    assert_equal([{"name" => "rails"}], @probe.x_trends(1, exclude: "hashtags"))
  end

  def test_x_update_profile_image_uploads_the_image
    stub_request(:post, "https://api.x.com/1.1/account/update_profile_image.json").to_return(body: "{}", headers: V2_JSON_HEADERS)
    @probe.x_update_profile_image(File.new("#{fixture_path}/me.jpg"))

    assert_requested(:post, "https://api.x.com/1.1/account/update_profile_image.json") { |request| request.headers["Content-Type"].start_with?("multipart/form-data") }
  end

  def test_x_update_profile_image_returns_an_empty_hash_without_a_body
    stub_request(:post, "https://api.x.com/1.1/account/update_profile_image.json").to_return(status: 204)

    assert_empty(@probe.x_update_profile_image(File.new("#{fixture_path}/me.jpg")))
  end

  # ---------- helpers ----------

  def test_slugify_list_name_replaces_punctuation
    assert_equal("my-list_name", @probe.send(:slugify_list_name, " My List_Name! "))
  end

  def test_result_count_defaults_and_stays_positive
    assert_equal(20, @probe.send(:result_count, {}))
    assert_equal(1, @probe.send(:result_count, {count: 0}))
  end
end
