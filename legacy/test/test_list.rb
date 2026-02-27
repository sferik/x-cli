# encoding: utf-8

require "test_helper"

class TestList < TTestCase
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
    @list_cmd = T::List.new
  end

  def teardown
    T::RCFile.instance.reset
    T.utc_offset = nil
    Timecop.return
    $stderr = @original_stderr
    $stdout = @original_stdout
    super
  end

  # add

  def setup_add
    @list_cmd.options = @list_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_user_by_name("BarackObama")
    stub_v2_post("lists/8863586/members").to_return(v2_return("v2/post_response.json"))
  end

  def test_add_requests_the_current_user_resource
    setup_add
    @list_cmd.add("presidents", "BarackObama")

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_add_requests_the_owned_lists_resource
    setup_add
    @list_cmd.add("presidents", "BarackObama")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_add_posts_the_list_member_addition
    setup_add
    @list_cmd.add("presidents", "BarackObama")

    assert_requested(:post, v2_pattern("lists/8863586/members"))
  end

  def test_add_has_the_correct_output
    setup_add
    @list_cmd.add("presidents", "BarackObama")

    assert_equal('@testcli added 1 member to the list "presidents".', $stdout.string.split("\n").first)
  end

  def test_add_with_id_requests_the_current_user_resource
    setup_add
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    @list_cmd.add("presidents", "7505382")

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_add_with_id_requests_the_owned_lists_resource
    setup_add
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    @list_cmd.add("presidents", "7505382")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_add_with_id_posts_the_list_member_addition
    setup_add
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    @list_cmd.add("presidents", "7505382")

    assert_requested(:post, v2_pattern("lists/8863586/members"))
  end

  def test_add_when_twitter_is_down_raises_an_error_after_retries
    setup_add
    stub_v2_post("lists/8863586/members").to_return(status: 502, body: '{"errors":[{"message":"Bad Gateway"}]}', headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) do
      @list_cmd.add("presidents", "BarackObama")
    end
  end

  def test_add_when_twitter_is_down_retries_3_times_before_failing
    setup_add
    stub_v2_post("lists/8863586/members").to_return(status: 502, body: '{"errors":[{"message":"Bad Gateway"}]}', headers: V2_JSON_HEADERS)
    @list_cmd.add("presidents", "BarackObama")
  rescue X::BadGateway
    assert_requested(:post, v2_pattern("lists/8863586/members"), times: 3)
  end

  # create

  def setup_create
    @list_cmd.options = @list_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_post("lists").to_return(v2_return("v2/list.json"))
  end

  def test_create_requests_the_correct_resource
    setup_create
    @list_cmd.create("presidents")

    assert_requested(:post, v2_pattern("lists"))
  end

  def test_create_has_the_correct_output
    setup_create
    @list_cmd.create("presidents")

    assert_equal('@testcli created the list "presidents".', $stdout.string.chomp)
  end

  def test_create_with_description_requests_the_correct_resource
    setup_create
    @list_cmd.create("presidents", "Presidents of the USA")

    assert_requested(:post, v2_pattern("lists"))
  end

  def test_create_with_description_has_the_correct_output
    setup_create
    @list_cmd.create("presidents", "Presidents of the USA")

    assert_equal('@testcli created the list "presidents".', $stdout.string.chomp)
  end

  def test_create_with_private_requests_the_correct_resource
    setup_create
    @list_cmd.options = @list_cmd.options.merge("private" => true)
    @list_cmd.create("presidents")

    assert_requested(:post, v2_pattern("lists"))
  end

  def test_create_with_private_has_the_correct_output
    setup_create
    @list_cmd.options = @list_cmd.options.merge("private" => true)
    @list_cmd.create("presidents")

    assert_equal('@testcli created the list "presidents".', $stdout.string.chomp)
  end

  # information

  def setup_information
    @list_cmd.options = @list_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586").to_return(v2_return("v2/list.json"))
  end

  def expected_info_output
    <<~EOS
      ID           8863586
      Description  Presidents of the United States of America
      Slug         presidents
      Screen name  @sferik
      Created at   Mar 15  2010 (a year ago)
      Members      2
      Subscribers  1
      Status       Not following
      Mode         public
      URL          https://x.com/i/lists/8863586
    EOS
  end

  def test_information_requests_the_user_lookup_resource
    setup_information
    @list_cmd.information("presidents")

    assert_requested(:get, v2_pattern("users/by/username/testcli"))
  end

  def test_information_requests_the_owned_lists_resource
    setup_information
    @list_cmd.information("presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_information_requests_the_list_detail_resource
    setup_information
    @list_cmd.information("presidents")

    assert_requested(:get, v2_pattern("lists/8863586"))
  end

  def test_information_has_the_correct_output
    setup_information
    @list_cmd.information("presidents")

    assert_equal(expected_info_output, $stdout.string)
  end

  def test_information_with_relative_dates_has_the_correct_output
    setup_information
    @list_cmd.options = @list_cmd.options.merge("relative_dates" => true)
    @list_cmd.information("presidents")

    assert_equal(expected_info_output, $stdout.string)
  end

  def test_information_with_user_passed_requests_the_user_lookup_resource
    setup_information
    @list_cmd.information("testcli/presidents")

    assert_requested(:get, v2_pattern("users/by/username/testcli"))
  end

  def test_information_with_user_passed_requests_the_owned_lists_resource
    setup_information
    @list_cmd.information("testcli/presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_information_with_user_passed_requests_the_list_detail_resource
    setup_information
    @list_cmd.information("testcli/presidents")

    assert_requested(:get, v2_pattern("lists/8863586"))
  end

  def test_information_with_user_passed_and_id_requests_the_owned_lists_resource
    setup_information
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586").to_return(v2_return("v2/list.json"))
    @list_cmd.information("7505382/presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_information_with_user_passed_and_id_requests_the_list_detail_resource
    setup_information
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586").to_return(v2_return("v2/list.json"))
    @list_cmd.information("7505382/presidents")

    assert_requested(:get, v2_pattern("lists/8863586"))
  end

  def test_information_with_csv_has_the_correct_output
    setup_information
    @list_cmd.options = @list_cmd.options.merge("csv" => true)
    @list_cmd.information("presidents")

    assert_equal(<<~EOS, $stdout.string)
      ID,Description,Slug,Screen name,Created at,Members,Subscribers,Following,Mode,URL
      8863586,Presidents of the United States of America,presidents,sferik,2010-03-15 12:10:13 +0000,2,1,false,public,https://x.com/i/lists/8863586
    EOS
  end

  def test_information_when_list_has_no_description_omits_description_row
    setup_information
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list_following_no_desc.json"))
    stub_v2_get("lists/8863586").to_return(v2_return("v2/list_following_no_desc.json"))
    @list_cmd.information("presidents")

    refute_includes($stdout.string, "Description")
  end

  def test_information_when_list_is_followed_shows_following_status
    setup_information
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list_following_no_desc.json"))
    stub_v2_get("lists/8863586").to_return(v2_return("v2/list_following_no_desc.json"))
    @list_cmd.information("presidents")

    assert_includes($stdout.string, "Following")
  end

  # members

  def setup_members
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/members").to_return(v2_return("v2/users_list.json"))
    stub_request(:get, %r{api\.twitter\.com/2/users\?}).to_return(v2_return("v2/users_list.json"))
  end

  def test_members_requests_the_user_lookup_resource
    setup_members
    @list_cmd.members("presidents")

    assert_requested(:get, v2_pattern("users/by/username/testcli"))
  end

  def test_members_requests_the_owned_lists_resource
    setup_members
    @list_cmd.members("presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_members_requests_the_list_members_resource
    setup_members
    @list_cmd.members("presidents")

    assert_requested(:get, v2_pattern("lists/8863586/members"))
  end

  def test_members_requests_the_user_details_resource
    setup_members
    @list_cmd.members("presidents")

    assert_requested(:get, %r{api\.twitter\.com/2/users\?})
  end

  def test_members_has_the_correct_output
    setup_members
    @list_cmd.members("presidents")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def expected_members_csv_output
    <<~EOS
      ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
      14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
      7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
    EOS
  end

  def test_members_with_csv_outputs_in_csv_format
    setup_members
    @list_cmd.options = @list_cmd.options.merge("csv" => true)
    @list_cmd.members("presidents")

    assert_equal(expected_members_csv_output, $stdout.string)
  end

  def expected_members_long_output
    <<~EOS
      ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
      14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
       7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
    EOS
  end

  def test_members_with_long_outputs_in_long_format
    setup_members
    @list_cmd.options = @list_cmd.options.merge("long" => true)
    @list_cmd.members("presidents")

    assert_equal(expected_members_long_output, $stdout.string)
  end

  def test_members_with_reverse_reverses_the_order_of_the_sort
    setup_members
    @list_cmd.options = @list_cmd.options.merge("reverse" => true)
    @list_cmd.members("presidents")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_members_with_sort_favorites_sorts_by_the_number_of_favorites
    setup_members
    @list_cmd.options = @list_cmd.options.merge("sort" => "favorites")
    @list_cmd.members("presidents")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_members_with_sort_followers_sorts_by_the_number_of_followers
    setup_members
    @list_cmd.options = @list_cmd.options.merge("sort" => "followers")
    @list_cmd.members("presidents")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_members_with_sort_friends_sorts_by_the_number_of_friends
    setup_members
    @list_cmd.options = @list_cmd.options.merge("sort" => "friends")
    @list_cmd.members("presidents")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_members_with_sort_listed_sorts_by_the_number_of_list_memberships
    setup_members
    @list_cmd.options = @list_cmd.options.merge("sort" => "listed")
    @list_cmd.members("presidents")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_members_with_sort_since_sorts_by_the_time_when_twitter_account_was_created
    setup_members
    @list_cmd.options = @list_cmd.options.merge("sort" => "since")
    @list_cmd.members("presidents")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_members_with_sort_tweets_sorts_by_the_number_of_tweets
    setup_members
    @list_cmd.options = @list_cmd.options.merge("sort" => "tweets")
    @list_cmd.members("presidents")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_members_with_sort_tweeted_sorts_by_the_time_of_the_last_tweet
    setup_members
    @list_cmd.options = @list_cmd.options.merge("sort" => "tweeted")
    @list_cmd.members("presidents")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_members_with_unsorted_is_not_sorted
    setup_members
    @list_cmd.options = @list_cmd.options.merge("unsorted" => true)
    @list_cmd.members("presidents")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_members_with_user_passed_requests_the_user_lookup_resource
    setup_members
    @list_cmd.members("testcli/presidents")

    assert_requested(:get, v2_pattern("users/by/username/testcli"))
  end

  def test_members_with_user_passed_requests_the_owned_lists_resource
    setup_members
    @list_cmd.members("testcli/presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_members_with_user_passed_requests_the_list_members_resource
    setup_members
    @list_cmd.members("testcli/presidents")

    assert_requested(:get, v2_pattern("lists/8863586/members"))
  end

  def test_members_with_user_passed_requests_the_user_details_resource
    setup_members
    @list_cmd.members("testcli/presidents")

    assert_requested(:get, %r{api\.twitter\.com/2/users\?})
  end

  def test_members_with_user_passed_and_id_requests_the_owned_lists_resource
    setup_members
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/members").to_return(v2_return("v2/users_list.json"))
    stub_request(:get, %r{api\.twitter\.com/2/users\?}).to_return(v2_return("v2/users_list.json"))
    @list_cmd.members("7505382/presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_members_with_user_passed_and_id_requests_the_list_members_resource
    setup_members
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/members").to_return(v2_return("v2/users_list.json"))
    stub_request(:get, %r{api\.twitter\.com/2/users\?}).to_return(v2_return("v2/users_list.json"))
    @list_cmd.members("7505382/presidents")

    assert_requested(:get, v2_pattern("lists/8863586/members"))
  end

  def test_members_with_user_passed_and_id_requests_the_user_details
    setup_members
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/members").to_return(v2_return("v2/users_list.json"))
    stub_request(:get, %r{api\.twitter\.com/2/users\?}).to_return(v2_return("v2/users_list.json"))
    @list_cmd.members("7505382/presidents")

    assert_requested(:get, %r{api\.twitter\.com/2/users\?})
  end

  # remove

  def setup_remove
    @list_cmd.options = @list_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_user_by_name("BarackObama")
  end

  def test_remove_requests_the_current_user_resource
    setup_remove
    stub_v2_delete("lists/8863586/members/7505382").to_return(v2_return("v2/post_response.json"))
    @list_cmd.remove("presidents", "BarackObama")

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_remove_requests_the_owned_lists_resource
    setup_remove
    stub_v2_delete("lists/8863586/members/7505382").to_return(v2_return("v2/post_response.json"))
    @list_cmd.remove("presidents", "BarackObama")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_remove_deletes_the_list_member
    setup_remove
    stub_v2_delete("lists/8863586/members/7505382").to_return(v2_return("v2/post_response.json"))
    @list_cmd.remove("presidents", "BarackObama")

    assert_requested(:delete, v2_pattern("lists/8863586/members/7505382"))
  end

  def test_remove_has_the_correct_output
    setup_remove
    stub_v2_delete("lists/8863586/members/7505382").to_return(v2_return("v2/post_response.json"))
    @list_cmd.remove("presidents", "BarackObama")

    assert_equal('@testcli removed 1 member from the list "presidents".', $stdout.string.split("\n").first)
  end

  def test_remove_with_id_requests_the_current_user_resource
    setup_remove
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_delete("lists/8863586/members/7505382").to_return(v2_return("v2/post_response.json"))
    @list_cmd.remove("presidents", "7505382")

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_remove_with_id_requests_the_owned_lists_resource
    setup_remove
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_delete("lists/8863586/members/7505382").to_return(v2_return("v2/post_response.json"))
    @list_cmd.remove("presidents", "7505382")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_remove_with_id_deletes_the_list_member
    setup_remove
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_delete("lists/8863586/members/7505382").to_return(v2_return("v2/post_response.json"))
    @list_cmd.remove("presidents", "7505382")

    assert_requested(:delete, v2_pattern("lists/8863586/members/7505382"))
  end

  def test_remove_when_twitter_is_down_raises_an_error_after_retries
    setup_remove
    stub_v2_delete("lists/8863586/members/7505382").to_return(status: 502, body: '{"errors":[{"message":"Bad Gateway"}]}', headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) do
      @list_cmd.remove("presidents", "BarackObama")
    end
  end

  def test_remove_when_twitter_is_down_retries_3_times_before_failing
    setup_remove
    stub_v2_delete("lists/8863586/members/7505382").to_return(status: 502, body: '{"errors":[{"message":"Bad Gateway"}]}', headers: V2_JSON_HEADERS)
    @list_cmd.remove("presidents", "BarackObama")
  rescue X::BadGateway
    assert_requested(:delete, v2_pattern("lists/8863586/members/7505382"), times: 3)
  end

  # timeline

  def setup_timeline
    @list_cmd.options = @list_cmd.options.merge("color" => "always")
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json"))
  end

  def expected_timeline_output
    <<-EOS
   @mutgoff
   Happy Birthday @imdane. Watch out for those @rally pranksters!

   @ironicsans
   If you like good real-life stories, check out @NarrativelyNY's just-launched
   site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)

   @pat_shaughnessy
   Something else to vote for: "New Rails workshops to bring more women into
   the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb

   @calebelston
   Pushing the button to launch the site. http://t.co/qLoEn5jG

   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @fivethirtyeight
   The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my
   book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

   @fbjork
   RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
   http://t.co/kGEykswZ /cc @JRuby @headius

   @mbostock
   If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u

   @FakeDorsey
   "Write drunk. Edit sober."—Ernest Hemingway

   @al3x
   RT @wcmaier: Better banking through better ops: build something new with us
   @Simplify (remote, PDX) http://t.co/8WgzKZH3

   @calebelston
   We just announced Mosaic, what we've been working on since the Yobongo
   acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic

   @BarackObama
   Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2
   #Obama2012

   @JEG2
   RT @tenderlove: If corporations are people, can we use them to drive in the
   carpool lane?

   @eveningedition
   LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake
   China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4

   @dhh
   RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
   achievement: why this goulish jingoism is so warped http://t.co/kood278s

   @jasonfried
   The story of Mars Curiosity's gears, made by a factory in Rockford, IL:
   http://t.co/MwCRsHQg

   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

   @dwiskus
   Gentlemen, you can't fight in here! This is the war room!
   http://t.co/kMxMYyqF

    EOS
  end

  def test_timeline_requests_the_user_lookup_resource
    setup_timeline
    @list_cmd.timeline("presidents")

    assert_requested(:get, v2_pattern("users/by/username/testcli"))
  end

  def test_timeline_requests_the_owned_lists_resource
    setup_timeline
    @list_cmd.timeline("presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_timeline_requests_the_list_tweets_resource
    setup_timeline
    @list_cmd.timeline("presidents")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"))
  end

  def test_timeline_has_the_correct_output
    setup_timeline
    @list_cmd.timeline("presidents")

    assert_equal(expected_timeline_output, $stdout.string)
  end

  def test_timeline_with_color_never_outputs_without_color
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("color" => "never")
    @list_cmd.timeline("presidents")

    assert_equal(expected_timeline_output, $stdout.string)
  end

  def expected_color_output
    <<~EOS
      \e[1m\e[33m   @mutgoff\e[0m
         Happy Birthday @imdane. Watch out for those @rally pranksters!

      \e[1m\e[33m   @ironicsans\e[0m
         If you like good real-life stories, check out @NarrativelyNY's just-launched
         site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)

      \e[1m\e[33m   @pat_shaughnessy\e[0m
         Something else to vote for: "New Rails workshops to bring more women into
         the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb

      \e[1m\e[33m   @calebelston\e[0m
         Pushing the button to launch the site. http://t.co/qLoEn5jG

      \e[1m\e[33m   @calebelston\e[0m
         RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

      \e[1m\e[33m   @fivethirtyeight\e[0m
         The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my
         book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)

      \e[1m\e[33m   @codeforamerica\e[0m
         RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
         Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
         @TheaClay

      \e[1m\e[33m   @fbjork\e[0m
         RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
         http://t.co/kGEykswZ /cc @JRuby @headius

      \e[1m\e[33m   @mbostock\e[0m
         If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u

      \e[1m\e[33m   @FakeDorsey\e[0m
         "Write drunk. Edit sober."—Ernest Hemingway

      \e[1m\e[33m   @al3x\e[0m
         RT @wcmaier: Better banking through better ops: build something new with us
         @Simplify (remote, PDX) http://t.co/8WgzKZH3

      \e[1m\e[33m   @calebelston\e[0m
         We just announced Mosaic, what we've been working on since the Yobongo
         acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic

      \e[1m\e[33m   @BarackObama\e[0m
         Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2
         #Obama2012

      \e[1m\e[33m   @JEG2\e[0m
         RT @tenderlove: If corporations are people, can we use them to drive in the
         carpool lane?

      \e[1m\e[33m   @eveningedition\e[0m
         LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake
         China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4

      \e[1m\e[33m   @dhh\e[0m
         RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
         achievement: why this goulish jingoism is so warped http://t.co/kood278s

      \e[1m\e[33m   @jasonfried\e[0m
         The story of Mars Curiosity's gears, made by a factory in Rockford, IL:
         http://t.co/MwCRsHQg

      \e[1m\e[33m   @sferik\e[0m
         @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
         to be missing "1.1" from the URL.

      \e[1m\e[33m   @sferik\e[0m
         @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

      \e[1m\e[33m   @dwiskus\e[0m
         Gentlemen, you can't fight in here! This is the war room!
         http://t.co/kMxMYyqF

    EOS
  end

  def test_timeline_with_color_auto_outputs_without_color_when_stdout_is_not_a_tty
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("color" => "auto")
    def $stdout.tty? = false
    @list_cmd.timeline("presidents")

    assert_equal(expected_timeline_output, $stdout.string)
  end

  def test_timeline_with_color_auto_outputs_with_color_when_stdout_is_a_tty
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("color" => "auto")
    def $stdout.tty? = true
    @list_cmd.timeline("presidents")

    assert_equal(expected_color_output, $stdout.string)
  end

  def test_timeline_with_color_icon_outputs_with_color_when_stdout_is_a_tty
    require "t/identicon"
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("color" => "icon")
    def $stdout.tty? = true

    icon_names = %w[mutgoff ironicsans pat_shaughnessy calebelston fivethirtyeight
                    codeforamerica fbjork mbostock FakeDorsey al3x BarackObama
                    JEG2 eveningedition dhh jasonfried sferik dwiskus]
    icons = icon_names.to_h { |elem| [elem.to_sym, T::Identicon.for_user_name(elem)] }

    expected = <<-EOS
  #{icons[:mutgoff].lines[0]}\e[1m\e[33m  @mutgoff\e[0m
  #{icons[:mutgoff].lines[1]}  Happy Birthday @imdane. Watch out for those @rally pranksters!
  #{icons[:mutgoff].lines[2]}


  #{icons[:ironicsans].lines[0]}\e[1m\e[33m  @ironicsans\e[0m
  #{icons[:ironicsans].lines[1]}  If you like good real-life stories, check out @NarrativelyNY's
  #{icons[:ironicsans].lines[2]}  just-launched site http://t.co/wiUL07jE (and also visit
          http://t.co/ZoyQxqWA)


  #{icons[:pat_shaughnessy].lines[0]}\e[1m\e[33m  @pat_shaughnessy\e[0m
  #{icons[:pat_shaughnessy].lines[1]}  Something else to vote for: "New Rails workshops to bring more women
  #{icons[:pat_shaughnessy].lines[2]}  into the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb


  #{icons[:calebelston].lines[0]}\e[1m\e[33m  @calebelston\e[0m
  #{icons[:calebelston].lines[1]}  Pushing the button to launch the site. http://t.co/qLoEn5jG
  #{icons[:calebelston].lines[2]}


  #{icons[:calebelston].lines[0]}\e[1m\e[33m  @calebelston\e[0m
  #{icons[:calebelston].lines[1]}  RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
  #{icons[:calebelston].lines[2]}


  #{icons[:fivethirtyeight].lines[0]}\e[1m\e[33m  @fivethirtyeight\e[0m
  #{icons[:fivethirtyeight].lines[1]}  The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from
  #{icons[:fivethirtyeight].lines[2]}  my book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)


  #{icons[:codeforamerica].lines[0]}\e[1m\e[33m  @codeforamerica\e[0m
  #{icons[:codeforamerica].lines[1]}  RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now,
  #{icons[:codeforamerica].lines[2]}  Sat, Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok
          @codeforamerica @TheaClay


  #{icons[:fbjork].lines[0]}\e[1m\e[33m  @fbjork\e[0m
  #{icons[:fbjork].lines[1]}  RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
  #{icons[:fbjork].lines[2]}  http://t.co/kGEykswZ /cc @JRuby @headius


  #{icons[:mbostock].lines[0]}\e[1m\e[33m  @mbostock\e[0m
  #{icons[:mbostock].lines[1]}  If you are wondering how we computed the split bubbles:
  #{icons[:mbostock].lines[2]}  http://t.co/BcaqSs5u


  #{icons[:FakeDorsey].lines[0]}\e[1m\e[33m  @FakeDorsey\e[0m
  #{icons[:FakeDorsey].lines[1]}  "Write drunk. Edit sober."—Ernest Hemingway
  #{icons[:FakeDorsey].lines[2]}


  #{icons[:al3x].lines[0]}\e[1m\e[33m  @al3x\e[0m
  #{icons[:al3x].lines[1]}  RT @wcmaier: Better banking through better ops: build something new
  #{icons[:al3x].lines[2]}  with us @Simplify (remote, PDX) http://t.co/8WgzKZH3


  #{icons[:calebelston].lines[0]}\e[1m\e[33m  @calebelston\e[0m
  #{icons[:calebelston].lines[1]}  We just announced Mosaic, what we've been working on since the
  #{icons[:calebelston].lines[2]}  Yobongo acquisition. My personal post, http://t.co/ELOyIRZU
          @heymosaic


  #{icons[:BarackObama].lines[0]}\e[1m\e[33m  @BarackObama\e[0m
  #{icons[:BarackObama].lines[1]}  Donate $10 or more --> get your favorite car magnet:
  #{icons[:BarackObama].lines[2]}  http://t.co/NfRhl2s2 #Obama2012


  #{icons[:JEG2].lines[0]}\e[1m\e[33m  @JEG2\e[0m
  #{icons[:JEG2].lines[1]}  RT @tenderlove: If corporations are people, can we use them to drive
  #{icons[:JEG2].lines[2]}  in the carpool lane?


  #{icons[:eveningedition].lines[0]}\e[1m\e[33m  @eveningedition\e[0m
  #{icons[:eveningedition].lines[1]}  LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes
  #{icons[:eveningedition].lines[2]}  shake China; Canada cuts Iran ties; weekend read:
          http://t.co/OFs6dVW4


  #{icons[:dhh].lines[0]}\e[1m\e[33m  @dhh\e[0m
  #{icons[:dhh].lines[1]}  RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their
  #{icons[:dhh].lines[2]}  proudest achievement: why this goulish jingoism is so warped
          http://t.co/kood278s


  #{icons[:jasonfried].lines[0]}\e[1m\e[33m  @jasonfried\e[0m
  #{icons[:jasonfried].lines[1]}  The story of Mars Curiosity's gears, made by a factory in Rockford,
  #{icons[:jasonfried].lines[2]}  IL: http://t.co/MwCRsHQg


  #{icons[:sferik].lines[0]}\e[1m\e[33m  @sferik\e[0m
  #{icons[:sferik].lines[1]}  @episod @twitterapi now https://t.co/I17jUTu2 and
  #{icons[:sferik].lines[2]}  https://t.co/deDu4Hgw seem to be missing "1.1" from the URL.


  #{icons[:sferik].lines[0]}\e[1m\e[33m  @sferik\e[0m
  #{icons[:sferik].lines[1]}  @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
  #{icons[:sferik].lines[2]}


  #{icons[:dwiskus].lines[0]}\e[1m\e[33m  @dwiskus\e[0m
  #{icons[:dwiskus].lines[1]}  Gentlemen, you can't fight in here! This is the war room!
  #{icons[:dwiskus].lines[2]}  http://t.co/kMxMYyqF


    EOS
    expected_icon_output = expected.gsub(/ +$/, "")

    @list_cmd.timeline("presidents")
    actual = $stdout.string.gsub(/ +$/, "")

    assert_equal(expected_icon_output, actual)
  end

  def expected_csv_output
    <<~EOS
      ID,Posted at,Screen name,Text
      4611686018427387904,2012-09-07 16:35:24 +0000,mutgoff,Happy Birthday @imdane. Watch out for those @rally pranksters!
      244111183165157376,2012-09-07 16:33:36 +0000,ironicsans,"If you like good real-life stories, check out @NarrativelyNY's just-launched site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)"
      244110336414859264,2012-09-07 16:30:14 +0000,pat_shaughnessy,"Something else to vote for: ""New Rails workshops to bring more women into the Boston software scene"" http://t.co/eNBuckHc /cc @bostonrb"
      244109797308379136,2012-09-07 16:28:05 +0000,calebelston,Pushing the button to launch the site. http://t.co/qLoEn5jG
      244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
      244107890632294400,2012-09-07 16:20:31 +0000,fivethirtyeight,"The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)"
      244107823733174272,2012-09-07 16:20:15 +0000,codeforamerica,"RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat, Sep 8 http://t.co/Sk5BM7U3  We'll see y'all there! #rhok @codeforamerica @TheaClay"
      244107236262170624,2012-09-07 16:17:55 +0000,fbjork,"RT @jondot: Just published: ""Pragmatic Concurrency With #Ruby"" http://t.co/kGEykswZ   /cc @JRuby @headius"
      244106476048764928,2012-09-07 16:14:53 +0000,mbostock,If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u
      244105599351148544,2012-09-07 16:11:24 +0000,FakeDorsey,"""Write drunk. Edit sober.""—Ernest Hemingway"
      244104558433951744,2012-09-07 16:07:16 +0000,al3x,"RT @wcmaier: Better banking through better ops: build something new with us @Simplify (remote, PDX) http://t.co/8WgzKZH3"
      244104146997870594,2012-09-07 16:05:38 +0000,calebelston,"We just announced Mosaic, what we've been working on since the Yobongo acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic"
      244103057175113729,2012-09-07 16:01:18 +0000,BarackObama,Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2 #Obama2012
      244102834398851073,2012-09-07 16:00:25 +0000,JEG2,"RT @tenderlove: If corporations are people, can we use them to drive in the carpool lane?"
      244102741125890048,2012-09-07 16:00:03 +0000,eveningedition,LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4
      244102729860009984,2012-09-07 16:00:00 +0000,dhh,RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest achievement: why this goulish jingoism is so warped http://t.co/kood278s
      244102490646278146,2012-09-07 15:59:03 +0000,jasonfried,"The story of Mars Curiosity's gears, made by a factory in Rockford, IL: http://t.co/MwCRsHQg"
      244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
      244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
      244099460672679938,2012-09-07 15:47:01 +0000,dwiskus,"Gentlemen, you can't fight in here! This is the war room! http://t.co/kMxMYyqF"
    EOS
  end

  def test_timeline_with_csv_outputs_in_csv_format
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("csv" => true)
    @list_cmd.timeline("presidents")

    assert_equal(expected_csv_output, $stdout.string)
  end

  def test_timeline_with_decode_uris_requests_the_correct_resource
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("decode_uris" => true)
    @list_cmd.timeline("presidents")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"))
  end

  def test_timeline_with_decode_uris_decodes_urls
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("decode_uris" => true)
    @list_cmd.timeline("presidents")

    assert_includes($stdout.string, "http://t.co/kMxMYyqF")
  end

  def expected_long_output
    <<~EOS
      ID                   Posted at     Screen name       Text
      4611686018427387904  Sep  7 08:35  @mutgoff          Happy Birthday @imdane. ...
       244111183165157376  Sep  7 08:33  @ironicsans       If you like good real-li...
       244110336414859264  Sep  7 08:30  @pat_shaughnessy  Something else to vote f...
       244109797308379136  Sep  7 08:28  @calebelston      Pushing the button to la...
       244108728834592770  Sep  7 08:23  @calebelston      RT @olivercameron: Mosai...
       244107890632294400  Sep  7 08:20  @fivethirtyeight  The Weatherman is Not a ...
       244107823733174272  Sep  7 08:20  @codeforamerica   RT @randomhacks: Going t...
       244107236262170624  Sep  7 08:17  @fbjork           RT @jondot: Just publish...
       244106476048764928  Sep  7 08:14  @mbostock         If you are wondering how...
       244105599351148544  Sep  7 08:11  @FakeDorsey       "Write drunk. Edit sober...
       244104558433951744  Sep  7 08:07  @al3x             RT @wcmaier: Better bank...
       244104146997870594  Sep  7 08:05  @calebelston      We just announced Mosaic...
       244103057175113729  Sep  7 08:01  @BarackObama      Donate $10 or more --> g...
       244102834398851073  Sep  7 08:00  @JEG2             RT @tenderlove: If corpo...
       244102741125890048  Sep  7 08:00  @eveningedition   LDN—Obama's nomination; ...
       244102729860009984  Sep  7 08:00  @dhh              RT @ggreenwald: Democrat...
       244102490646278146  Sep  7 07:59  @jasonfried       The story of Mars Curios...
       244102209942458368  Sep  7 07:57  @sferik           @episod @twitterapi now ...
       244100411563339777  Sep  7 07:50  @sferik           @episod @twitterapi Did ...
       244099460672679938  Sep  7 07:47  @dwiskus          Gentlemen, you can't fig...
    EOS
  end

  def test_timeline_with_long_outputs_in_long_format
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("long" => true)
    @list_cmd.timeline("presidents")

    assert_equal(expected_long_output, $stdout.string)
  end

  def expected_reverse_output
    <<~EOS
      ID                   Posted at     Screen name       Text
       244099460672679938  Sep  7 07:47  @dwiskus          Gentlemen, you can't fig...
       244100411563339777  Sep  7 07:50  @sferik           @episod @twitterapi Did ...
       244102209942458368  Sep  7 07:57  @sferik           @episod @twitterapi now ...
       244102490646278146  Sep  7 07:59  @jasonfried       The story of Mars Curios...
       244102729860009984  Sep  7 08:00  @dhh              RT @ggreenwald: Democrat...
       244102741125890048  Sep  7 08:00  @eveningedition   LDN—Obama's nomination; ...
       244102834398851073  Sep  7 08:00  @JEG2             RT @tenderlove: If corpo...
       244103057175113729  Sep  7 08:01  @BarackObama      Donate $10 or more --> g...
       244104146997870594  Sep  7 08:05  @calebelston      We just announced Mosaic...
       244104558433951744  Sep  7 08:07  @al3x             RT @wcmaier: Better bank...
       244105599351148544  Sep  7 08:11  @FakeDorsey       "Write drunk. Edit sober...
       244106476048764928  Sep  7 08:14  @mbostock         If you are wondering how...
       244107236262170624  Sep  7 08:17  @fbjork           RT @jondot: Just publish...
       244107823733174272  Sep  7 08:20  @codeforamerica   RT @randomhacks: Going t...
       244107890632294400  Sep  7 08:20  @fivethirtyeight  The Weatherman is Not a ...
       244108728834592770  Sep  7 08:23  @calebelston      RT @olivercameron: Mosai...
       244109797308379136  Sep  7 08:28  @calebelston      Pushing the button to la...
       244110336414859264  Sep  7 08:30  @pat_shaughnessy  Something else to vote f...
       244111183165157376  Sep  7 08:33  @ironicsans       If you like good real-li...
      4611686018427387904  Sep  7 08:35  @mutgoff          Happy Birthday @imdane. ...
    EOS
  end

  def test_timeline_with_long_and_reverse_reverses_the_order_of_the_sort
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("long" => true, "reverse" => true)
    @list_cmd.timeline("presidents")

    assert_equal(expected_reverse_output, $stdout.string)
  end

  def test_timeline_with_number_limits_the_number_of_results_to_1
    setup_timeline
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @list_cmd.options = @list_cmd.options.merge("number" => 1)
    @list_cmd.timeline("presidents")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"))
  end

  def test_timeline_with_number_limits_the_number_of_results_to_201
    setup_timeline
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json")).then.to_return(v2_return("v2/empty.json"))
    @list_cmd.options = @list_cmd.options.merge("number" => 201)
    @list_cmd.timeline("presidents")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"), at_least_times: 1)
  end

  def test_timeline_with_user_passed_requests_the_user_lookup_resource
    setup_timeline
    @list_cmd.timeline("testcli/presidents")

    assert_requested(:get, v2_pattern("users/by/username/testcli"))
  end

  def test_timeline_with_user_passed_requests_the_owned_lists_resource
    setup_timeline
    @list_cmd.timeline("testcli/presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_timeline_with_user_passed_requests_the_list_tweets_resource
    setup_timeline
    @list_cmd.timeline("testcli/presidents")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"))
  end

  def test_timeline_with_user_passed_and_id_requests_the_owned_lists_resource
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json"))
    @list_cmd.timeline("7505382/presidents")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_timeline_with_user_passed_and_id_requests_the_list_tweets_resource
    setup_timeline
    @list_cmd.options = @list_cmd.options.merge("id" => true)
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586/tweets").to_return(v2_return("v2/statuses.json"))
    @list_cmd.timeline("7505382/presidents")

    assert_requested(:get, v2_pattern("lists/8863586/tweets"))
  end
end
