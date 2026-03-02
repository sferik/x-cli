require "test_helper"

class TestStream < TTestCase
  def setup
    super
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
    $stdout = StringIO.new
    def $stdout.tty? = true
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @stream_cmd = T::Stream.new
    @tweet = tweet_from_fixture("status.json")
  end

  def teardown
    T::RCFile.instance.reset
    $stderr = @original_stderr
    $stdout = @original_stdout
    super
  end

  # Builds a fake object that accepts options= and options, and records calls
  # to any additional methods specified.
  def build_fake_t_class(*recordable_methods)
    obj = Object.new
    obj.define_singleton_method(:options=) { |_| nil }
    obj.define_singleton_method(:options) { {} }
    recordable_methods.each do |meth|
      obj.define_singleton_method(meth) { |*_| nil }
    end
    obj
  end

  # all

  def test_all_prints_the_tweet
    called = false
    @stream_cmd.stub(:print_message, ->(*_) { called = true }) do
      @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
        @stream_cmd.all
      end
    end

    assert(called, "expected print_message to be called")
  end

  def test_all_csv_outputs_headings
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    say_args = []
    @stream_cmd.stub(:say, ->(*args) { say_args << args }) do
      @stream_cmd.stub(:stream_tweets, ->(_endpoint, &_block) {}) do
        @stream_cmd.all
      end
    end

    assert(say_args.any? { |args| args.first == "ID,Posted at,Screen name,Text\n" },
           "expected say to be called with CSV headings")
  end

  def test_all_csv_outputs_in_csv_format
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    called = false
    @stream_cmd.stub(:print_csv_tweet, ->(*_) { called = true }) do
      @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
        @stream_cmd.all
      end
    end

    assert(called, "expected print_csv_tweet to be called")
  end

  def test_all_long_outputs_headings
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    call_count = 0
    @stream_cmd.stub(:print_table, ->(*_) { call_count += 1 }) do
      @stream_cmd.stub(:stream_tweets, ->(_endpoint, &_block) {}) do
        @stream_cmd.all
      end
    end

    assert_operator(call_count, :>=, 1, "expected print_table to be called")
  end

  def test_all_long_outputs_in_long_text_format
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    call_count = 0
    @stream_cmd.stub(:print_table, ->(*_) { call_count += 1 }) do
      @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
        @stream_cmd.all
      end
    end

    assert_operator(call_count, :>=, 2, "expected print_table to be called at least twice")
  end

  def test_all_streams_from_the_sample_endpoint
    received_endpoint = nil
    @stream_cmd.stub(:print_message, ->(*_) {}) do
      @stream_cmd.stub(:stream_tweets, ->(endpoint, &_block) { received_endpoint = endpoint }) do
        @stream_cmd.all
      end
    end

    assert_equal("tweets/sample/stream", received_endpoint)
  end

  def test_all_does_nothing_when_neither_csv_nor_long_is_set
    @stream_cmd.stub(:stream_tweets, ->(_endpoint, &_block) {}) do
      @stream_cmd.all
    end
  end

  # list

  def setup_list
    stub_get("/1.1/lists/members.json").with(query: {cursor: "-1", owner_screen_name: "testcli", slug: "presidents"}).to_return(body: fixture("users_list.json"), headers: {content_type: "application/json; charset=utf-8"})
  end

  def test_list_prints_the_tweet
    setup_list
    t_class = build_fake_t_class(:timeline)
    called = false
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert(called, "expected print_message to be called")
  end

  def test_list_requests_the_correct_resource
    setup_list
    t_class = build_fake_t_class(:timeline)
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert_requested(:get, "https://api.twitter.com/1.1/lists/members.json", query: {cursor: "-1", owner_screen_name: "testcli", slug: "presidents"})
  end

  def test_list_csv_outputs_in_csv_format
    setup_list
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    t_class = build_fake_t_class(:timeline)
    called = false
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_csv_tweet, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert(called, "expected print_csv_tweet to be called")
  end

  def test_list_csv_requests_the_correct_resource
    setup_list
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    t_class = build_fake_t_class(:timeline)
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_csv_tweet, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert_requested(:get, "https://api.twitter.com/1.1/lists/members.json", query: {cursor: "-1", owner_screen_name: "testcli", slug: "presidents"})
  end

  def test_list_long_outputs_in_long_text_format
    setup_list
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    t_class = build_fake_t_class(:timeline)
    called = false
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_table, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert(called, "expected print_table to be called")
  end

  def test_list_long_requests_the_correct_resource
    setup_list
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    t_class = build_fake_t_class(:timeline)
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_table, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert_requested(:get, "https://api.twitter.com/1.1/lists/members.json", query: {cursor: "-1", owner_screen_name: "testcli", slug: "presidents"})
  end

  def test_list_performs_the_initial_rest_timeline
    setup_list
    t_class = build_fake_t_class
    timeline_called = false
    t_class.define_singleton_method(:timeline) { |*_| timeline_called = true }
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert(timeline_called, "expected timeline to be called on the list object")
  end

  def test_list_streams_from_the_search_endpoint
    setup_list
    t_class = build_fake_t_class(:timeline)
    received_endpoint = nil
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(endpoint, &_block) { received_endpoint = endpoint }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert_equal("tweets/search/stream", received_endpoint)
  end

  def test_list_sets_up_stream_rules
    setup_list
    t_class = build_fake_t_class(:timeline)
    rules_called = false
    T::List.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { 
          rules_called = true
          []
        }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.list("presidents")
          end
        end
      end
    end

    assert(rules_called, "expected setup_stream_rules to be called")
  end

  # matrix

  def test_matrix_outputs_the_tweet
    hiragana_tweet = {"text" => "テストあいう"}
    say_called = false
    @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
      @stream_cmd.stub(:say, ->(*_) { say_called = true }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(hiragana_tweet) }) do
          @stream_cmd.matrix
        end
      end
    end

    assert(say_called, "expected say to be called")
  end

  def test_matrix_skips_tweets_without_hiragana
    say_called = false
    @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
      @stream_cmd.stub(:say, ->(*_) { say_called = true }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
          @stream_cmd.matrix
        end
      end
    end

    refute(say_called, "say should not be called for tweets without hiragana")
  end

  def test_matrix_streams_from_the_filtered_stream
    received_endpoint = nil
    @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
      @stream_cmd.stub(:say, ->(*_) {}) do
        @stream_cmd.stub(:stream_tweets, ->(endpoint, &_block) { received_endpoint = endpoint }) do
          @stream_cmd.matrix
        end
      end
    end

    assert_equal("tweets/search/stream", received_endpoint)
  end

  def test_matrix_sets_up_stream_rules
    rules_set = false
    @stream_cmd.stub(:setup_stream_rules, ->(*_) { 
      rules_set = true
      []
    }) do
      @stream_cmd.stub(:say, ->(*_) {}) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &_block) {}) do
          @stream_cmd.matrix
        end
      end
    end

    assert(rules_set, "expected setup_stream_rules to be called")
  end

  # search

  def test_search_prints_the_tweet
    t_class = build_fake_t_class(:all)
    called = false
    T::Search.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.search("twitter", "gem")
          end
        end
      end
    end

    assert(called, "expected print_message to be called")
  end

  def test_search_csv_outputs_in_csv_format
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    t_class = build_fake_t_class(:all)
    called = false
    T::Search.stub(:new, t_class) do
      @stream_cmd.stub(:print_csv_tweet, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.search("twitter", "gem")
          end
        end
      end
    end

    assert(called, "expected print_csv_tweet to be called")
  end

  def test_search_long_outputs_in_long_text_format
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    t_class = build_fake_t_class(:all)
    called = false
    T::Search.stub(:new, t_class) do
      @stream_cmd.stub(:print_table, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.search("twitter", "gem")
          end
        end
      end
    end

    assert(called, "expected print_table to be called")
  end

  def test_search_performs_a_rest_search_on_initialization
    t_class = build_fake_t_class
    all_arg = nil
    t_class.define_singleton_method(:all) { |*args| all_arg = args.first }
    T::Search.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.search("t", "gem")
          end
        end
      end
    end

    assert_equal("t OR gem", all_arg)
  end

  def test_search_streams_from_the_search_endpoint
    t_class = build_fake_t_class(:all)
    received_endpoint = nil
    T::Search.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(endpoint, &_block) { received_endpoint = endpoint }) do
            @stream_cmd.search("twitter", "gem")
          end
        end
      end
    end

    assert_equal("tweets/search/stream", received_endpoint)
  end

  def test_search_sets_up_stream_rules_with_the_keywords
    t_class = build_fake_t_class(:all)
    received_rules = nil
    T::Search.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*args) { 
          received_rules = args.first
          []
        }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.search("twitter", "gem")
          end
        end
      end
    end

    assert_equal([{value: "twitter OR gem"}], received_rules)
  end

  # timeline

  def test_timeline_prints_the_tweet
    t_class = build_fake_t_class(:timeline)
    called = false
    T::CLI.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.timeline
          end
        end
      end
    end

    assert(called, "expected print_message to be called")
  end

  def test_timeline_csv_outputs_in_csv_format
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    t_class = build_fake_t_class(:timeline)
    called = false
    T::CLI.stub(:new, t_class) do
      @stream_cmd.stub(:print_csv_tweet, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.timeline
          end
        end
      end
    end

    assert(called, "expected print_csv_tweet to be called")
  end

  def test_timeline_long_outputs_in_long_text_format
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    t_class = build_fake_t_class(:timeline)
    called = false
    T::CLI.stub(:new, t_class) do
      @stream_cmd.stub(:print_table, ->(*_) { called = true }) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.timeline
          end
        end
      end
    end

    assert(called, "expected print_table to be called")
  end

  def test_timeline_performs_a_rest_timeline_on_initialization
    t_class = build_fake_t_class
    timeline_called = false
    t_class.define_singleton_method(:timeline) { |*_| timeline_called = true }
    T::CLI.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.timeline
          end
        end
      end
    end

    assert(timeline_called, "expected timeline to be called on the CLI object")
  end

  def test_timeline_streams_from_the_search_endpoint
    t_class = build_fake_t_class(:timeline)
    received_endpoint = nil
    T::CLI.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
          @stream_cmd.stub(:stream_tweets, ->(endpoint, &_block) { received_endpoint = endpoint }) do
            @stream_cmd.timeline
          end
        end
      end
    end

    assert_equal("tweets/search/stream", received_endpoint)
  end

  def test_timeline_sets_up_stream_rules_for_the_active_user
    t_class = build_fake_t_class(:timeline)
    received_rules = nil
    T::CLI.stub(:new, t_class) do
      @stream_cmd.stub(:print_message, ->(*_) {}) do
        @stream_cmd.stub(:setup_stream_rules, ->(*args) { 
          received_rules = args.first
          []
        }) do
          @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
            @stream_cmd.timeline
          end
        end
      end
    end

    assert_equal([{value: "from:testcli OR to:testcli"}], received_rules)
  end

  # users

  def test_users_prints_the_tweet
    called = false
    @stream_cmd.stub(:print_message, ->(*_) { called = true }) do
      @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
          @stream_cmd.users("123")
        end
      end
    end

    assert(called, "expected print_message to be called")
  end

  def test_users_csv_outputs_headings
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    say_args = []
    @stream_cmd.stub(:say, ->(*args) { say_args << args }) do
      @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &_block) {}) do
          @stream_cmd.users("123")
        end
      end
    end

    assert(say_args.any? { |args| args.first == "ID,Posted at,Screen name,Text\n" },
           "expected say to be called with CSV headings")
  end

  def test_users_csv_outputs_in_csv_format
    @stream_cmd.options = @stream_cmd.options.merge("csv" => true)
    called = false
    @stream_cmd.stub(:print_csv_tweet, ->(*_) { called = true }) do
      @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
          @stream_cmd.users("123")
        end
      end
    end

    assert(called, "expected print_csv_tweet to be called")
  end

  def test_users_long_outputs_headings
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    call_count = 0
    @stream_cmd.stub(:print_table, ->(*_) { call_count += 1 }) do
      @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &_block) {}) do
          @stream_cmd.users("123")
        end
      end
    end

    assert_operator(call_count, :>=, 1, "expected print_table to be called")
  end

  def test_users_long_outputs_in_long_text_format
    @stream_cmd.options = @stream_cmd.options.merge("long" => true)
    call_count = 0
    @stream_cmd.stub(:print_table, ->(*_) { call_count += 1 }) do
      @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
          @stream_cmd.users("123")
        end
      end
    end

    assert_operator(call_count, :>=, 2, "expected print_table to be called at least twice")
  end

  def test_users_streams_from_the_search_endpoint
    received_endpoint = nil
    @stream_cmd.stub(:print_message, ->(*_) {}) do
      @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
        @stream_cmd.stub(:stream_tweets, ->(endpoint, &_block) { received_endpoint = endpoint }) do
          @stream_cmd.users("123", "456", "789")
        end
      end
    end

    assert_equal("tweets/search/stream", received_endpoint)
  end

  def test_users_sets_up_stream_rules_for_the_specified_users
    received_rules = nil
    @stream_cmd.stub(:print_message, ->(*_) {}) do
      @stream_cmd.stub(:setup_stream_rules, ->(*args) { 
        received_rules = args.first
        []
      }) do
        @stream_cmd.stub(:stream_tweets, ->(_endpoint, &block) { block&.call(@tweet) }) do
          @stream_cmd.users("123", "456", "789")
        end
      end
    end

    assert_equal([{value: "from:123 OR from:456 OR from:789"}], received_rules)
  end

  def test_users_does_nothing_when_neither_csv_nor_long_is_set
    @stream_cmd.stub(:setup_stream_rules, ->(*_) { [] }) do
      @stream_cmd.stub(:stream_tweets, ->(_endpoint, &_block) {}) do
        @stream_cmd.users("123")
      end
    end
  end

  # bearer_client

  def test_bearer_client_obtains_token_via_client_credentials_grant
    # Trigger client initialization so @requestable_api_credentials is set
    @stream_cmd.send(:client)
    bearer = @stream_cmd.send(:bearer_client)

    assert_kind_of(X::Client, bearer)
    assert_requested(:post, "https://api.twitter.com/oauth2/token")
  end

  # stream_tweets

  def test_stream_tweets_yields_exactly_one_tweet
    v2_stream_response = build_v2_stream_response
    x_client = Object.new
    x_client.define_singleton_method(:stream) { |_url, &block| block.call(v2_stream_response) }
    collected = []
    @stream_cmd.stub(:bearer_client, x_client) do
      @stream_cmd.send(:stream_tweets, "tweets/sample/stream") { |t| collected << t }
    end

    assert_equal(1, collected.size)
  end

  def test_stream_tweets_normalizes_the_screen_name
    v2_stream_response = build_v2_stream_response
    x_client = Object.new
    x_client.define_singleton_method(:stream) { |_url, &block| block.call(v2_stream_response) }
    collected = []
    @stream_cmd.stub(:bearer_client, x_client) do
      @stream_cmd.send(:stream_tweets, "tweets/sample/stream") { |t| collected << t }
    end

    assert_equal("sferik", collected.first["user"]["screen_name"])
  end

  def test_stream_tweets_preserves_the_tweet_text
    v2_stream_response = build_v2_stream_response
    x_client = Object.new
    x_client.define_singleton_method(:stream) { |_url, &block| block.call(v2_stream_response) }
    collected = []
    @stream_cmd.stub(:bearer_client, x_client) do
      @stream_cmd.send(:stream_tweets, "tweets/sample/stream") { |t| collected << t }
    end

    assert_includes(collected.first["text"], "problem with your code")
  end

  def test_stream_tweets_skips_nil_tweets_from_malformed_stream_data
    x_client = Object.new
    x_client.define_singleton_method(:stream) { |_url, &block| block.call({"data" => nil}) }
    tweets = []
    @stream_cmd.stub(:bearer_client, x_client) do
      @stream_cmd.send(:stream_tweets, "tweets/sample/stream") { |t| tweets << t }
    end

    assert_empty(tweets)
  end

  def test_stream_tweets_appends_stream_field_parameters_to_the_endpoint
    x_client = Object.new
    received_url = nil
    x_client.define_singleton_method(:stream) { |url, &_block| received_url = url }
    @stream_cmd.stub(:bearer_client, x_client) do
      @stream_cmd.send(:stream_tweets, "tweets/sample/stream") { |_t| nil }
    end

    assert_match(/tweet\.fields=.*&expansions=author_id&user\.fields=/, received_url)
  end

  # setup_stream_rules / remove_stream_rules

  def test_setup_stream_rules_posts_add_request
    stub_v2_post("tweets/search/stream/rules").to_return(
      body: '{"data":[{"id":"42","value":"ruby OR rails"}],"meta":{"summary":{"created":1}}}',
      headers: V2_JSON_HEADERS
    )
    bearer = X::Client.new(bearer_token: "test-token")
    rule_ids = nil
    @stream_cmd.stub(:bearer_client, bearer) do
      rule_ids = @stream_cmd.send(:setup_stream_rules, [{value: "ruby OR rails"}])
    end

    assert_requested(:post, v2_pattern("tweets/search/stream/rules"), times: 1)
    assert_equal ["42"], rule_ids
  end

  def test_setup_stream_rules_returns_empty_when_no_data
    stub_v2_post("tweets/search/stream/rules").to_return(
      body: '{"meta":{"summary":{"created":1}}}',
      headers: V2_JSON_HEADERS
    )
    bearer = X::Client.new(bearer_token: "test-token")
    rule_ids = nil
    @stream_cmd.stub(:bearer_client, bearer) do
      rule_ids = @stream_cmd.send(:setup_stream_rules, [{value: "ruby"}])
    end

    assert_equal [], rule_ids
  end

  def test_remove_stream_rules_posts_delete_request
    stub_v2_post("tweets/search/stream/rules").to_return(body: "{}", headers: V2_JSON_HEADERS)
    bearer = X::Client.new(bearer_token: "test-token")
    @stream_cmd.stub(:bearer_client, bearer) do
      @stream_cmd.send(:remove_stream_rules, %w[42 43])
    end

    assert_requested(:post, v2_pattern("tweets/search/stream/rules"), times: 1)
  end

  def test_remove_stream_rules_skips_when_empty
    bearer = X::Client.new(bearer_token: "test-token")
    @stream_cmd.stub(:bearer_client, bearer) do
      @stream_cmd.send(:remove_stream_rules, [])
    end

    assert_not_requested(:post, v2_pattern("tweets/search/stream/rules"))
  end

private

  def build_v2_stream_response
    {
      "data" => {
        "id" => "55709764298092545",
        "text" => "The problem with your code is that it's doing exactly what you told it to do.",
        "author_id" => "7505382",
        "created_at" => "2011-04-06T19:13:37.000Z",
      },
      "includes" => {
        "users" => [
          {"id" => "7505382", "username" => "sferik", "name" => "Erik Michaels-Ober"},
        ],
      },
    }
  end
end
