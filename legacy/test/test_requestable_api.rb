require "test_helper"
require "tempfile"

# A lightweight probe that includes RequestableAPI for direct testing
class RequestableAPIProbe
  include T::RequestableAPI

  attr_accessor :client

  def initialize(client)
    @client = client
    @requestable_api_credentials = {
      api_key: "key",
      api_key_secret: "secret",
      access_token: "token",
      access_token_secret: "tokensecret",
    }
    @requestable_api_setup = true
    @requestable_api_user_search_tokens = {}
    @requestable_api_before_request = nil
  end
end

# Minimal fake client that records calls and supports configurable GET routing
class FakeXClient
  attr_reader :get_calls, :post_calls, :delete_calls

  def initialize
    @get_handler = ->(_url) { {"data" => []} }
    @post_handler = ->(_url, _body) { {} }
    @get_calls = []
    @post_calls = []
    @delete_calls = []
  end

  def get(url)
    @get_calls << url
    @get_handler.call(url)
  end

  def post(url, body = nil, **_kwargs)
    @post_calls << [url, body]
    @post_handler.call(url, body)
  end

  def delete(url)
    @delete_calls << url
    {}
  end

  def on_get(&block)
    @get_handler = block
  end

  def on_post(&block)
    @post_handler = block
  end
end

