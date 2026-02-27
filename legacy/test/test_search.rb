require "test_helper"

class TestSearch < TTestCase
  def setup
    super
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
    $stdout = StringIO.new
    def $stdout.tty? = true
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0))
    T.utc_offset = "PST"
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @search_cmd = T::Search.new
    @search_cmd.options = @search_cmd.options.merge("color" => "always")
  end

  def teardown
    T::RCFile.instance.reset
    T.utc_offset = nil
    Timecop.return
    $stderr = @original_stderr
    $stdout = @original_stdout
    super
  end

  # all

  def test_all_requests_the_correct_resource
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.all("twitter")

    assert_requested(:get, v2_pattern("tweets/search/recent"))
  end

  def test_all_includes_first_batch_screen_name
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "@amaliasafitri2")
  end

  def test_all_includes_first_batch_tweet_text
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "RT @heartCOBOYJR: @AlvaroMaldini1 :-) http://t.co/Oxce0Tob3n")
  end

  def test_all_includes_second_batch_screen_name
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "@bryony_thfc")
  end

  def test_all_includes_second_batch_tweet_text
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "merry christmas you arse X http://t.co/yRiWFgqr7p")
  end

  def test_all_includes_third_batch_first_screen_name
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "@yunistosun6034")
  end

  def test_all_includes_third_batch_second_screen_name
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "@MaimounaLvb")
  end

  def test_all_with_csv_outputs_csv_header
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
  end

  def test_all_with_csv_outputs_first_csv_row
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "415600159511158784,2013-12-24 21:49:34 +0000,amaliasafitri2,RT @heartCOBOYJR: @AlvaroMaldini1 :-) http://t.co/Oxce0Tob3n")
  end

  def test_all_with_csv_outputs_second_csv_row
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "415600159372767232,2013-12-24 21:49:34 +0000,bryony_thfc,merry christmas you arse X http://t.co/yRiWFgqr7p")
  end

  def test_all_with_long_outputs_long_format_header
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "ID                  Posted at     Screen name")
  end

  def test_all_with_long_outputs_first_long_format_row
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "415600159511158784  Dec 24 13:49  @amaliasafitri2")
  end

  def test_all_with_long_outputs_second_long_format_row
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "415600159372767232  Dec 24 13:49  @bryony_thfc")
  end

  def test_all_with_number_limits_the_number_of_results_to_1
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("number" => 1)
    @search_cmd.all("twitter")

    assert_requested(:get, v2_pattern("tweets/search/recent"))
  end

  def test_all_with_number_limits_the_number_of_results_to_201
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("number" => 201)
    @search_cmd.all("twitter")

    assert_requested(:get, v2_pattern("tweets/search/recent"))
  end

  def test_all_with_reverse_reverses_the_order_of_the_results
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/search.json"))
    @search_cmd.options = @search_cmd.options.merge("reverse" => true)
    @search_cmd.all("twitter")

    assert_includes($stdout.string, "@amaliasafitri2")
  end

  def test_all_when_no_results_outputs_nothing_in_default_mode
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/empty.json"))
    @search_cmd.all("nomatchquery")

    assert_equal("", $stdout.string)
  end

  def test_all_when_no_results_outputs_no_csv_headers
    stub_v2_get("tweets/search/recent").to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.all("nomatchquery")

    assert_equal("", $stdout.string)
  end

  # favorites

  def setup_favorites
    stub_v2_current_user
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
  end

  FAVORITES_EXPECTED_OUTPUT = <<-EOS.freeze
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

  EOS

  FAVORITES_EXPECTED_CSV_OUTPUT = <<~EOS.freeze
    ID,Posted at,Screen name,Text
    244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
    244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
  EOS

  FAVORITES_EXPECTED_LONG_OUTPUT = <<~EOS.freeze
    ID                  Posted at     Screen name  Text
    244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
    244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
  EOS

  def test_favorites_requests_the_correct_resource
    setup_favorites
    @search_cmd.favorites("twitter")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"), at_least_times: 1)
  end

  def test_favorites_has_the_correct_output
    setup_favorites
    @search_cmd.favorites("twitter")

    assert_equal(FAVORITES_EXPECTED_OUTPUT, $stdout.string)
  end

  def test_favorites_with_csv_outputs_in_csv_format
    setup_favorites
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.favorites("twitter")

    assert_equal(FAVORITES_EXPECTED_CSV_OUTPUT, $stdout.string)
  end

  def test_favorites_with_decode_uris_requests_the_correct_resource
    setup_favorites
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.favorites("twitter")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"), at_least_times: 1)
  end

  def test_favorites_with_decode_uris_outputs_matching_tweets_screen_name
    setup_favorites
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.favorites("twitter")

    assert_includes($stdout.string, "@sferik")
  end

  def test_favorites_with_decode_uris_outputs_matching_tweets_text
    setup_favorites
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.favorites("twitter")

    assert_includes($stdout.string, "twitterapi")
  end

  def test_favorites_with_long_outputs_in_long_format
    setup_favorites
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.favorites("twitter")

    assert_equal(FAVORITES_EXPECTED_LONG_OUTPUT, $stdout.string)
  end

  def test_favorites_when_twitter_is_down_retries_and_raises_error
    stub_v2_current_user
    stub_v2_get("users/7505382/liked_tweets").to_return(status: 502, body: "{}", headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @search_cmd.favorites("twitter") }
  end

  def test_favorites_with_a_user_passed_requests_the_correct_resource
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.favorites("sferik", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"), at_least_times: 1)
  end

  def test_favorites_with_a_user_passed_has_the_correct_output
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.favorites("sferik", "twitter")

    assert_equal(FAVORITES_EXPECTED_OUTPUT, $stdout.string)
  end

  def test_favorites_with_a_user_passed_and_id_requests_the_correct_resource
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.favorites("7505382", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"), at_least_times: 1)
  end

  def test_favorites_with_a_user_passed_and_id_has_the_correct_output
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.favorites("7505382", "twitter")

    assert_equal(FAVORITES_EXPECTED_OUTPUT, $stdout.string)
  end

  # mentions

  def setup_mentions
    stub_v2_current_user
    stub_v2_get("users/7505382/mentions").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
  end

  MENTIONS_EXPECTED_OUTPUT = <<-EOS.freeze
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

  EOS

  MENTIONS_EXPECTED_CSV_OUTPUT = <<~EOS.freeze
    ID,Posted at,Screen name,Text
    244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
    244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
  EOS

  MENTIONS_EXPECTED_LONG_OUTPUT = <<~EOS.freeze
    ID                  Posted at     Screen name  Text
    244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
    244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
  EOS

  def test_mentions_requests_the_correct_resource
    setup_mentions
    @search_cmd.mentions("twitter")

    assert_requested(:get, v2_pattern("users/7505382/mentions"), at_least_times: 1)
  end

  def test_mentions_has_the_correct_output
    setup_mentions
    @search_cmd.mentions("twitter")

    assert_equal(MENTIONS_EXPECTED_OUTPUT, $stdout.string)
  end

  def test_mentions_with_csv_outputs_in_csv_format
    setup_mentions
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.mentions("twitter")

    assert_equal(MENTIONS_EXPECTED_CSV_OUTPUT, $stdout.string)
  end

  def test_mentions_with_decode_uris_requests_the_correct_resource
    setup_mentions
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.mentions("twitter")

    assert_requested(:get, v2_pattern("users/7505382/mentions"), at_least_times: 1)
  end

  def test_mentions_with_decode_uris_outputs_matching_tweets_screen_name
    setup_mentions
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.mentions("twitter")

    assert_includes($stdout.string, "@sferik")
  end

  def test_mentions_with_decode_uris_outputs_matching_tweets_text
    setup_mentions
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.mentions("twitter")

    assert_includes($stdout.string, "twitterapi")
  end

  def test_mentions_with_long_outputs_in_long_format
    setup_mentions
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.mentions("twitter")

    assert_equal(MENTIONS_EXPECTED_LONG_OUTPUT, $stdout.string)
  end

  def test_mentions_when_twitter_is_down_retries_and_raises_error
    stub_v2_current_user
    stub_v2_get("users/7505382/mentions").to_return(status: 502, body: "{}", headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @search_cmd.mentions("twitter") }
  end

  # list

  def setup_list
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
  end

  LIST_EXPECTED_OUTPUT = <<-EOS.freeze
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

  EOS

  LIST_EXPECTED_CSV_OUTPUT = <<~EOS.freeze
    ID,Posted at,Screen name,Text
    244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
    244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
  EOS

  LIST_EXPECTED_LONG_OUTPUT = <<~EOS.freeze
    ID                  Posted at     Screen name  Text
    244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
    244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
  EOS

  def test_list_requests_the_user_resource
    setup_list
    @search_cmd.list("presidents", "twitter")

    assert_requested(:get, v2_pattern("users/by/username/testcli"), at_least_times: 1)
  end

  def test_list_requests_the_owned_lists_resource
    setup_list
    @search_cmd.list("presidents", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"), at_least_times: 1)
  end

  def test_list_requests_the_list_tweets_resource
    setup_list
    @search_cmd.list("presidents", "twitter")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"), at_least_times: 1)
  end

  def test_list_has_the_correct_output
    setup_list
    @search_cmd.list("presidents", "twitter")

    assert_equal(LIST_EXPECTED_OUTPUT, $stdout.string)
  end

  def test_list_with_csv_outputs_in_csv_format
    setup_list
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.list("presidents", "twitter")

    assert_equal(LIST_EXPECTED_CSV_OUTPUT, $stdout.string)
  end

  def test_list_with_decode_uris_requests_the_user_resource
    setup_list
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.list("presidents", "twitter")

    assert_requested(:get, v2_pattern("users/by/username/testcli"), at_least_times: 1)
  end

  def test_list_with_decode_uris_requests_the_owned_lists_resource
    setup_list
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.list("presidents", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"), at_least_times: 1)
  end

  def test_list_with_decode_uris_requests_the_list_tweets_resource
    setup_list
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.list("presidents", "twitter")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"), at_least_times: 1)
  end

  def test_list_with_decode_uris_outputs_matching_tweets_screen_name
    setup_list
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.list("presidents", "twitter")

    assert_includes($stdout.string, "@sferik")
  end

  def test_list_with_decode_uris_outputs_matching_tweets_text
    setup_list
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.list("presidents", "twitter")

    assert_includes($stdout.string, "twitterapi")
  end

  def test_list_with_long_outputs_in_long_format
    setup_list
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.list("presidents", "twitter")

    assert_equal(LIST_EXPECTED_LONG_OUTPUT, $stdout.string)
  end

  def test_list_with_a_user_passed_requests_the_user_resource
    setup_list
    @search_cmd.list("testcli/presidents", "twitter")

    assert_requested(:get, v2_pattern("users/by/username/testcli"), at_least_times: 1)
  end

  def test_list_with_a_user_passed_requests_the_owned_lists_resource
    setup_list
    @search_cmd.list("testcli/presidents", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"), at_least_times: 1)
  end

  def test_list_with_a_user_passed_requests_the_list_tweets_resource
    setup_list
    @search_cmd.list("testcli/presidents", "twitter")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"), at_least_times: 1)
  end

  def test_list_with_a_user_passed_and_id_requests_the_owned_lists_resource
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.list("7505382/presidents", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"), at_least_times: 1)
  end

  def test_list_with_a_user_passed_and_id_requests_the_list_tweets_resource
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.list("7505382/presidents", "twitter")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"), at_least_times: 1)
  end

  def test_list_when_twitter_is_down_retries_and_raises_error
    setup_list
    stub_v2_get("lists/8863586/tweets").to_return(status: 502, body: "{}", headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @search_cmd.list("presidents", "twitter") }
  end

  # retweets

  def setup_retweets
    stub_v2_current_user
    stub_v2_get("users/reposts_of_me").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
  end

  RETWEETS_EXPECTED_OUTPUT = <<-EOS.freeze
   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @calebelston
   We just announced Mosaic, what we've been working on since the Yobongo
   acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic

  EOS

  RETWEETS_EXPECTED_CSV_OUTPUT = <<~EOS.freeze
    ID,Posted at,Screen name,Text
    244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
    244104146997870594,2012-09-07 16:05:38 +0000,calebelston,"We just announced Mosaic, what we've been working on since the Yobongo acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic"
  EOS

  RETWEETS_EXPECTED_LONG_OUTPUT = <<~EOS.freeze
    ID                  Posted at     Screen name   Text
    244108728834592770  Sep  7 08:23  @calebelston  RT @olivercameron: Mosaic loo...
    244104146997870594  Sep  7 08:05  @calebelston  We just announced Mosaic, wha...
  EOS

  def test_retweets_requests_the_correct_resource
    setup_retweets
    @search_cmd.retweets("mosaic")

    assert_requested(:get, v2_pattern("users/reposts_of_me"), at_least_times: 1)
  end

  def test_retweets_has_the_correct_output
    setup_retweets
    @search_cmd.retweets("mosaic")

    assert_equal(RETWEETS_EXPECTED_OUTPUT, $stdout.string)
  end

  def test_retweets_with_csv_outputs_in_csv_format
    setup_retweets
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.retweets("mosaic")

    assert_equal(RETWEETS_EXPECTED_CSV_OUTPUT, $stdout.string)
  end

  def test_retweets_with_decode_uris_requests_the_correct_resource
    setup_retweets
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.retweets("mosaic")

    assert_requested(:get, v2_pattern("users/reposts_of_me"), at_least_times: 1)
  end

  def test_retweets_with_decode_uris_outputs_matching_tweets_text
    setup_retweets
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.retweets("mosaic")

    assert_includes($stdout.string, "Mosaic")
  end

  def test_retweets_with_decode_uris_outputs_matching_tweets_screen_name
    setup_retweets
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.retweets("mosaic")

    assert_includes($stdout.string, "@calebelston")
  end

  def test_retweets_with_long_outputs_in_long_format
    setup_retweets
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.retweets("mosaic")

    assert_equal(RETWEETS_EXPECTED_LONG_OUTPUT, $stdout.string)
  end

  def test_retweets_when_twitter_is_down_retries_and_raises_error
    stub_v2_current_user
    stub_v2_get("users/reposts_of_me").to_return(status: 502, body: "{}", headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @search_cmd.retweets("mosaic") }
  end

  def test_retweets_with_a_user_passed_requests_the_user_resource
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.retweets("sferik", "mosaic")

    assert_requested(:get, v2_pattern("users/by/username/sferik"), at_least_times: 1)
  end

  def test_retweets_with_a_user_passed_requests_the_tweets_resource
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.retweets("sferik", "mosaic")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_retweets_with_a_user_passed_outputs_screen_name
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.retweets("sferik", "mosaic")

    assert_includes($stdout.string, "@calebelston")
  end

  def test_retweets_with_a_user_passed_outputs_tweet_text
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.retweets("sferik", "mosaic")

    assert_includes($stdout.string, "Mosaic")
  end

  def test_retweets_with_a_user_passed_and_id_requests_the_correct_resource
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.retweets("7505382", "mosaic")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_retweets_with_a_user_passed_and_id_outputs_screen_name
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.retweets("7505382", "mosaic")

    assert_includes($stdout.string, "@calebelston")
  end

  def test_retweets_with_a_user_passed_and_id_outputs_tweet_text
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.retweets("7505382", "mosaic")

    assert_includes($stdout.string, "Mosaic")
  end

  # timeline

  def setup_timeline
    stub_v2_current_user
    stub_v2_get("users/7505382/timelines/reverse_chronological").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
  end

  TIMELINE_EXPECTED_OUTPUT = <<-EOS.freeze
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

  EOS

  TIMELINE_EXPECTED_CSV_OUTPUT = <<~EOS.freeze
    ID,Posted at,Screen name,Text
    244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
    244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
  EOS

  TIMELINE_EXPECTED_LONG_OUTPUT = <<~EOS.freeze
    ID                  Posted at     Screen name  Text
    244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
    244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
  EOS

  def test_timeline_requests_the_correct_resource
    setup_timeline
    @search_cmd.timeline("twitter")

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"), at_least_times: 1)
  end

  def test_timeline_has_the_correct_output
    setup_timeline
    @search_cmd.timeline("twitter")

    assert_equal(TIMELINE_EXPECTED_OUTPUT, $stdout.string)
  end

  def test_timeline_with_csv_outputs_in_csv_format
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.timeline("twitter")

    assert_equal(TIMELINE_EXPECTED_CSV_OUTPUT, $stdout.string)
  end

  def test_timeline_with_decode_uris_requests_the_correct_resource
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.timeline("twitter")

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"), at_least_times: 1)
  end

  def test_timeline_with_decode_uris_outputs_matching_tweets_screen_name
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.timeline("twitter")

    assert_includes($stdout.string, "@sferik")
  end

  def test_timeline_with_decode_uris_outputs_matching_tweets_text
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("decode_uris" => true)
    @search_cmd.timeline("twitter")

    assert_includes($stdout.string, "twitterapi")
  end

  def test_timeline_with_exclude_replies_excludes_replies
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("exclude" => "replies")
    @search_cmd.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"), at_least_times: 1)
  end

  def test_timeline_with_exclude_retweets_excludes_retweets
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("exclude" => "retweets")
    @search_cmd.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"), at_least_times: 1)
  end

  def test_timeline_with_long_outputs_in_long_format
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.timeline("twitter")

    assert_equal(TIMELINE_EXPECTED_LONG_OUTPUT, $stdout.string)
  end

  def test_timeline_with_max_id_requests_the_correct_resource
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("max_id" => 244_104_558_433_951_744)
    @search_cmd.timeline("twitter")

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"), at_least_times: 1)
  end

  def test_timeline_with_since_id_requests_the_correct_resource
    setup_timeline
    @search_cmd.options = @search_cmd.options.merge("since_id" => 244_104_558_433_951_744)
    @search_cmd.timeline("twitter")

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"), at_least_times: 1)
  end

  def test_timeline_when_twitter_is_down_retries_and_raises_error
    stub_v2_current_user
    stub_v2_get("users/7505382/timelines/reverse_chronological").to_return(status: 502, body: "{}", headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @search_cmd.timeline("twitter") }
  end

  def setup_timeline_with_user
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
  end

  def test_timeline_with_a_user_passed_requests_the_user_resource
    setup_timeline_with_user
    @search_cmd.timeline("sferik", "twitter")

    assert_requested(:get, v2_pattern("users/by/username/sferik"), at_least_times: 1)
  end

  def test_timeline_with_a_user_passed_requests_the_tweets_resource
    setup_timeline_with_user
    @search_cmd.timeline("sferik", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_timeline_with_a_user_passed_has_the_correct_output
    setup_timeline_with_user
    @search_cmd.timeline("sferik", "twitter")

    assert_equal(TIMELINE_EXPECTED_OUTPUT, $stdout.string)
  end

  def test_timeline_with_a_user_passed_and_csv_outputs_in_csv_format
    setup_timeline_with_user
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.timeline("sferik", "twitter")

    assert_equal(TIMELINE_EXPECTED_CSV_OUTPUT, $stdout.string)
  end

  def test_timeline_with_a_user_passed_and_id_requests_the_correct_resource
    setup_timeline_with_user
    @search_cmd.options = @search_cmd.options.merge("id" => true)
    @search_cmd.timeline("7505382", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_timeline_with_a_user_passed_and_long_outputs_in_long_format
    setup_timeline_with_user
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.timeline("sferik", "twitter")

    assert_equal(TIMELINE_EXPECTED_LONG_OUTPUT, $stdout.string)
  end

  def test_timeline_with_a_user_passed_and_max_id_requests_the_correct_resource
    setup_timeline_with_user
    @search_cmd.options = @search_cmd.options.merge("max_id" => 244_104_558_433_951_744)
    @search_cmd.timeline("sferik", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_timeline_with_a_user_passed_and_since_id_requests_the_correct_resource
    setup_timeline_with_user
    @search_cmd.options = @search_cmd.options.merge("since_id" => 244_104_558_433_951_744)
    @search_cmd.timeline("sferik", "twitter")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_timeline_with_a_user_passed_when_twitter_is_down_retries_and_raises_error
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(status: 502, body: "{}", headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @search_cmd.timeline("sferik", "twitter") }
  end

  # users

  def setup_users
    stub_v2_get("users/search").to_return(v2_return("v2/users_list.json"))
  end

  USERS_EXPECTED_CSV_OUTPUT = <<~EOS.freeze
    ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
    14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
    7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
  EOS

  USERS_EXPECTED_LONG_OUTPUT = <<~EOS.freeze
    ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
    14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
     7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
  EOS

  def test_users_requests_the_correct_resource
    setup_users
    @search_cmd.users("Erik")

    assert_requested(:get, v2_pattern("users/search"))
  end

  def test_users_has_the_correct_output
    setup_users
    @search_cmd.users("Erik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_csv_outputs_in_csv_format
    setup_users
    @search_cmd.options = @search_cmd.options.merge("csv" => true)
    @search_cmd.users("Erik")

    assert_equal(USERS_EXPECTED_CSV_OUTPUT, $stdout.string)
  end

  def test_users_with_long_outputs_in_long_format
    setup_users
    @search_cmd.options = @search_cmd.options.merge("long" => true)
    @search_cmd.users("Erik")

    assert_equal(USERS_EXPECTED_LONG_OUTPUT, $stdout.string)
  end

  def test_users_with_reverse_reverses_the_order_of_the_sort
    setup_users
    @search_cmd.options = @search_cmd.options.merge("reverse" => true)
    @search_cmd.users("Erik")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_favorites_sorts_by_the_number_of_favorites
    setup_users
    @search_cmd.options = @search_cmd.options.merge("sort" => "favorites")
    @search_cmd.users("Erik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_sort_followers_sorts_by_the_number_of_followers
    setup_users
    @search_cmd.options = @search_cmd.options.merge("sort" => "followers")
    @search_cmd.users("Erik")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_friends_sorts_by_the_number_of_friends
    setup_users
    @search_cmd.options = @search_cmd.options.merge("sort" => "friends")
    @search_cmd.users("Erik")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_listed_sorts_by_the_number_of_list_memberships
    setup_users
    @search_cmd.options = @search_cmd.options.merge("sort" => "listed")
    @search_cmd.users("Erik")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_since_sorts_by_the_time_when_account_was_created
    setup_users
    @search_cmd.options = @search_cmd.options.merge("sort" => "since")
    @search_cmd.users("Erik")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_tweets_sorts_by_the_number_of_tweets
    setup_users
    @search_cmd.options = @search_cmd.options.merge("sort" => "tweets")
    @search_cmd.users("Erik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_sort_tweeted_sorts_by_the_time_of_the_last_tweet
    setup_users
    @search_cmd.options = @search_cmd.options.merge("sort" => "tweeted")
    @search_cmd.users("Erik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_unsorted_is_not_sorted
    setup_users
    @search_cmd.options = @search_cmd.options.merge("unsorted" => true)
    @search_cmd.users("Erik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_when_twitter_is_down_retries_and_raises_error
    stub_v2_get("users/search").to_return(status: 502, body: "{}", headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @search_cmd.users("Erik") }
  end
end