class TestRequestableAPI < TTestCase
  ME_RESPONSE = {
    "data" => {
      "id" => "7505382",
      "username" => "sferik",
      "name" => "Erik",
      "public_metrics" => {"followers_count" => 100, "following_count" => 50, "tweet_count" => 1000, "listed_count" => 10, "like_count" => 500},
    },
  }.freeze

  def setup
    super
    @fake_client = FakeXClient.new
    @fake_client.on_get do |url|
      if url.include?("users/me")
        ME_RESPONSE
      else
        {"data" => []}
      end
    end
    @probe = RequestableAPIProbe.new(@fake_client)
  end

  # Helper: create a v1 client fake and wire it into the probe
  def with_v1_client
    v1 = FakeXClient.new
    @probe.define_singleton_method(:v1_client) { v1 }
    v1
  end

  # Helper: create an upload client fake and wire it into the probe
  def with_upload_client
    uc = FakeXClient.new
    @probe.define_singleton_method(:upload_client) { uc }
    uc
  end

  # Helper: build a Net::HTTP error response
  def build_http_response(klass, code, message)
    resp = klass.new("1.1", code, message)
    resp.instance_variable_set(:@body, "{}")
    resp.instance_variable_set(:@read, true)
    resp
  end

  # ---------- x_user with block and no before_request ----------

  def test_x_user_with_block_works_when_before_request_is_nil
    tweets = [{"id" => "1", "text" => "hi", "full_text" => "hi", "user" => {}}]
    @probe.define_singleton_method(:x_home_timeline) { |**_| tweets }
    collected = []
    @probe.x_user(nil) { |t| collected << t }

    assert_equal tweets, collected
  end

  # ---------- x_verify_credentials ----------

  def test_x_verify_credentials_when_v2_succeeds
    result = @probe.x_verify_credentials

    assert_equal "sferik", result["screen_name"]
  end

  def test_x_verify_credentials_falls_back_to_v1_on_x_error
    @fake_client.on_get { |_url| raise X::Error.new("v2 unavailable") }
    v1 = with_v1_client
    v1_user = {"id" => 7_505_382, "id_str" => "7505382", "screen_name" => "sferik", "name" => "Erik Michaels-Ober"}
    v1.on_get { |_url| v1_user }
    result = @probe.x_verify_credentials

    assert_equal "sferik", result["screen_name"]
  end

  def test_x_verify_credentials_calls_v1_client_on_x_error
    @fake_client.on_get { |_url| raise X::Error.new("v2 unavailable") }
    v1 = with_v1_client
    v1_user = {"id" => 7_505_382, "id_str" => "7505382", "screen_name" => "sferik", "name" => "Erik Michaels-Ober"}
    v1.on_get { |_url| v1_user }
    @probe.x_verify_credentials

    assert(v1.get_calls.any? { |url| url.include?("account/verify_credentials.json") })
  end

  # ---------- x_user fallback on ServiceUnavailable ----------

  def test_x_user_fallback_on_service_unavailable
    resp = build_http_response(Net::HTTPServiceUnavailable, "503", "Service Unavailable")
    @fake_client.on_get do |url|
      raise X::ServiceUnavailable.new(response: resp) unless url.include?("users/me")

      ME_RESPONSE
    end
    v1 = with_v1_client
    v1_user = {"id" => 7_505_382, "id_str" => "7505382", "screen_name" => "sferik", "name" => "Erik Michaels-Ober"}
    v1.on_get { |_url| v1_user }
    result = @probe.x_user("sferik")

    assert_equal "sferik", result["screen_name"]
  end

  def test_x_user_fallback_calls_v1_with_screen_name
    resp = build_http_response(Net::HTTPServiceUnavailable, "503", "Service Unavailable")
    @fake_client.on_get do |url|
      raise X::ServiceUnavailable.new(response: resp) unless url.include?("users/me")

      ME_RESPONSE
    end
    v1 = with_v1_client
    v1_user = {"id" => 7_505_382, "id_str" => "7505382", "screen_name" => "sferik", "name" => "Erik Michaels-Ober"}
    v1.on_get { |_url| v1_user }
    @probe.x_user("sferik")

    assert(v1.get_calls.any? { |url| url.match?(%r{users/show\.json.*screen_name=sferik}) })
  end

  # ---------- x_users ----------

  def test_x_users_returns_empty_array_when_empty
    assert_equal [], @probe.x_users([])
  end

  def test_x_users_looks_up_by_numeric_ids
    user_resp = {"data" => [{"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}]}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users?") || (url.include?("users") && url.include?("ids=")) then user_resp
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.x_users(["14100886"]).first["screen_name"]
  end

  def test_x_users_looks_up_by_screen_names
    user_resp = {"data" => [{"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}]}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by") then user_resp
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.x_users(["pengwynn"]).first["screen_name"]
  end

  # ---------- x_user_search ----------

  def test_x_user_search_returns_first_page_results
    search_resp = {"data" => [{"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}], "meta" => {"result_count" => 1, "next_token" => "page2token"}}
    @fake_client.on_get do |url|
      url.include?("users/search") ? search_resp : {"data" => []}
    end

    assert_equal "pengwynn", @probe.x_user_search("test", page: 1).first["screen_name"]
  end

  def test_x_user_search_uses_stored_next_token_for_page_2
    search_resp = {"data" => [{"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}], "meta" => {"result_count" => 1, "next_token" => "page2token"}}
    search_resp2 = {"data" => [{"id" => "7505382", "username" => "sferik", "name" => "Erik"}], "meta" => {"result_count" => 1}}
    call_count = 0
    @fake_client.on_get do |url|
      if url.include?("users/search")
        call_count += 1
        call_count == 1 ? search_resp : search_resp2
      else
        {"data" => []}
      end
    end
    @probe.x_user_search("test", page: 1)

    assert_equal "sferik", @probe.x_user_search("test", page: 2).first["screen_name"]
  end

  def test_x_user_search_returns_empty_when_page_gt_1_and_no_token
    assert_equal [], @probe.x_user_search("test", page: 2)
  end

  # ---------- x_search ----------

  def test_x_search_returns_empty_with_max_id
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      else {"data" => [], "meta" => {"result_count" => 0}}
      end
    end

    assert_equal [], @probe.x_search("test", max_id: "12345")
  end

  def test_x_search_converts_max_id_to_until_id
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      else {"data" => [], "meta" => {"result_count" => 0}}
      end
    end
    @probe.x_search("test", max_id: "12345")

    assert(@fake_client.get_calls.any? { |url| url.include?("until_id=12345") })
  end

  def test_x_search_returns_empty_with_since_id
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      else {"data" => [], "meta" => {"result_count" => 0}}
      end
    end

    assert_equal [], @probe.x_search("test", since_id: "99999")
  end

  def test_x_search_includes_since_id_parameter
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      else {"data" => [], "meta" => {"result_count" => 0}}
      end
    end
    @probe.x_search("test", since_id: "99999")

    assert(@fake_client.get_calls.any? { |url| url.include?("since_id=99999") })
  end

  # ---------- x_direct_message ----------

  def test_x_direct_message_returns_nil_on_not_found
    resp = build_http_response(Net::HTTPNotFound, "404", "Not Found")
    @fake_client.on_get { |_url| raise X::NotFound.new(response: resp) }

    assert_nil @probe.x_direct_message("12345")
  end

  def test_x_direct_message_handles_single_hash_data
    dm_resp = {
      "data" => {"id" => "999", "event_type" => "MessageCreate", "sender_id" => "7505382", "text" => "hello", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"},
      "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}, {"id" => "14100886", "username" => "pengwynn"}]},
    }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events/") then dm_resp
      else {"data" => []}
      end
    end

    assert_equal 999, @probe.x_direct_message("999")["id"]
  end

  def test_x_direct_message_returns_nil_when_events_empty
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events/") then {"data" => [], "meta" => {"result_count" => 0}}
      else {"data" => []}
      end
    end

    assert_nil @probe.x_direct_message("999")
  end

  # ---------- x_create_direct_message_event ----------

  def test_x_create_dm_event_resolves_recipient_by_username
    user_resp = {"data" => {"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}}
    post_resp = {"data" => {"id" => "9999", "text" => "hi"}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/pengwynn") || url.include?("users/14100886") then user_resp
      else {"data" => []}
      end
    end
    @fake_client.on_post { |_url, _body| post_resp }

    assert_equal "hello", @probe.x_create_direct_message_event("pengwynn", "hello")["text"]
  end

  def test_x_create_dm_event_uses_recipient_hash_id
    user_resp = {"data" => {"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}}
    post_resp = {"data" => {"id" => "9999", "text" => "hi"}}
    @fake_client.on_post { |_url, _body| post_resp }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/14100886") then user_resp
      else {"data" => []}
      end
    end
    recipient = {"id" => "14100886", "screen_name" => "pengwynn"}

    assert_equal "14100886", @probe.x_create_direct_message_event(recipient, "hello")["recipient_id"]
  end

  # ---------- x_destroy_list ----------

  def test_x_destroy_list_accepts_string_id
    assert @probe.x_destroy_list("12345")
  end

  def test_x_destroy_list_accepts_hash_with_id
    assert @probe.x_destroy_list({"id" => "12345", "slug" => "test"})
  end

  # ---------- x_trends ----------

  def test_x_trends_filters_nil_names
    resp = {"data" => [{"trend_name" => "#sevenwordsaftersex"}, {"trend_name" => nil}, {"trend_name" => "Walkman"}]}
    @fake_client.on_get { |url| url.include?("trends") ? resp : {"data" => []} }
    result = @probe.x_trends(1)

    assert_equal 2, result.size
  end

  def test_x_trends_returns_only_non_nil_names
    resp = {"data" => [{"trend_name" => "#sevenwordsaftersex"}, {"trend_name" => nil}, {"trend_name" => "Walkman"}]}
    @fake_client.on_get { |url| url.include?("trends") ? resp : {"data" => []} }
    result = @probe.x_trends(1)

    assert_equal(["#sevenwordsaftersex", "Walkman"], result.map { |t| t["name"] })
  end

  def test_x_trends_excludes_hashtags
    resp = {"data" => [{"trend_name" => "#sevenwordsaftersex"}, {"trend_name" => "Walkman"}]}
    @fake_client.on_get { |url| url.include?("trends") ? resp : {"data" => []} }
    result = @probe.x_trends(1, exclude: "hashtags")

    assert_equal 1, result.size
    assert_equal "Walkman", result.first["name"]
  end

  def test_x_trends_falls_back_to_name_key
    resp = {"data" => [{"name" => "FallbackTrend"}]}
    @fake_client.on_get { |url| url.include?("trends") ? resp : {"data" => []} }

    assert_equal "FallbackTrend", @probe.x_trends(1).first["name"]
  end

  # ---------- x_update_profile_background_image ----------

  def test_x_update_profile_background_image_with_tile_true
    v1 = with_v1_client
    v1.on_post { |_url, _body| {} }

    assert @probe.x_update_profile_background_image(StringIO.new("imagedata"), tile: true)
  end

  # ---------- x_sample ----------

  def test_x_sample_calls_search_and_yields
    tweets = [{"id" => "1", "text" => "hello", "full_text" => "hello", "user" => {"screen_name" => "test"}}]
    @probe.define_singleton_method(:x_search) { |*_args, **_opts| tweets }
    collected = []
    @probe.x_sample { |t| collected << t }

    assert_equal tweets, collected
  end

  def test_x_sample_calls_before_request_callback
    called = false
    @probe.x_before_request { called = true }
    @probe.define_singleton_method(:x_search) { |*_args, **_opts| [] }
    @probe.x_sample { |_t| nil }

    assert called
  end

  def test_x_sample_uses_language_filter
    search_args = nil
    @probe.define_singleton_method(:x_search) do |*args, **opts|
      search_args = [args, opts]
      []
    end
    @probe.x_sample(language: "en") { |_t| nil }

    assert_equal "lang:en -is:retweet", search_args[0][0]
    assert_equal 20, search_args[1][:count]
  end

  def test_x_sample_falls_back_on_bad_request
    resp = build_http_response(Net::HTTPBadRequest, "400", "Bad Request")
    call_count = 0
    @probe.define_singleton_method(:x_search) do |*_args, **_opts|
      call_count += 1
      raise X::BadRequest.new(response: resp) if call_count == 1

      [{"id" => "1", "text" => "news", "full_text" => "news", "user" => {}}]
    end
    collected = []
    @probe.x_sample { |t| collected << t }

    assert_equal 1, collected.size
  end

  def test_x_sample_falls_back_with_language_on_bad_request
    resp = build_http_response(Net::HTTPBadRequest, "400", "Bad Request")
    call_count = 0
    @probe.define_singleton_method(:x_search) do |*_args, **_opts|
      call_count += 1
      raise X::BadRequest.new(response: resp) if call_count == 1

      [{"id" => "1", "text" => "news", "full_text" => "news", "user" => {}}]
    end
    collected = []
    @probe.x_sample(language: "en") { |t| collected << t }

    assert_equal 1, collected.size
  end

  # ---------- x_filter ----------

  def test_x_filter_yields_search_results_with_track
    tweets = [{"id" => "1", "text" => "hello", "full_text" => "hello", "user" => {"screen_name" => "test"}}]
    @probe.define_singleton_method(:x_search) { |*_args, **_opts| tweets }
    collected = []
    @probe.x_filter(track: "ruby,rails") { |t| collected << t }

    assert_equal tweets, collected
  end

  def test_x_filter_converts_track_keywords_to_or_query
    search_args = nil
    @probe.define_singleton_method(:x_search) do |*args, **opts|
      search_args = [args, opts]
      []
    end
    @probe.x_filter(track: "ruby,rails") { |_t| nil }

    assert_equal "ruby OR rails", search_args[0][0]
    assert_equal 100, search_args[1][:count]
  end

  def test_x_filter_calls_before_request_callback
    called = false
    @probe.x_before_request { called = true }
    @probe.define_singleton_method(:x_search) { |*_args, **_opts| [] }
    @probe.x_filter(track: "test") { |_t| nil }

    assert called
  end

  def test_x_filter_uses_follow_ids_as_from_queries
    search_args = nil
    @probe.define_singleton_method(:x_search) do |*args, **opts|
      search_args = [args, opts]
      []
    end
    @probe.x_filter(follow: "123,456") { |_t| nil }

    assert_equal "from:123 OR from:456", search_args[0][0]
  end

  def test_x_filter_uses_default_query_when_no_track_or_follow
    search_args = nil
    @probe.define_singleton_method(:x_search) do |*args, **opts|
      search_args = [args, opts]
      []
    end
    @probe.x_filter { |_t| nil }

    assert_equal "has:mentions OR -is:retweet", search_args[0][0]
  end

  def test_x_filter_falls_back_on_bad_request
    resp = build_http_response(Net::HTTPBadRequest, "400", "Bad Request")
    call_count = 0
    @probe.define_singleton_method(:x_search) do |*_args, **_opts|
      call_count += 1
      raise X::BadRequest.new(response: resp) if call_count == 1

      [{"id" => "1", "text" => "news", "full_text" => "news", "user" => {}}]
    end
    collected = []
    @probe.x_filter(track: "test") { |t| collected << t }

    assert_equal 1, collected.size
  end

  def test_x_filter_handles_empty_track_strings
    search_args = nil
    @probe.define_singleton_method(:x_search) do |*args, **opts|
      search_args = [args, opts]
      []
    end
    @probe.x_filter(track: ",,,") { |_t| nil }

    assert_equal "has:mentions OR -is:retweet", search_args[0][0]
  end

  def test_x_filter_handles_empty_follow_strings
    search_args = nil
    @probe.define_singleton_method(:x_search) do |*args, **opts|
      search_args = [args, opts]
      []
    end
    @probe.x_filter(follow: ",,,") { |_t| nil }

    assert_equal "has:mentions OR -is:retweet", search_args[0][0]
  end

  # ---------- x_direct_messages_received ----------

  def test_x_direct_messages_received_filters_non_messagecreate
    events_resp = {
      "data" => [
        {"id" => "1", "event_type" => "MessageCreate", "sender_id" => "14100886", "text" => "hello", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"},
        {"id" => "2", "event_type" => "ParticipantsJoin", "sender_id" => "14100886", "text" => "", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"},
      ],
      "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}, {"id" => "14100886", "username" => "pengwynn"}]},
      "meta" => {"result_count" => 2},
    }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events") then events_resp
      else {"data" => []}
      end
    end
    result = @probe.x_direct_messages_received

    assert_equal 1, result.size
    assert_equal 1, result.first["id"]
  end

  # ---------- x_direct_messages_sent ----------

  def test_x_direct_messages_sent_returns_correct_count
    dm_users = [{"id" => "7505382", "username" => "sferik"}, {"id" => "14100886", "username" => "pengwynn"}]
    events_resp = {
      "data" => [{"id" => "1", "event_type" => "MessageCreate", "sender_id" => "7505382", "text" => "sent msg", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"}],
      "includes" => {"users" => dm_users},
      "meta" => {"result_count" => 1},
    }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events") then events_resp
      else {"data" => []}
      end
    end
    result = @probe.x_direct_messages_sent

    assert_equal 1, result.size
    assert_equal "sent msg", result.first["text"]
  end

  def test_x_direct_messages_sent_filters_by_max_id
    dm_users = [{"id" => "7505382", "username" => "sferik"}, {"id" => "14100886", "username" => "pengwynn"}]
    events_resp = {
      "data" => [
        {"id" => "100", "event_type" => "MessageCreate", "sender_id" => "7505382", "text" => "a", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"},
        {"id" => "200", "event_type" => "MessageCreate", "sender_id" => "7505382", "text" => "b", "created_at" => "2023-01-02T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"},
      ],
      "includes" => {"users" => dm_users},
      "meta" => {"result_count" => 2},
    }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events") then events_resp
      else {"data" => []}
      end
    end
    result = @probe.x_direct_messages_sent(max_id: 150)

    assert_equal 1, result.size
    assert_equal 100, result.first["id"]
  end

  # ---------- normalize_dm_event ----------

  def test_normalize_dm_event_falls_back_to_peer_id_when_recipient_empty
    users_by_id = {"14100886" => {"id" => "14100886", "username" => "pengwynn"}}
    event = {"id" => "1", "sender_id" => "7505382", "text" => "test", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"}
    result = @probe.send(:normalize_dm_event, event, users_by_id, "7505382", true)

    assert_equal 14_100_886, result["recipient_id"]
  end

  def test_normalize_dm_event_uses_message_create_recipient
    users_by_id = {"14100886" => {"id" => "14100886", "username" => "pengwynn"}}
    event = {"id" => "1", "message_create" => {"sender_id" => "7505382", "target" => {"recipient_id" => "14100886"}, "message_data" => {"text" => "hi"}}, "created_timestamp" => "1356998400000"}
    result = @probe.send(:normalize_dm_event, event, users_by_id, "7505382", true)

    assert_equal 14_100_886, result["recipient_id"]
  end

  # ---------- extract_dm_users_by_id ----------

  def test_extract_dm_users_by_id_v1_array_format
    payload = {"users" => [{"id" => 7_505_382, "id_str" => "7505382", "screen_name" => "sferik"}, {"id" => 14_100_886, "id_str" => "14100886", "screen_name" => "pengwynn"}]}
    result = @probe.send(:extract_dm_users_by_id, payload)

    assert_equal "sferik", result["7505382"]["screen_name"]
    assert_equal "pengwynn", result["14100886"]["screen_name"]
  end

  def test_extract_dm_users_by_id_v1_hash_format
    payload = {"users" => {"7505382" => {"id_str" => "7505382", "screen_name" => "sferik"}, "14100886" => {"id_str" => "14100886", "screen_name" => "pengwynn"}}}
    result = @probe.send(:extract_dm_users_by_id, payload)

    assert_equal "sferik", result["7505382"]["screen_name"]
    assert_equal "pengwynn", result["14100886"]["screen_name"]
  end

  def test_extract_dm_users_by_id_skips_includes_without_id
    payload = {"includes" => {"users" => [{"username" => "noone"}, {"id" => "7505382", "username" => "sferik"}]}}

    assert_equal ["7505382"], @probe.send(:extract_dm_users_by_id, payload).keys
  end

  def test_extract_dm_users_by_id_handles_non_hash_value
    payload = {"users" => {"7505382" => "just_a_string"}}

    assert_equal "just_a_string", @probe.send(:extract_dm_users_by_id, payload)["7505382"]
  end

  def test_extract_dm_users_by_id_handles_empty_payload
    assert_equal({}, @probe.send(:extract_dm_users_by_id, {}))
  end

  def test_extract_dm_users_by_id_handles_array_entries_missing_id
    payload = {"users" => [{"username" => "noone"}]}

    assert_equal({}, @probe.send(:extract_dm_users_by_id, payload))
  end

  # ---------- dm_other_participant_id ----------

  def test_dm_other_participant_id_returns_nil_when_no_conversation_id
    event = {"sender_id" => "7505382"}

    assert_nil @probe.send(:dm_other_participant_id, event, "7505382")
  end

  def test_dm_other_participant_id_returns_other_participant
    event = {"dm_conversation_id" => "7505382-14100886"}

    assert_equal "14100886", @probe.send(:dm_other_participant_id, event, "7505382")
  end

  # ---------- dm_peer_id ----------

  def test_dm_peer_id_with_message_create_returns_recipient_when_sent
    event = {"message_create" => {"sender_id" => "7505382", "target" => {"recipient_id" => "14100886"}}}

    assert_equal "14100886", @probe.send(:dm_peer_id, event, "7505382", true)
  end

  def test_dm_peer_id_with_message_create_returns_sender_when_received
    event = {"message_create" => {"sender_id" => "14100886", "target" => {"recipient_id" => "7505382"}}}

    assert_equal "14100886", @probe.send(:dm_peer_id, event, "7505382", false)
  end

  def test_dm_peer_id_without_message_create_returns_other_when_sent
    event = {"sender_id" => "7505382", "dm_conversation_id" => "7505382-14100886"}

    assert_equal "14100886", @probe.send(:dm_peer_id, event, "7505382", true)
  end

  def test_dm_peer_id_without_message_create_returns_sender_when_received
    event = {"sender_id" => "14100886", "dm_conversation_id" => "7505382-14100886"}

    assert_equal "14100886", @probe.send(:dm_peer_id, event, "7505382", false)
  end

  def test_dm_peer_id_without_message_create_returns_other_when_received_and_sender_is_self
    event = {"sender_id" => "7505382", "dm_conversation_id" => "7505382-14100886"}

    assert_equal "14100886", @probe.send(:dm_peer_id, event, "7505382", false)
  end

  # ---------- dm_time ----------

  def test_dm_time_returns_epoch_for_unparseable_date
    result = @probe.send(:dm_time, {"created_at" => "not-a-valid-date"})

    assert_equal Time.at(0).utc, result
  end

  def test_dm_time_returns_time_directly_if_already_time
    t = Time.now.utc
    result = @probe.send(:dm_time, {"created_at" => t})

    assert_equal t, result
  end

  def test_dm_time_parses_created_timestamp
    result = @probe.send(:dm_time, {"created_timestamp" => "1356998400000"})

    assert_equal Time.at(1_356_998_400).utc, result
  end

  def test_dm_time_parses_created_at_string
    result = @probe.send(:dm_time, {"created_at" => "2023-01-01T00:00:00.000Z"})

    assert_equal 2023, result.year
  end

  # ---------- upload_media ----------

  def test_upload_media_uses_file_binread_for_path
    uc = with_upload_client
    uc.on_post { |_url, _body| {"media_id_string" => "12345"} }
    tmpfile = Tempfile.new("media")
    tmpfile.write("binary data")
    tmpfile.close

    assert_equal "12345", @probe.send(:upload_media, tmpfile.path)
  ensure
    tmpfile&.unlink
  end

  def test_upload_media_reads_and_rewinds_io
    uc = with_upload_client
    uc.on_post { |_url, _body| {"media_id_string" => "67890"} }

    assert_equal "67890", @probe.send(:upload_media, StringIO.new("image data here"))
  end

  def test_upload_media_raises_when_media_id_empty
    uc = with_upload_client
    uc.on_post { |_url, _body| {} }
    assert_raises(X::Error) { @probe.send(:upload_media, StringIO.new("image data here")) }
  end

  def test_upload_media_falls_back_to_media_id
    uc = with_upload_client
    uc.on_post { |_url, _body| {"media_id" => 12_345} }

    assert_equal "12345", @probe.send(:upload_media, StringIO.new("image data here"))
  end

  # ---------- extract_tweets ----------

  def test_extract_tweets_returns_array_directly
    assert_equal [{"id" => 1}], @probe.send(:extract_tweets, [{"id" => 1}])
  end

  def test_extract_tweets_returns_statuses_array
    assert_equal [{"id" => 1, "text" => "hi"}], @probe.send(:extract_tweets, {"statuses" => [{"id" => 1, "text" => "hi"}]})
  end

  def test_extract_tweets_with_v2_data_array
    value = {"data" => [{"id" => "1", "text" => "hello", "author_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik", "name" => "Erik"}]}}
    result = @probe.send(:extract_tweets, value)

    assert_equal "hello", result.first["text"]
    assert_equal "sferik", result.first["user"]["screen_name"]
  end

  def test_extract_tweets_with_single_v2_data_hash
    value = {"data" => {"id" => "1", "text" => "hello", "author_id" => "7505382"}, "includes" => {"users" => [{"id" => "7505382", "username" => "sferik", "name" => "Erik"}]}}
    result = @probe.send(:extract_tweets, value)

    assert_equal 1, result.size
    assert_equal "hello", result.first["text"]
  end

  def test_extract_tweets_returns_empty_when_no_data_key
    assert_equal [], @probe.send(:extract_tweets, {"meta" => {}})
  end

  # ---------- extract_users ----------

  def test_extract_users_returns_array_directly
    assert_equal [{"id" => 1}], @probe.send(:extract_users, [{"id" => 1}])
  end

  def test_extract_users_returns_users_array
    assert_equal [{"id" => 1}], @probe.send(:extract_users, {"users" => [{"id" => 1}]})
  end

  def test_extract_users_normalizes_v2_data_array
    value = {"data" => [{"id" => "7505382", "username" => "sferik", "name" => "Erik"}]}

    assert_equal "sferik", @probe.send(:extract_users, value).first["screen_name"]
  end

  def test_extract_users_wraps_single_v2_data_hash
    value = {"data" => {"id" => "7505382", "username" => "sferik", "name" => "Erik"}}
    result = @probe.send(:extract_users, value)

    assert_equal 1, result.size
    assert_equal "sferik", result.first["screen_name"]
  end

  def test_extract_users_returns_empty_when_no_data_key
    assert_equal [], @probe.send(:extract_users, {"meta" => {}})
  end

  def test_extract_users_wraps_bare_v1_user_with_screen_name
    v1_user = {"id" => 7_505_382, "id_str" => "7505382", "screen_name" => "sferik", "name" => "Erik Michaels-Ober"}
    result = @probe.send(:extract_users, v1_user)

    assert_equal [v1_user], result
    assert_equal "sferik", result.first["screen_name"]
  end

  def test_extract_users_wraps_bare_v1_user_with_only_id
    v1_user = {"id" => 7_505_382, "id_str" => "7505382", "name" => "Erik Michaels-Ober"}

    assert_equal [v1_user], @probe.send(:extract_users, v1_user)
  end

  def test_extract_users_returns_empty_for_bare_hash_without_screen_name_or_id
    assert_equal [], @probe.send(:extract_users, {"something" => "else"})
  end

  # ---------- extract_lists ----------

  def test_extract_lists_returns_array_directly
    assert_equal [{"id" => 1}], @probe.send(:extract_lists, [{"id" => 1}])
  end

  def test_extract_lists_returns_lists_array
    assert_equal [{"id" => 1}], @probe.send(:extract_lists, {"lists" => [{"id" => 1}]})
  end

  def test_extract_lists_returns_empty_when_data_not_array
    assert_equal [], @probe.send(:extract_lists, {"data" => "notarray"})
  end

  def test_extract_lists_normalizes_v2_data_array
    value = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}

    assert_equal "test", @probe.send(:extract_lists, value).first["slug"]
  end

  # ---------- normalize_v2_tweet ----------

  def test_normalize_v2_tweet_returns_as_is_when_has_user
    tweet = {"id" => 1, "text" => "hi", "user" => {"screen_name" => "sferik"}}

    assert_equal tweet, @probe.send(:normalize_v2_tweet, tweet, {}, {})
  end

  def test_normalize_v2_tweet_omits_id_when_no_id
    result = @probe.send(:normalize_v2_tweet, {"text" => "no id here"}, {}, {})

    refute result.key?("id")
    assert_equal "no id here", result["text"]
  end

  def test_normalize_v2_tweet_handles_no_text
    refute @probe.send(:normalize_v2_tweet, {"id" => "1"}, {}, {}).key?("text")
  end

  def test_normalize_v2_tweet_includes_created_at_when_present
    tweet = {"id" => "1", "text" => "hi", "created_at" => "2023-01-01T00:00:00.000Z"}

    assert_equal "2023-01-01T00:00:00.000Z", @probe.send(:normalize_v2_tweet, tweet, {}, {})["created_at"]
  end

  def test_normalize_v2_tweet_excludes_created_at_when_absent
    refute @probe.send(:normalize_v2_tweet, {"id" => "1", "text" => "hi"}, {}, {}).key?("created_at")
  end

  def test_normalize_v2_tweet_includes_source
    tweet = {"id" => "1", "text" => "hi", "source" => "Twitter for iPhone"}

    assert_equal "Twitter for iPhone", @probe.send(:normalize_v2_tweet, tweet, {}, {})["source"]
  end

  def test_normalize_v2_tweet_copies_entities_with_urls
    tweet = {"id" => "1", "text" => "hi", "entities" => {"urls" => [{"url" => "https://example.com"}]}}
    result = @probe.send(:normalize_v2_tweet, tweet, {}, {})

    assert_equal tweet["entities"], result["entities"]
    assert_equal [{"url" => "https://example.com"}], result["uris"]
  end

  def test_normalize_v2_tweet_copies_entities_without_urls
    tweet = {"id" => "1", "text" => "hi", "entities" => {"mentions" => [{"username" => "sferik"}]}}
    result = @probe.send(:normalize_v2_tweet, tweet, {}, {})

    assert_equal tweet["entities"], result["entities"]
    refute result.key?("uris")
  end

  def test_normalize_v2_tweet_maps_retweet_and_like_count
    tweet = {"id" => "1", "text" => "hi", "public_metrics" => {"retweet_count" => 5, "like_count" => 10}}
    result = @probe.send(:normalize_v2_tweet, tweet, {}, {})

    assert_equal 5, result["retweet_count"]
    assert_equal 10, result["favorite_count"]
  end

  def test_normalize_v2_tweet_only_like_count
    tweet = {"id" => "1", "text" => "hi", "public_metrics" => {"like_count" => 10}}
    result = @probe.send(:normalize_v2_tweet, tweet, {}, {})

    refute result.key?("retweet_count")
    assert_equal 10, result["favorite_count"]
  end

  def test_normalize_v2_tweet_only_retweet_count
    tweet = {"id" => "1", "text" => "hi", "public_metrics" => {"retweet_count" => 5}}
    result = @probe.send(:normalize_v2_tweet, tweet, {}, {})

    assert_equal 5, result["retweet_count"]
    refute result.key?("favorite_count")
  end

  def test_normalize_v2_tweet_skips_non_hash_public_metrics
    result = @probe.send(:normalize_v2_tweet, {"id" => "1", "text" => "hi", "public_metrics" => "invalid"}, {}, {})

    refute result.key?("retweet_count")
  end

  def test_normalize_v2_tweet_includes_author_user
    users = {"7505382" => {"id" => "7505382", "username" => "sferik", "name" => "Erik"}}
    result = @probe.send(:normalize_v2_tweet, {"id" => "1", "text" => "hi", "author_id" => "7505382"}, users, {})

    assert_equal "sferik", result["user"]["screen_name"]
  end

  def test_normalize_v2_tweet_creates_fallback_user
    result = @probe.send(:normalize_v2_tweet, {"id" => "1", "text" => "hi", "author_id" => "99999"}, {}, {})

    assert_equal "99999", result["user"]["screen_name"]
  end

  def test_normalize_v2_tweet_skips_user_when_no_author_id
    refute @probe.send(:normalize_v2_tweet, {"id" => "1", "text" => "hi"}, {}, {}).key?("user")
  end

  def test_normalize_v2_tweet_includes_place_from_geo
    places = {"abc" => {"id" => "abc", "name" => "SF"}}
    result = @probe.send(:normalize_v2_tweet, {"id" => "1", "text" => "hi", "geo" => {"place_id" => "abc"}}, {}, places)

    assert_equal "SF", result["place"]["name"]
  end

  def test_normalize_v2_tweet_includes_geo_coordinates
    tweet = {"id" => "1", "text" => "hi", "geo" => {"coordinates" => {"type" => "Point", "coordinates" => [37.7, -122.4]}}}

    assert_equal [37.7, -122.4], @probe.send(:normalize_v2_tweet, tweet, {}, {})["geo"]["coordinates"]
  end

  def test_normalize_v2_tweet_place_id_and_coordinates_includes_place_omits_geo
    places = {"abc" => {"id" => "abc", "name" => "SF"}}
    tweet = {"id" => "1", "text" => "hi", "geo" => {"place_id" => "abc", "coordinates" => {"type" => "Point", "coordinates" => [37.7, -122.4]}}}
    result = @probe.send(:normalize_v2_tweet, tweet, {}, places)

    assert_equal "SF", result["place"]["name"]
    refute result.key?("geo")
  end

  def test_normalize_v2_tweet_geo_no_place_or_coordinates
    result = @probe.send(:normalize_v2_tweet, {"id" => "1", "text" => "hi", "geo" => {"something" => "else"}}, {}, {})

    refute result.key?("place")
    refute result.key?("geo")
  end

  def test_normalize_v2_tweet_full_text_overrides_text
    result = @probe.send(:normalize_v2_tweet, {"id" => "1", "full_text" => "full version", "text" => "short"}, {}, {})

    assert_equal "full version", result["text"]
    assert_equal "full version", result["full_text"]
  end

  # ---------- normalize_v2_user ----------

  def test_normalize_v2_user_returns_as_is_with_screen_name
    user = {"id" => 1, "screen_name" => "sferik"}

    assert_equal user, @probe.send(:normalize_v2_user, user)
  end

  def test_normalize_v2_user_omits_id_when_no_id
    result = @probe.send(:normalize_v2_user, {"username" => "sferik", "name" => "Erik"})

    refute result.key?("id")
    assert_equal "sferik", result["screen_name"]
  end

  def test_normalize_v2_user_handles_no_username
    refute @probe.send(:normalize_v2_user, {"id" => "7505382"}).key?("screen_name")
  end

  def test_normalize_v2_user_maps_all_public_metrics
    user = {"id" => "7505382", "username" => "sferik", "public_metrics" => {"tweet_count" => 1000, "like_count" => 500, "listed_count" => 10, "following_count" => 50, "followers_count" => 100}}
    result = @probe.send(:normalize_v2_user, user)

    assert_equal 1000, result["statuses_count"]
    assert_equal 500, result["favourites_count"]
    assert_equal 500, result["favorites_count"]
    assert_equal 10, result["listed_count"]
    assert_equal 50, result["friends_count"]
    assert_equal 100, result["followers_count"]
  end

  def test_normalize_v2_user_only_tweet_count
    user = {"id" => "7505382", "username" => "sferik", "public_metrics" => {"tweet_count" => 1000}}
    result = @probe.send(:normalize_v2_user, user)

    assert_equal 1000, result["statuses_count"]
    refute result.key?("favourites_count")
    refute result.key?("listed_count")
    refute result.key?("friends_count")
    refute result.key?("followers_count")
  end

  def test_normalize_v2_user_skips_non_hash_public_metrics
    result = @probe.send(:normalize_v2_user, {"id" => "7505382", "username" => "sferik", "public_metrics" => "invalid"})

    refute result.key?("statuses_count")
  end

  def test_normalize_v2_user_copies_profile_attributes
    user = {"id" => "7505382", "username" => "sferik", "created_at" => "2007-07-16T12:59:01.000Z", "name" => "Erik", "verified" => false, "protected" => false, "description" => "Vagabond.", "location" => "SF", "url" => "https://example.com"}
    result = @probe.send(:normalize_v2_user, user)

    assert_equal "Erik", result["name"]
    assert_equal "Vagabond.", result["description"]
    assert_equal "SF", result["location"]
    assert_equal "https://example.com", result["url"]
  end

  # ---------- normalize_v2_list ----------

  def test_normalize_v2_list_returns_as_is_with_slug
    list = {"id" => 1, "slug" => "test", "name" => "test"}

    assert_equal list, @probe.send(:normalize_v2_list, list, {})
  end

  def test_normalize_v2_list_returns_as_is_with_full_name
    list = {"id" => 1, "full_name" => "@sferik/test"}

    assert_equal list, @probe.send(:normalize_v2_list, list, {})
  end

  def test_normalize_v2_list_omits_id_when_no_id
    result = @probe.send(:normalize_v2_list, {"name" => "test"}, {})

    refute result.key?("id")
    assert_equal "test", result["slug"]
  end

  def test_normalize_v2_list_handles_no_name
    refute @probe.send(:normalize_v2_list, {"id" => "1"}, {}).key?("slug")
  end

  def test_normalize_v2_list_includes_created_at
    result = @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "created_at" => "2023-01-01"}, {})

    assert_equal "2023-01-01", result["created_at"]
  end

  def test_normalize_v2_list_excludes_created_at_when_absent
    refute @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test"}, {}).key?("created_at")
  end

  def test_normalize_v2_list_includes_description
    result = @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "description" => "A test list"}, {})

    assert_equal "A test list", result["description"]
  end

  def test_normalize_v2_list_includes_member_count
    assert_equal 5, @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "member_count" => 5}, {})["member_count"]
  end

  def test_normalize_v2_list_excludes_member_count_when_absent
    refute @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test"}, {}).key?("member_count")
  end

  def test_normalize_v2_list_uses_mode_key
    assert_equal "public", @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "mode" => "public"}, {})["mode"]
  end

  def test_normalize_v2_list_derives_mode_from_private_true
    assert_equal "private", @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "private" => true}, {})["mode"]
  end

  def test_normalize_v2_list_derives_mode_from_private_false
    assert_equal "public", @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "private" => false}, {})["mode"]
  end

  def test_normalize_v2_list_excludes_mode_when_neither_present
    refute @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test"}, {}).key?("mode")
  end

  def test_normalize_v2_list_includes_owner_user
    users = {"7505382" => {"id" => "7505382", "username" => "sferik", "name" => "Erik"}}
    result = @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "owner_id" => "7505382"}, users)

    assert_equal "sferik", result["user"]["screen_name"]
    assert_equal "@sferik/test", result["full_name"]
  end

  def test_normalize_v2_list_omits_user_when_owner_not_found
    result = @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "owner_id" => "99999"}, {})

    refute result.key?("user")
    refute result.key?("full_name")
  end

  def test_normalize_v2_list_excludes_owner_when_no_owner_id
    refute @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test"}, {}).key?("user")
  end

  def test_normalize_v2_list_includes_uri_when_id_present
    assert_equal "https://x.com/i/lists/1", @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test"}, {})["uri"]
  end

  def test_normalize_v2_list_excludes_uri_when_no_id
    refute @probe.send(:normalize_v2_list, {"name" => "test"}, {}).key?("uri")
  end

  def test_normalize_v2_list_includes_user_hash_when_owner_has_no_screen_name
    users = {"7505382" => {"id" => "7505382"}}
    result = @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "owner_id" => "7505382"}, users)

    assert_kind_of Hash, result["user"]
    refute result.key?("full_name")
  end

  def test_normalize_v2_list_maps_slug_from_name
    assert_equal "test", @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test"}, {})["slug"]
  end

  def test_normalize_v2_list_uses_follower_count_as_subscriber_count
    assert_equal 42, @probe.send(:normalize_v2_list, {"id" => "1", "name" => "test", "follower_count" => 42}, {})["subscriber_count"]
  end

  # ---------- index_items_by_id ----------

  def test_index_items_by_id_skips_entries_without_id
    values = [{"id" => "1", "name" => "one"}, {"name" => "no_id"}, {"id" => "3", "name" => "three"}]

    assert_equal %w[1 3], @probe.send(:index_items_by_id, values).keys
  end

  def test_index_items_by_id_handles_nil
    assert_equal({}, @probe.send(:index_items_by_id, nil))
  end

  # ---------- t_form_pairs ----------

  def test_t_form_pairs_skips_nil_values
    assert_equal [%w[a 1], %w[c 3]], @probe.send(:t_form_pairs, {a: "1", b: nil, c: "3"})
  end

  # ---------- t_compact_hash ----------

  def test_t_compact_hash_skips_nil_values
    assert_equal({a: "1", c: "3"}, @probe.send(:t_compact_hash, {a: "1", b: nil, c: "3"}))
  end

  # ---------- t_scalar_value ----------

  def test_t_scalar_value_converts_true
    assert_equal "true", @probe.send(:t_scalar_value, true)
  end

  def test_t_scalar_value_converts_false
    assert_equal "false", @probe.send(:t_scalar_value, false)
  end

  def test_t_scalar_value_converts_other
    assert_equal "42", @probe.send(:t_scalar_value, 42)
  end

  # ---------- resolve_user ----------

  def test_resolve_user_returns_current_user_when_nil
    assert_equal "sferik", @probe.send(:resolve_user, nil)["username"]
  end

  def test_resolve_user_returns_hash_as_is
    user = {"id" => "123", "screen_name" => "test"}

    assert_equal user, @probe.send(:resolve_user, user)
  end

  def test_resolve_user_looks_up_by_numeric_id
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/14100886") then {"data" => {"id" => "14100886", "username" => "pengwynn"}}
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.send(:resolve_user, "14100886")["screen_name"]
  end

  def test_resolve_user_looks_up_by_screen_name
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/pengwynn") then {"data" => {"id" => "14100886", "username" => "pengwynn"}}
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.send(:resolve_user, "pengwynn")["screen_name"]
  end

  # ---------- resolve_user_id ----------

  def test_resolve_user_id_returns_current_user_id_when_nil
    assert_equal "7505382", @probe.send(:resolve_user_id, nil)
  end

  def test_resolve_user_id_returns_id_from_hash
    assert_equal "14100886", @probe.send(:resolve_user_id, {"id" => "14100886"})
  end

  def test_resolve_user_id_returns_numeric_entry_as_is
    assert_equal "14100886", @probe.send(:resolve_user_id, "14100886")
  end

  def test_resolve_user_id_looks_up_by_screen_name
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/pengwynn") then {"data" => {"id" => "14100886", "username" => "pengwynn"}}
      else {"data" => []}
      end
    end

    assert_equal "14100886", @probe.send(:resolve_user_id, "pengwynn")
  end

  # ---------- x_user ----------

  def test_x_user_calls_before_request_callback
    tweets = [{"id" => "1", "text" => "hello", "full_text" => "hello", "user" => {"screen_name" => "test"}}]
    @probe.define_singleton_method(:x_home_timeline) { |**_| tweets }
    called = false
    @probe.x_before_request { called = true }
    @probe.x_user(nil) { |_t| nil }

    assert called
  end

  def test_x_user_yields_home_timeline_tweets
    tweets = [{"id" => "1", "text" => "hello", "full_text" => "hello", "user" => {"screen_name" => "test"}}]
    @probe.define_singleton_method(:x_home_timeline) { |**_| tweets }
    @probe.x_before_request { nil }
    collected = []
    @probe.x_user(nil) { |t| collected << t }

    assert_equal tweets, collected
  end

  def test_x_user_looks_up_by_numeric_id
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/14100886") then {"data" => {"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}}
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.x_user("14100886")["screen_name"]
  end

  def test_x_user_looks_up_by_screen_name
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/pengwynn") then {"data" => {"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}}
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.x_user("pengwynn")["screen_name"]
  end

  # ---------- x_before_request ----------

  def test_x_before_request_stores_callback
    called = false
    @probe.x_before_request { called = true }
    @probe.instance_variable_get(:@requestable_api_before_request).call

    assert called
  end

  # ---------- Pagination ----------

  def test_fetch_relationship_ids_follows_next_token
    page1 = {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1, "next_token" => "abc123"}}
    page2 = {"data" => [{"id" => "7505382", "username" => "sferik"}], "meta" => {"result_count" => 1}}
    call_count = 0
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("followers")
        call_count += 1
        call_count == 1 ? page1 : page2
      else
        {"data" => []}
      end
    end

    assert_equal %w[14100886 7505382], @probe.send(:fetch_relationship_ids, "7505382", "followers")
  end

  def test_fetch_relationship_ids_uses_following_endpoint
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("following") then {"data" => [{"id" => "14100886"}], "meta" => {"result_count" => 1}}
      else {"data" => []}
      end
    end

    assert_equal ["14100886"], @probe.send(:fetch_relationship_ids, "7505382", "following")
  end

  def test_x_retweeters_ids_follows_next_token
    page1 = {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1, "next_token" => "retweetpage2"}}
    page2 = {"data" => [{"id" => "7505382", "username" => "sferik"}], "meta" => {"result_count" => 1}}
    call_count = 0
    @fake_client.on_get do |url|
      if url.include?("retweeted_by")
        call_count += 1
        call_count == 1 ? page1 : page2
      else
        {"data" => []}
      end
    end

    assert_equal %w[14100886 7505382], @probe.x_retweeters_ids("12345")
  end

  def test_x_muted_ids_follows_next_token
    page1 = {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1, "next_token" => "mutenextpage"}}
    page2 = {"data" => [{"id" => "7505382", "username" => "sferik"}], "meta" => {"result_count" => 1}}
    call_count = 0
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("muting")
        call_count += 1
        call_count == 1 ? page1 : page2
      else
        {"data" => []}
      end
    end

    assert_equal %w[14100886 7505382], @probe.x_muted_ids
  end

  def test_fetch_list_member_ids_follows_next_token
    page1 = {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1, "next_token" => "listnextpage"}}
    page2 = {"data" => [{"id" => "7505382", "username" => "sferik"}], "meta" => {"result_count" => 1}}
    call_count = 0
    @fake_client.on_get do |url|
      if url.include?("members")
        call_count += 1
        call_count == 1 ? page1 : page2
      else
        {"data" => []}
      end
    end

    assert_equal %w[14100886 7505382], @probe.send(:fetch_list_member_ids, "1234")
  end

  def test_collect_owned_lists_follows_next_token
    first_page = {"data" => [{"id" => "1", "name" => "List One", "description" => "First", "member_count" => 5, "follower_count" => 3, "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik", "name" => "Erik"}]}, "meta" => {"result_count" => 1, "next_token" => "ownedlistpage2"}}
    second_page = {"data" => [{"id" => "2", "name" => "List Two", "description" => "Second", "member_count" => 10, "follower_count" => 7, "private" => true, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik", "name" => "Erik"}]}, "meta" => {"result_count" => 1}}
    call_count = 0
    @fake_client.on_get do |url|
      if url.include?("owned_lists")
        call_count += 1
        call_count == 1 ? first_page : second_page
      else
        {"data" => []}
      end
    end
    result = @probe.send(:collect_owned_lists, "7505382")

    assert_equal 2, result.size
    assert_equal "List One", result.first["slug"]
    assert_equal "List Two", result.last["slug"]
  end

  # ---------- fetch_direct_messages_payload fallback ----------

  def test_fetch_dm_payload_falls_back_to_v1_on_forbidden
    v1 = with_v1_client
    v1.on_get { |_url| {"events" => []} }
    resp = build_http_response(Net::HTTPForbidden, "403", "Forbidden")
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events") then raise X::Forbidden.new(response: resp)
      else {"data" => []}
      end
    end
    @probe.send(:fetch_direct_messages_payload, 50)

    assert_operator v1.get_calls.size, :>=, 1
  end

  def test_fetch_dm_payload_falls_back_to_v1_on_not_found
    v1 = with_v1_client
    v1.on_get { |_url| {"events" => []} }
    resp = build_http_response(Net::HTTPNotFound, "404", "Not Found")
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events") then raise X::NotFound.new(response: resp)
      else {"data" => []}
      end
    end
    @probe.send(:fetch_direct_messages_payload, 50)

    assert_operator v1.get_calls.size, :>=, 1
  end

  # ---------- normalize_user_with_pinned_status ----------

  def test_normalize_user_with_pinned_status_includes_pinned_tweet
    user = {"id" => "7505382", "username" => "sferik", "pinned_tweet_id" => "222034648631484416"}
    tweets = {"222034648631484416" => {"id" => "222034648631484416", "text" => "pinned tweet"}}
    result = @probe.send(:normalize_user_with_pinned_status, user, tweets)

    assert_kind_of Hash, result["status"]
    assert_equal "pinned tweet", result["status"]["text"]
  end

  def test_normalize_user_with_pinned_status_excludes_when_not_in_includes
    user = {"id" => "7505382", "username" => "sferik", "pinned_tweet_id" => "222034648631484416"}

    refute @probe.send(:normalize_user_with_pinned_status, user, {}).key?("status")
  end

  def test_normalize_user_with_pinned_status_excludes_when_no_pinned_tweet_id
    refute @probe.send(:normalize_user_with_pinned_status, {"id" => "7505382", "username" => "sferik"}, {}).key?("status")
  end

  def test_normalize_user_with_pinned_status_returns_hash_for_empty_input
    result = @probe.send(:normalize_user_with_pinned_status, {}, {})

    assert_kind_of Hash, result
    refute result.key?("status")
  end

  # ---------- value_id ----------

  def test_value_id_returns_nil_for_string
    assert_nil @probe.send(:value_id, "string")
  end

  def test_value_id_returns_nil_for_nil
    assert_nil @probe.send(:value_id, nil)
  end

  def test_value_id_prefers_id_str
    assert_equal "123", @probe.send(:value_id, {"id_str" => "123", "id" => 456})
  end

  def test_value_id_falls_back_to_id
    assert_equal "456", @probe.send(:value_id, {"id" => 456})
  end

  def test_value_id_returns_nil_for_hash_without_id
    assert_nil @probe.send(:value_id, {"name" => "test"})
  end

  # ---------- extract_ids ----------

  def test_extract_ids_from_data_array
    assert_equal %w[1 2], @probe.send(:extract_ids, {"data" => [{"id" => "1"}, {"id" => "2"}]})
  end

  def test_extract_ids_returns_empty_when_data_not_array
    assert_equal [], @probe.send(:extract_ids, {"data" => "notarray"})
  end

  def test_extract_ids_skips_entries_without_id
    assert_equal ["1"], @probe.send(:extract_ids, {"data" => [{"id" => "1"}, {"name" => "no id"}]})
  end

  # ---------- x_friendship? ----------

  def test_x_friendship_returns_true_when_following
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("following") then {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1}}
      elsif url.include?("users/by/username") then {"data" => {"id" => "14100886", "username" => "pengwynn"}}
      elsif url.include?("users/7505382") && !url.include?("following") then {"data" => {"id" => "7505382", "username" => "sferik"}}
      else {"data" => []}
      end
    end

    assert @probe.x_friendship?("7505382", "14100886")
  end

  # ---------- x_friend_ids / x_follower_ids ----------

  def test_x_friend_ids_uses_current_user_id
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("following") then {"data" => [{"id" => "14100886"}], "meta" => {"result_count" => 1}}
      else {"data" => []}
      end
    end

    assert_equal ["14100886"], @probe.x_friend_ids
  end

  def test_x_friend_ids_resolves_user
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("following") then {"data" => [{"id" => "999"}], "meta" => {"result_count" => 1}}
      else {"data" => []}
      end
    end

    assert_equal ["999"], @probe.x_friend_ids("7505382")
  end

  def test_x_follower_ids_uses_current_user_id
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("followers") then {"data" => [{"id" => "14100886"}], "meta" => {"result_count" => 1}}
      else {"data" => []}
      end
    end

    assert_equal ["14100886"], @probe.x_follower_ids
  end

  # ---------- x_block ----------

  def test_x_block_blocks_users
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/pengwynn") then {"data" => {"id" => "14100886", "username" => "pengwynn"}}
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.x_block(["pengwynn"]).first["screen_name"]
  end

  # ---------- x_favorite / x_unfavorite / x_retweet / x_destroy_status ----------

  def test_x_favorite_single_tweet
    assert_equal 12_345, @probe.x_favorite("12345")["id"]
  end

  def test_x_favorite_multiple_tweets
    assert_equal 2, @probe.x_favorite(%w[12345 67890]).size
  end

  def test_x_unfavorite_single_tweet
    assert_equal 12_345, @probe.x_unfavorite("12345")["id"]
  end

  def test_x_retweet_single_tweet
    assert_equal 12_345, @probe.x_retweet("12345")["id"]
  end

  def test_x_destroy_status_single_tweet
    assert_equal 12_345, @probe.x_destroy_status("12345")["id"]
  end

  # ---------- x_update ----------

  def test_x_update_returns_posted_tweet_text
    @fake_client.on_post { |_url, _body| {"data" => {"id" => "99999"}} }

    assert_equal "Hello world", @probe.x_update("Hello world")["text"]
  end

  def test_x_update_returns_posted_tweet_id
    @fake_client.on_post { |_url, _body| {"data" => {"id" => "99999"}} }

    assert_equal 99_999, @probe.x_update("Hello world")["id"]
  end

  def test_x_update_passes_in_reply_to
    @fake_client.on_post { |_url, _body| {"data" => {"id" => "99999"}} }

    assert_equal "Reply", @probe.x_update("Reply", in_reply_to_status_id: "12345")["text"]
  end

  def test_x_update_passes_media_ids
    @fake_client.on_post { |_url, _body| {"data" => {"id" => "99999"}} }

    assert_equal "With media", @probe.x_update("With media", media_ids: ["111"])["text"]
  end

  # ---------- x_update_with_media ----------

  def test_x_update_with_media_uploads_and_posts
    uc = with_upload_client
    uc.on_post { |_url, _body| {"media_id_string" => "111"} }
    @fake_client.on_post { |_url, _body| {"data" => {"id" => "99999"}} }

    assert_equal "Hello", @probe.x_update_with_media("Hello", StringIO.new("image data"))["text"]
  end

  # ---------- x_home_timeline ----------

  def test_x_home_timeline_returns_tweets
    resp = {"data" => [{"id" => "1", "text" => "hello", "author_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("reverse_chronological") then resp
      else {"data" => []}
      end
    end

    assert_equal "hello", @probe.x_home_timeline.first["text"]
  end

  # ---------- x_favorites ----------

  def test_x_favorites_uses_current_user_when_nil
    resp = {"data" => [{"id" => "1", "text" => "fav tweet", "author_id" => "999"}], "includes" => {"users" => [{"id" => "999", "username" => "someone"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("liked_tweets") then resp
      else {"data" => []}
      end
    end

    assert_equal "fav tweet", @probe.x_favorites.first["text"]
  end

  def test_x_favorites_treats_hash_first_arg_as_opts
    resp = {"data" => [{"id" => "1", "text" => "fav tweet", "author_id" => "999"}], "includes" => {"users" => [{"id" => "999", "username" => "someone"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("liked_tweets") then resp
      else {"data" => []}
      end
    end

    assert_equal "fav tweet", @probe.x_favorites({count: 10}).first["text"]
  end

  # ---------- x_lists / x_list / x_create_list ----------

  def test_x_lists_for_current_user
    resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then resp
      else {"data" => []}
      end
    end

    assert_equal "test", @probe.x_lists.first["slug"]
  end

  def test_x_list_by_numeric_id
    resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      if url.include?("lists/1") then resp
      else {"data" => []}
      end
    end

    assert_equal "test", @probe.x_list("1")["slug"]
  end

  def test_x_create_list
    @fake_client.on_post { |_url, _body| {"data" => [{"id" => "1", "name" => "newlist", "private" => false}]} }

    assert_equal "newlist", @probe.x_create_list("newlist", description: "desc", mode: "private")["slug"]
  end

  # ---------- x_add_list_members ----------

  def test_x_add_list_members
    owned_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then owned_resp
      elsif url.include?("users/by/username/pengwynn") then {"data" => {"id" => "14100886", "username" => "pengwynn"}}
      else {"data" => []}
      end
    end

    assert @probe.x_add_list_members("test", ["pengwynn"])
  end

  # ---------- x_list_member? ----------

  def test_x_list_member_checks_membership
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/sferik") then {"data" => {"id" => "7505382", "username" => "sferik"}}
      elsif url.include?("users/by/username/pengwynn") then {"data" => {"id" => "14100886", "username" => "pengwynn"}}
      elsif url.include?("owned_lists") then {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
      elsif url.include?("members") then {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1}}
      else {"data" => []}
      end
    end

    assert @probe.x_list_member?("sferik", "test", "pengwynn")
  end

  # ---------- x_report_spam ----------

  def test_x_report_spam_by_username
    v1 = with_v1_client
    v1.on_post { |_url, _body| {} }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/spammer") then {"data" => {"id" => "14100886", "username" => "spammer"}}
      else {"data" => []}
      end
    end

    assert_equal "spammer", @probe.x_report_spam(["spammer"]).first["screen_name"]
  end

  # ---------- x_status ----------

  def test_x_status_fetches_single_status
    resp = {"data" => {"id" => "12345", "text" => "hello", "author_id" => "7505382"}, "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      url.include?("tweets/12345") ? resp : {"data" => []}
    end

    assert_equal "hello", @probe.x_status("12345")["text"]
  end

  # ---------- x_retweets_of_me ----------

  def test_x_retweets_of_me
    resp = {"data" => [{"id" => "1", "text" => "RT @someone", "author_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("reposts_of_me") then resp
      else {"data" => []}
      end
    end

    assert_equal "RT @someone", @probe.x_retweets_of_me.first["text"]
  end

  # ---------- x_destroy_direct_message ----------

  def test_x_destroy_direct_message
    assert @probe.x_destroy_direct_message("111", "222")
  end

  # ---------- x_settings ----------

  def test_x_settings
    v1 = with_v1_client
    v1.on_post { |_url, _body| {} }

    assert @probe.x_settings(lang: "en")
  end

  # ---------- x_update_profile ----------

  def test_x_update_profile
    v1 = with_v1_client
    v1.on_post { |_url, _body| {"data" => {"id" => "7505382", "username" => "sferik"}} }

    assert_kind_of Hash, @probe.x_update_profile(description: "New bio", location: "NYC", name: "New Name", url: "https://example.com")
  end

  # ---------- x_update_profile_image ----------

  def test_x_update_profile_image
    v1 = with_v1_client
    v1.on_post { |_url, _body| {"data" => {"id" => "7505382", "username" => "sferik"}} }

    assert_kind_of Hash, @probe.x_update_profile_image(StringIO.new("image data"))
  end

  # ---------- x_trend_locations ----------

  def test_x_trend_locations_returns_woeid
    v1 = with_v1_client
    v1.on_get { |_url| [{"woeid" => 1, "parentid" => 0, "placeType" => {"name" => "Town"}, "name" => "Worldwide", "country" => ""}] }
    result = @probe.x_trend_locations

    assert_equal 1, result.first["woeid"]
    assert_equal "Town", result.first["place_type"]
  end

  # ---------- direct_messages_for with user lookup ----------

  def test_dm_received_looks_up_unknown_peer_users
    events_resp = {"data" => [{"id" => "1", "event_type" => "MessageCreate", "sender_id" => "99999", "text" => "from unknown", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-99999"}], "meta" => {"result_count" => 1}}
    user_lookup_resp = {"data" => [{"id" => "99999", "username" => "unknown_user", "name" => "Unknown"}]}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events") then events_resp
      elsif url.include?("users") && url.include?("ids=99999") then user_lookup_resp
      else {"data" => []}
      end
    end

    assert_equal "from unknown", @probe.x_direct_messages_received.first["text"]
  end

  # ---------- dm_text / dm_urls ----------

  def test_dm_text_from_message_create
    assert_equal "hello from v1", @probe.send(:dm_text, {"message_create" => {"message_data" => {"text" => "hello from v1"}}})
  end

  def test_dm_text_from_top_level
    assert_equal "hello v2", @probe.send(:dm_text, {"text" => "hello v2"})
  end

  def test_dm_text_empty_when_no_text
    assert_equal "", @probe.send(:dm_text, {})
  end

  def test_dm_urls_from_message_create
    event = {"message_create" => {"message_data" => {"entities" => {"urls" => [{"url" => "http://example.com"}]}}}}

    assert_equal [{"url" => "http://example.com"}], @probe.send(:dm_urls, event)
  end

  def test_dm_urls_from_top_level
    assert_equal [{"url" => "http://example.com"}], @probe.send(:dm_urls, {"urls" => [{"url" => "http://example.com"}]})
  end

  def test_dm_urls_empty_when_none
    assert_equal [], @probe.send(:dm_urls, {})
  end

  # ---------- dm_event_type ----------

  def test_dm_event_type_downcases_type
    assert_equal "messagecreate", @probe.send(:dm_event_type, {"type" => "MessageCreate"})
  end

  def test_dm_event_type_strips_underscores
    assert_equal "messagecreate", @probe.send(:dm_event_type, {"event_type" => "Message_Create"})
  end

  def test_dm_event_type_defaults_to_messagecreate
    assert_equal "messagecreate", @probe.send(:dm_event_type, {})
  end

  # ---------- extract_dm_events ----------

  def test_extract_dm_events_from_events_key
    assert_equal [{"id" => "1"}], @probe.send(:extract_dm_events, {"events" => [{"id" => "1"}]})
  end

  def test_extract_dm_events_from_data_key
    assert_equal [{"id" => "1"}], @probe.send(:extract_dm_events, {"data" => [{"id" => "1"}]})
  end

  def test_extract_dm_events_wraps_single_hash
    assert_equal [{"id" => "1"}], @probe.send(:extract_dm_events, {"data" => {"id" => "1"}})
  end

  def test_extract_dm_events_returns_empty_when_none
    assert_equal [], @probe.send(:extract_dm_events, {})
  end

  # ---------- single_or_array ----------

  def test_single_or_array_returns_array_when_input_is_array
    assert_equal %w[x y], @probe.send(:single_or_array, ["a"], %w[x y])
  end

  def test_single_or_array_returns_first_when_input_is_not_array
    assert_equal "x", @probe.send(:single_or_array, "a", %w[x y])
  end

  # ---------- strip_at ----------

  def test_strip_at_removes_prefix
    assert_equal "sferik", @probe.send(:strip_at, "@sferik")
  end

  def test_strip_at_returns_unchanged
    assert_equal "sferik", @probe.send(:strip_at, "sferik")
  end

  # ---------- slugify_list_name ----------

  def test_slugify_list_name
    assert_equal "my-cool-list", @probe.send(:slugify_list_name, "My Cool List!")
  end

  # ---------- numeric_identifier? ----------

  def test_numeric_identifier_true
    assert @probe.send(:numeric_identifier?, "12345")
  end

  def test_numeric_identifier_false
    refute @probe.send(:numeric_identifier?, "sferik")
  end

  # ---------- t_normalize_path ----------

  def test_t_normalize_path_strips_leading_slash
    assert_equal "foo/bar", @probe.send(:t_normalize_path, "/foo/bar")
  end

  def test_t_normalize_path_unchanged_without_leading_slash
    assert_equal "foo/bar", @probe.send(:t_normalize_path, "foo/bar")
  end

  # ---------- t_endpoint ----------

  def test_t_endpoint_without_params
    assert_equal "test/path", @probe.send(:t_endpoint, "test/path", {})
  end

  def test_t_endpoint_with_params
    assert_equal "test/path?a=1", @probe.send(:t_endpoint, "test/path", {a: "1"})
  end

  # ---------- setup_requestable_api! ----------

  def test_setup_requestable_api_sets_up_on_first_call
    new_probe = RequestableAPIProbe.new(@fake_client)
    credentials = {api_key: "k", api_key_secret: "s", access_token: "t", access_token_secret: "ts"}
    new_probe.instance_variable_set(:@requestable_api_setup, false)
    new_probe.setup_requestable_api!(credentials)

    assert new_probe.instance_variable_get(:@requestable_api_setup)
  end

  def test_setup_requestable_api_remains_set_up
    new_probe = RequestableAPIProbe.new(@fake_client)
    credentials = {api_key: "k", api_key_secret: "s", access_token: "t", access_token_secret: "ts"}
    new_probe.instance_variable_set(:@requestable_api_setup, false)
    new_probe.setup_requestable_api!(credentials)
    new_probe.setup_requestable_api!(credentials)

    assert new_probe.instance_variable_get(:@requestable_api_setup)
  end

  # ---------- x_retweeted_by_me ----------

  def test_x_retweeted_by_me_delegates
    @probe.define_singleton_method(:x_retweets_of_me) { |_opts = {}| [{"id" => 1}] }

    assert_equal [{"id" => 1}], @probe.x_retweeted_by_me
  end

  # ---------- x_retweeted_by_user ----------

  def test_x_retweeted_by_user_returns_only_retweets
    tweets = [{"id" => 1, "text" => "hello", "full_text" => "hello"}, {"id" => 2, "text" => "RT @someone: hi", "full_text" => "RT @someone: hi"}]
    @probe.define_singleton_method(:x_user_timeline) { |*_args, **_opts| tweets }
    result = @probe.x_retweeted_by_user("sferik")

    assert_equal 1, result.size
    assert result.first["full_text"].start_with?("RT @")
  end

  # ---------- x_mentions ----------

  def test_x_mentions
    resp = {"data" => [{"id" => "1", "text" => "@sferik hello", "author_id" => "999"}], "includes" => {"users" => [{"id" => "999", "username" => "someone"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("mentions") then resp
      else {"data" => []}
      end
    end

    assert_equal "@sferik hello", @probe.x_mentions.first["text"]
  end

  # ---------- x_user_timeline ----------

  def test_x_user_timeline
    resp = {"data" => [{"id" => "1", "text" => "tweet", "author_id" => "14100886"}], "includes" => {"users" => [{"id" => "14100886", "username" => "pengwynn"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/14100886/tweets") then resp
      else {"data" => []}
      end
    end

    assert_equal "tweet", @probe.x_user_timeline("14100886").first["text"]
  end

  # ---------- x_list_timeline ----------

  def test_x_list_timeline
    owned_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    timeline_resp = {"data" => [{"id" => "1", "text" => "list tweet", "author_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then owned_resp
      elsif url.include?("lists/") && url.include?("tweets") then timeline_resp
      else {"data" => []}
      end
    end

    assert_equal "list tweet", @probe.x_list_timeline("7505382", "test").first["text"]
  end

  # ---------- x_remove_list_members ----------

  def test_x_remove_list_members
    owned_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then owned_resp
      else {"data" => []}
      end
    end

    assert @probe.x_remove_list_members("test", ["14100886"])
  end

  # ---------- x_list_members ----------

  def test_x_list_members
    owned_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    members_resp = {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1}}
    user_lookup_resp = {"data" => [{"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}]}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then owned_resp
      elsif url.include?("members") then members_resp
      elsif url.include?("users") && url.include?("ids=") then user_lookup_resp
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.x_list_members("7505382", "test").first["screen_name"]
  end

  # ---------- lookup_users_by_ids ----------

  def test_lookup_users_by_ids_returns_empty_for_empty
    assert_equal [], @probe.send(:lookup_users_by_ids, [])
  end

  # ---------- timeline_v2_params ----------

  def test_timeline_v2_params_exclude_replies
    params = @probe.send(:timeline_v2_params, {exclude_replies: true})

    assert_includes params[:exclude], "replies"
  end

  def test_timeline_v2_params_exclude_retweets
    params = @probe.send(:timeline_v2_params, {include_rts: false})

    assert_includes params[:exclude], "retweets"
  end

  def test_timeline_v2_params_maps_max_id_to_until_id
    params = @probe.send(:timeline_v2_params, {max_id: "100", since_id: "50"})

    assert_equal "100", params[:until_id]
    assert_equal "50", params[:since_id]
  end

  def test_timeline_v2_params_no_exclude_when_empty
    params = @probe.send(:timeline_v2_params, {})

    refute params.key?(:exclude)
  end

  # ---------- Additional coverage ----------

  def test_x_follower_ids_with_user
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("followers") then {"data" => [{"id" => "999"}], "meta" => {"result_count" => 1}}
      else {"data" => []}
      end
    end

    assert_equal ["999"], @probe.x_follower_ids("14100886")
  end

  def test_x_report_spam_with_numeric_id
    v1 = with_v1_client
    v1.on_post { |_url, _body| {} }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/14100886") then {"data" => {"id" => "14100886", "username" => "spammer"}}
      else {"data" => []}
      end
    end

    assert_equal "spammer", @probe.x_report_spam(["14100886"]).first["screen_name"]
  end

  def test_x_favorites_with_specific_user
    resp = {"data" => [{"id" => "1", "text" => "fav tweet", "author_id" => "14100886"}], "includes" => {"users" => [{"id" => "14100886", "username" => "pengwynn"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("liked_tweets") then resp
      else {"data" => []}
      end
    end

    assert_equal "fav tweet", @probe.x_favorites("14100886").first["text"]
  end

  def test_x_direct_message_data_hash_fallback
    dm_resp = {
      "events" => [],
      "data" => {"id" => "999", "event_type" => "MessageCreate", "sender_id" => "7505382", "text" => "hello", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-14100886"},
      "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}, {"id" => "14100886", "username" => "pengwynn"}]},
    }
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events/") then dm_resp
      else {"data" => []}
      end
    end

    assert_equal 999, @probe.x_direct_message("999")["id"]
  end

  def test_x_lists_with_specific_user
    resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "14100886"}], "includes" => {"users" => [{"id" => "14100886", "username" => "pengwynn"}]}, "meta" => {"result_count" => 1}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then resp
      else {"data" => []}
      end
    end

    assert_equal "test", @probe.x_lists("14100886").first["slug"]
  end

  def test_x_list_with_non_numeric_owner_and_list_name
    user_resp = {"data" => {"id" => "7505382", "username" => "sferik"}}
    owned_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    list_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/sferik") then user_resp
      elsif url.include?("owned_lists") then owned_resp
      elsif url.include?("lists/1") then list_resp
      else {"data" => []}
      end
    end

    assert_equal "test", @probe.x_list("sferik", "test")["slug"]
  end

  def test_x_list_with_numeric_owner_and_list_name
    owned_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    list_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then owned_resp
      elsif url.include?("lists/1") then list_resp
      else {"data" => []}
      end
    end

    assert_equal "test", @probe.x_list("7505382", "test")["slug"]
  end

  def test_x_list_by_name_when_non_numeric
    owned_resp = {"data" => [{"id" => "1", "name" => "mylist", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    list_resp = {"data" => [{"id" => "1", "name" => "mylist", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then owned_resp
      elsif url.include?("lists/1") then list_resp
      else {"data" => []}
      end
    end

    assert_equal "mylist", @probe.x_list("mylist")["slug"]
  end

  def test_x_list_member_with_numeric_owner
    owned_resp = {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
    members_resp = {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1}}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("owned_lists") then owned_resp
      elsif url.include?("members") then members_resp
      else {"data" => []}
      end
    end

    assert @probe.x_list_member?("7505382", "test", "14100886")
  end

  def test_x_list_members_with_non_numeric_owner
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/sferik") then {"data" => {"id" => "7505382", "username" => "sferik"}}
      elsif url.include?("owned_lists") then {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
      elsif url.include?("members") then {"data" => [{"id" => "14100886", "username" => "pengwynn"}], "meta" => {"result_count" => 1}}
      elsif url.include?("users") && url.include?("ids=") then {"data" => [{"id" => "14100886", "username" => "pengwynn", "name" => "Wynn"}]}
      else {"data" => []}
      end
    end

    assert_equal "pengwynn", @probe.x_list_members("sferik", "test").first["screen_name"]
  end

  def test_x_list_timeline_with_non_numeric_owner
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("users/by/username/sferik") then {"data" => {"id" => "7505382", "username" => "sferik"}}
      elsif url.include?("owned_lists") then {"data" => [{"id" => "1", "name" => "test", "private" => false, "owner_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}, "meta" => {"result_count" => 1}}
      elsif url.include?("lists/") && url.include?("tweets") then {"data" => [{"id" => "1", "text" => "list tweet", "author_id" => "7505382"}], "includes" => {"users" => [{"id" => "7505382", "username" => "sferik"}]}}
      else {"data" => []}
      end
    end

    assert_equal "list tweet", @probe.x_list_timeline("sferik", "test").first["text"]
  end

  def test_x_update_profile_with_no_params
    v1 = with_v1_client
    v1.on_post { |_url, _body| {} }

    assert_kind_of Hash, @probe.x_update_profile
  end

  def test_x_update_profile_background_image_with_tile_false
    v1 = with_v1_client
    v1.on_post { |_url, _body| {} }

    assert @probe.x_update_profile_background_image(StringIO.new("imagedata"))
  end

  def test_dm_received_with_user_lookup_returning_nil_id
    events_resp = {"data" => [{"id" => "1", "event_type" => "MessageCreate", "sender_id" => "99999", "text" => "hi", "created_at" => "2023-01-01T00:00:00.000Z", "dm_conversation_id" => "7505382-99999"}], "meta" => {"result_count" => 1}}
    user_lookup_resp = {"data" => [{"username" => "unknown_no_id"}]}
    @fake_client.on_get do |url|
      if url.include?("users/me") then ME_RESPONSE
      elsif url.include?("dm_events") then events_resp
      elsif url.include?("users") && url.include?("ids=") then user_lookup_resp
      else {"data" => []}
      end
    end
    result = @probe.x_direct_messages_received

    assert_equal 1, result.size
    assert_equal({}, result.first["recipient"])
  end

  def test_normalize_dm_event_with_empty_message_create_recipient
    event = {"id" => "1", "message_create" => {"sender_id" => "7505382", "target" => {"recipient_id" => ""}, "message_data" => {"text" => "test"}}, "created_timestamp" => "1356998400000", "dm_conversation_id" => "7505382-14100886"}
    users_by_id = {"14100886" => {"id" => "14100886", "username" => "pengwynn"}}
    result = @probe.send(:normalize_dm_event, event, users_by_id, "7505382", true)

    assert_equal "test", result["text"]
  end

  def test_upload_media_with_non_rewindable_io
    uc = with_upload_client
    uc.on_post { |_url, _body| {"media_id_string" => "12345"} }
    reader = Object.new
    reader.define_singleton_method(:read) { "binary data" }
    original_respond_to = reader.method(:respond_to?)
    reader.define_singleton_method(:respond_to?) do |method, *args|
      method.to_s == "rewind" ? false : original_respond_to.call(method, *args)
    end

    assert_equal "12345", @probe.send(:upload_media, reader)
  end

  def test_normalize_v2_user_without_tweet_count_in_metrics
    user = {"id" => "7505382", "username" => "sferik", "public_metrics" => {"like_count" => 500, "listed_count" => 10, "following_count" => 50, "followers_count" => 100}}
    result = @probe.send(:normalize_v2_user, user)

    refute result.key?("statuses_count")
    assert_equal 500, result["favourites_count"]
    assert_equal 10, result["listed_count"]
    assert_equal 50, result["friends_count"]
    assert_equal 100, result["followers_count"]
  end
end
