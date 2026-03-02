# encoding: utf-8

require "test_helper"

class TestCLI < TTestCase
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
    @cli = T::CLI.new
    @cli.options = @cli.options.merge("color" => "always")
    stub_v2_user_by_name("sferik")
    stub_v2_user_by_name("testcli")
  end

  def teardown
    T::RCFile.instance.reset
    T.utc_offset = nil
    Timecop.return
    $stderr = @original_stderr
    $stdout = @original_stdout
    super
  end

  # accounts

  def test_accounts_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    @cli.accounts

    assert_equal(<<~EOS, $stdout.string)
      testcli
        abc123 (active)
    EOS
  end

  # authorize

  def authorize_stubs
    @cli.options = @cli.options.merge("profile" => "#{project_path}/tmp/authorize", "display-uri" => true)
    stub_post("/oauth/request_token").to_return(body: fixture("request_token"))
    stub_post("/oauth/access_token").to_return(body: fixture("access_token"))
    stub_get("/1.1/account/verify_credentials.json?skip_status=true").to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    stub_v2_current_user
  end

  def authorize_readline_stub
    ->(prompt, _) {
      case prompt
      when /API key/ then "abc123"
      when /API secret/ then "asdfasd223sd2"
      when /PIN/ then "1234567890"
      else "\n"
      end
    }
  end

  def test_authorize_requests_oauth_request_token
    authorize_stubs
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end

    assert_requested(:post, "https://api.twitter.com/oauth/request_token")
  end

  def test_authorize_requests_oauth_access_token
    authorize_stubs
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end

    assert_requested(:post, "https://api.twitter.com/oauth/access_token")
  end

  def test_authorize_verifies_credentials
    authorize_stubs
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end

    assert_requested(:get, "https://api.twitter.com/1.1/account/verify_credentials.json?skip_status=true")
  end

  def test_authorize_does_not_raise_error
    authorize_stubs
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end
  end

  def test_authorize_with_empty_rc_file_requests_oauth_request_token
    authorize_stubs
    file_path = "#{project_path}/tmp/empty"
    @cli.options = @cli.options.merge("profile" => file_path, "display-uri" => true)
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end

    assert_requested(:post, "https://api.twitter.com/oauth/request_token")
  ensure
    FileUtils.rm_f(file_path)
  end

  def test_authorize_with_empty_rc_file_requests_oauth_access_token
    authorize_stubs
    file_path = "#{project_path}/tmp/empty"
    @cli.options = @cli.options.merge("profile" => file_path, "display-uri" => true)
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end

    assert_requested(:post, "https://api.twitter.com/oauth/access_token")
  ensure
    FileUtils.rm_f(file_path)
  end

  def test_authorize_with_empty_rc_file_verifies_credentials
    authorize_stubs
    file_path = "#{project_path}/tmp/empty"
    @cli.options = @cli.options.merge("profile" => file_path, "display-uri" => true)
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end

    assert_requested(:get, "https://api.twitter.com/1.1/account/verify_credentials.json?skip_status=true")
  ensure
    FileUtils.rm_f(file_path)
  end

  def test_authorize_with_empty_rc_file_does_not_raise_error
    authorize_stubs
    file_path = "#{project_path}/tmp/empty"
    @cli.options = @cli.options.merge("profile" => file_path, "display-uri" => true)
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end
  ensure
    FileUtils.rm_f(file_path)
  end

  # block

  def block_stubs
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_post("users/7505382/blocking").to_return(v2_return("v2/post_response.json"))
  end

  def test_block_looks_up_current_user
    block_stubs
    @cli.block("sferik")

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_block_looks_up_target_user
    block_stubs
    @cli.block("sferik")

    assert_requested(:get, v2_pattern("users/by/username/sferik"))
  end

  def test_block_sends_block_request
    block_stubs
    @cli.block("sferik")

    assert_requested(:post, v2_pattern("users/7505382/blocking"))
  end

  def test_block_has_the_correct_output
    block_stubs
    @cli.block("sferik")

    assert_match(/^@testcli blocked 1 user/, $stdout.string)
  end

  def test_block_with_id_requests_user_by_id
    block_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    stub_v2_post("users/7505382/blocking").to_return(v2_return("v2/post_response.json"))
    @cli.block("7505382")

    assert_requested(:get, v2_pattern("users/7505382"))
  end

  def test_block_with_id_sends_block_request
    block_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    stub_v2_post("users/7505382/blocking").to_return(v2_return("v2/post_response.json"))
    @cli.block("7505382")

    assert_requested(:post, v2_pattern("users/7505382/blocking"))
  end

  # direct_messages

  def dm_stubs
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(body: fixture("direct_message_events.json"), headers: V2_JSON_HEADERS)
    stub_v2_users_lookup.to_return(body: fixture("v2/dm_users.json"), headers: V2_JSON_HEADERS)
  end

  def test_direct_messages_requests_dm_events
    dm_stubs
    @cli.direct_messages

    assert_requested(:get, v2_pattern("dm_events"), at_least_times: 1)
  end

  def test_direct_messages_requests_current_user
    dm_stubs
    @cli.direct_messages

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_direct_messages_has_the_correct_output
    dm_stubs
    @cli.direct_messages
    expected_output = <<-EOS
   @
   Thanks https://twitter.com/i/stickers/image/10011

   @Araujoselmaa
   \u2764\uFE0F

   @nederfariar
   \u{1F60D}

   @juliawerneckx
   obrigada!!! bj

   @
   https://twitter.com/i/stickers/image/10011

   @marlonscampos
   OBRIGADO MINHA LINDA SER\u00C1 INCR\u00CDVEL ASSISTIR O TEU SHOW, VOU FAZER O POSS\u00CDVEL
   PARA TE PRESTIGIAR. SUCESSO

   @abcss_cesar
   Obrigado. Vou adquiri-lo. Muito sucesso!

   @nederfariar
   COM CERTEZA QDO ESTIVER EM SAO PAU\u00C7O IREI COM O MAIOR PRAZER SUCESSO LINDA

   @Free7Freejac
   \u{1F60D} M\u00FAsica boa para seu espet\u00E1culo em S\u00E3o-Paulo com seu amigo

   @Free7Freejac
   Jardim urbano

   @Free7Freejac
   https://twitter.com/messages/media/856478621090942979

   @Free7Freejac
   Os amantes em face a o mar

   @Free7Freejac
   https://twitter.com/messages/media/856477710595624963

    EOS
    assert_equal(expected_output, $stdout.string)
  end

  def test_direct_messages_with_csv
    dm_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.direct_messages

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
    assert_includes($stdout.string, "856574281366605831")
  end

  def test_direct_messages_with_decode_uris
    dm_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.direct_messages

    assert_requested(:get, v2_pattern("dm_events"), at_least_times: 1)
  end

  def test_direct_messages_with_long
    dm_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.direct_messages

    assert_includes($stdout.string, "856574281366605831")
    assert_includes($stdout.string, "@Araujoselmaa")
  end

  def test_direct_messages_with_number
    dm_stubs
    @cli.options = @cli.options.merge("number" => 1)
    @cli.direct_messages

    assert_requested(:get, v2_pattern("dm_events"))
  end

  def test_direct_messages_with_reverse
    dm_stubs
    @cli.options = @cli.options.merge("reverse" => true)
    @cli.direct_messages
    lines = $stdout.string.lines
    # In reverse, the last DM (Free7Freejac media link) should appear first
    assert_match(/Free7Freejac/, lines.first(5).join)
  end

  # direct_messages_sent

  def dm_sent_stubs
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(body: fixture("direct_message_events.json"), headers: V2_JSON_HEADERS)
    stub_v2_users_lookup.to_return(body: fixture("v2/users_list.json"), headers: V2_JSON_HEADERS)
  end

  def test_direct_messages_sent_requests_correct_resource
    dm_sent_stubs
    @cli.direct_messages_sent

    assert_requested(:get, v2_pattern("dm_events"), at_least_times: 1)
  end

  def test_direct_messages_sent_has_output
    dm_sent_stubs
    @cli.direct_messages_sent

    refute_empty($stdout.string)
  end

  def test_direct_messages_sent_with_csv
    dm_sent_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.direct_messages_sent

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
  end

  def test_direct_messages_sent_with_decode_uris
    dm_sent_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.direct_messages_sent

    assert_requested(:get, v2_pattern("dm_events"), at_least_times: 1)
  end

  def test_direct_messages_sent_with_long
    dm_sent_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.direct_messages_sent

    assert_includes($stdout.string, "ID")
    assert_includes($stdout.string, "Posted at")
  end

  def test_direct_messages_sent_with_number_1
    dm_sent_stubs
    @cli.options = @cli.options.merge("number" => 1)
    @cli.direct_messages_sent

    assert_requested(:get, v2_pattern("dm_events"), at_least_times: 1)
  end

  def test_direct_messages_sent_with_number_201
    dm_sent_stubs
    @cli.options = @cli.options.merge("number" => 201)
    @cli.direct_messages_sent

    assert_requested(:get, v2_pattern("dm_events"), at_least_times: 1)
  end

  def test_direct_messages_sent_with_reverse
    dm_sent_stubs
    @cli.options = @cli.options.merge("reverse" => true)
    @cli.direct_messages_sent

    refute_empty($stdout.string)
  end

  # dm

  def test_dm_requests_user_lookup
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_user_by_name("sferik")
    stub_v2_post("dm_conversations/with/7505382/messages").to_return(v2_return("v2/dm_event.json"))
    stub_v2_user_by_id("7505382")
    @cli.dm("sferik", "Creating a fixture for the Twitter gem")

    assert_requested(:get, v2_pattern("users/by/username/sferik"))
  end

  def test_dm_sends_message
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_user_by_name("sferik")
    stub_v2_post("dm_conversations/with/7505382/messages").to_return(v2_return("v2/dm_event.json"))
    stub_v2_user_by_id("7505382")
    @cli.dm("sferik", "Creating a fixture for the Twitter gem")

    assert_requested(:post, v2_pattern("dm_conversations/with/7505382/messages"))
  end

  def test_dm_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_user_by_name("sferik")
    stub_v2_post("dm_conversations/with/7505382/messages").to_return(v2_return("v2/dm_event.json"))
    stub_v2_user_by_id("7505382")
    @cli.dm("sferik", "Creating a fixture for the Twitter gem")

    assert_equal("Direct Message sent from @testcli to @sferik.", $stdout.string.chomp)
  end

  def test_dm_with_id_sends_message
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc", "id" => true)
    stub_v2_post("dm_conversations/with/7505382/messages").to_return(v2_return("v2/dm_event.json"))
    stub_v2_user_by_id("7505382")
    @cli.dm("7505382", "Creating a fixture for the Twitter gem")

    assert_requested(:post, v2_pattern("dm_conversations/with/7505382/messages"))
  end

  def test_dm_with_id_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc", "id" => true)
    stub_v2_post("dm_conversations/with/7505382/messages").to_return(v2_return("v2/dm_event.json"))
    stub_v2_user_by_id("7505382")
    @cli.dm("7505382", "Creating a fixture for the Twitter gem")

    assert_equal("Direct Message sent from @testcli to @sferik.", $stdout.string.chomp)
  end

  # does_contain

  def does_contain_stubs
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/lists.json"))
    stub_v2_get("lists/presidents/members").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
  end

  def test_does_contain_requests_correct_resource
    does_contain_stubs
    @cli.does_contain("presidents")

    assert_requested(:get, v2_pattern("users/by/username/testcli"), at_least_times: 1)
  end

  def test_does_contain_has_the_correct_output
    does_contain_stubs
    @cli.does_contain("presidents")

    assert_equal("Yes, presidents contains @testcli.", $stdout.string.chomp)
  end

  def test_does_contain_with_id
    does_contain_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    stub_v2_user_by_name("sferik")
    @cli.does_contain("presidents", "7505382")

    assert_requested(:get, v2_pattern("users/7505382"), at_least_times: 1)
  end

  def test_does_contain_with_owner_passed
    does_contain_stubs
    @cli.does_contain("testcli/presidents", "testcli")

    assert_equal("Yes, presidents contains @testcli.", $stdout.string.chomp)
  end

  def test_does_contain_with_owner_and_id
    does_contain_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/lists.json"))
    stub_v2_get("lists/presidents/members").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_contain("7505382/presidents", "7505382")

    assert_requested(:get, v2_pattern("users/7505382"), at_least_times: 1)
  end

  def test_does_contain_with_user_passed
    does_contain_stubs
    @cli.does_contain("presidents", "testcli")

    assert_equal("Yes, presidents contains @testcli.", $stdout.string.chomp)
  end

  def test_does_contain_false_exits
    does_contain_stubs
    stub_v2_get("lists/presidents/members").to_return(v2_return("v2/empty.json"))
    assert_raises(SystemExit) { @cli.does_contain("presidents") }
  end

  # does_follow

  def does_follow_stubs
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("testcli")
    stub_v2_user_by_name("ev", "v2/sferik.json")
  end

  def test_does_follow_requests_correct_resource
    does_follow_stubs
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_follow("ev")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_does_follow_has_the_correct_output
    does_follow_stubs
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_follow("ev")

    assert_equal("Yes, @ev follows @testcli.", $stdout.string.chomp)
  end

  def test_does_follow_with_id_requests_user
    does_follow_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_follow("20")

    assert_requested(:get, v2_pattern("users/20"), at_least_times: 1)
  end

  def test_does_follow_with_id_requests_following_list
    does_follow_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_follow("20")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_does_follow_with_id_has_the_correct_output
    does_follow_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_follow("20")

    assert_equal("Yes, @sferik follows @testcli.", $stdout.string.chomp)
  end

  def test_does_follow_with_user_passed_requests_following
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_follow("ev", "sferik")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_does_follow_with_user_passed_has_the_correct_output
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.does_follow("ev", "sferik")

    assert_equal("Yes, @ev follows @sferik.", $stdout.string.chomp)
  end

  def test_does_follow_with_user_and_id_requests_users
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_id("428004849")
    @cli.does_follow("20", "428004849")

    assert_requested(:get, v2_pattern("users/20"))
  end

  def test_does_follow_with_user_and_id_requests_second_user
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_id("428004849")
    @cli.does_follow("20", "428004849")

    assert_requested(:get, v2_pattern("users/428004849"))
  end

  def test_does_follow_with_user_and_id_has_correct_output
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_id("428004849")
    @cli.does_follow("20", "428004849")

    assert_equal("Yes, @sferik follows @sferik.", $stdout.string.chomp)
  end

  def test_does_follow_yourself_raises_error
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_id("428004849")
    assert_raises(SystemExit) { @cli.does_follow("testcli") }
  end

  def test_does_follow_yourself_output_message
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_id("428004849")
    @cli.does_follow("testcli")
  rescue SystemExit
    assert_equal("No, you are not following yourself.", $stderr.string.chomp)
  end

  def test_does_follow_same_account_raises_error
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_id("428004849")
    assert_raises(SystemExit) { @cli.does_follow("sferik", "sferik") }
  end

  def test_does_follow_same_account_output_message
    does_follow_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("20")
    stub_v2_user_by_id("428004849")
    @cli.does_follow("sferik", "sferik")
  rescue SystemExit
    assert_equal("No, @sferik is not following themself.", $stderr.string.chomp)
  end

  def test_does_follow_false_raises_error
    does_follow_stubs
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/empty.json"))
    assert_raises(SystemExit) { @cli.does_follow("ev") }
  end

  def test_does_follow_false_requests_following
    does_follow_stubs
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/empty.json"))
    @cli.does_follow("ev")
  rescue SystemExit
    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  # favorite

  def test_favorite_requests_correct_resource
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_post("users/7505382/likes").to_return(v2_return("v2/post_response.json"))
    @cli.favorite("26755176471724032")

    assert_requested(:post, v2_pattern("users/7505382/likes"))
  end

  def test_favorite_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_post("users/7505382/likes").to_return(v2_return("v2/post_response.json"))
    @cli.favorite("26755176471724032")

    assert_match(/^@testcli favorited 1 tweet.$/, $stdout.string)
  end

  # favorites

  def favorites_stubs
    stub_v2_current_user
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
  end

  def test_favorites_requests_correct_resource
    favorites_stubs
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_has_the_correct_output
    favorites_stubs
    @cli.favorites

    assert_includes($stdout.string, "@mutgoff")
    assert_includes($stdout.string, "Happy Birthday @imdane")
    assert_includes($stdout.string, "@dwiskus")
  end

  def test_favorites_with_csv
    favorites_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.favorites

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
    assert_includes($stdout.string, "4611686018427387904")
  end

  def test_favorites_with_decode_uris_requests_resource
    favorites_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_decode_uris_decodes_urls
    favorites_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.favorites

    assert_includes($stdout.string, "https://twitter.com/sferik/status/243988000076337152")
  end

  def test_favorites_with_long
    favorites_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.favorites

    assert_includes($stdout.string, "4611686018427387904")
    assert_includes($stdout.string, "@mutgoff")
  end

  def test_favorites_with_long_and_reverse
    favorites_stubs
    @cli.options = @cli.options.merge("long" => true, "reverse" => true)
    @cli.favorites

    assert_includes($stdout.string, "244099460672679938")
    assert_includes($stdout.string, "@dwiskus")
  end

  def test_favorites_with_max_id
    favorites_stubs
    @cli.options = @cli.options.merge("max_id" => 244_104_558_433_951_744)
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_number_1
    favorites_stubs
    @cli.options = @cli.options.merge("number" => 1)
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_number_201
    favorites_stubs
    @cli.options = @cli.options.merge("number" => 201)
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"), at_least_times: 1)
  end

  def test_favorites_with_since_id
    favorites_stubs
    @cli.options = @cli.options.merge("since_id" => 244_104_558_433_951_744)
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_user_passed
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.favorites("sferik")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_user_and_id
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("id" => true)
    @cli.favorites("7505382")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_user_and_max_id
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("max_id" => 244_104_558_433_951_744)
    @cli.favorites("sferik")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_user_and_number_1
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("number" => 1)
    @cli.favorites("sferik")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_user_and_number_201
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("number" => 201)
    @cli.favorites("sferik")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"), at_least_times: 1)
  end

  def test_favorites_with_user_and_since_id
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("since_id" => 244_104_558_433_951_744)
    @cli.favorites("sferik")

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  # follow

  def follow_stubs
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_post("users/7505382/following").to_return(v2_return("v2/post_response.json"))
  end

  def test_follow_requests_current_user
    follow_stubs
    @cli.follow("sferik", "pengwynn")

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_follow_requests_following
    follow_stubs
    @cli.follow("sferik", "pengwynn")

    assert_requested(:post, v2_pattern("users/7505382/following"), at_least_times: 1)
  end

  def test_follow_has_the_correct_output
    follow_stubs
    @cli.follow("sferik", "pengwynn")

    assert_match(/^@testcli is now following 2 more users\.$/, $stdout.string)
  end

  def test_follow_with_id
    follow_stubs
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    stub_v2_user_by_id("14100886", "v2/pengwynn.json")
    @cli.follow("7505382", "14100886")

    assert_requested(:post, v2_pattern("users/7505382/following"), at_least_times: 1)
  end

  def test_follow_when_twitter_is_down
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_post("users/7505382/following").to_return(status: 502, body: '{"errors":[{"message":"Service Unavailable"}]}', headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @cli.follow("sferik", "pengwynn") }
  end

  # followings - helper for user-list commands

  def user_list_stubs(endpoint)
    stub_v2_current_user
    stub_v2_get("users/7505382/#{endpoint}").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
  end

  def assert_user_list_sort(method, option, expected, *)
    @cli.options = @cli.options.merge(option)
    @cli.send(method, *)

    assert_equal(expected, $stdout.string.chomp)
  end

  # followings

  def followings_stubs
    user_list_stubs("following")
  end

  def test_followings_looks_up_current_user
    followings_stubs
    @cli.followings

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_followings_requests_following_list
    followings_stubs
    @cli.followings

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_followings_looks_up_user_details
    followings_stubs
    @cli.followings

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_followings_has_the_correct_output
    followings_stubs
    @cli.followings

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_followings_with_csv
    followings_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.followings

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
    assert_includes($stdout.string, "pengwynn")
  end

  def test_followings_with_long
    followings_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.followings

    assert_includes($stdout.string, "14100886")
    assert_includes($stdout.string, "7505382")
  end

  def test_followings_with_reverse
    followings_stubs

    assert_user_list_sort(:followings, {"reverse" => true}, "sferik    pengwynn")
  end

  def test_followings_with_sort_favorites
    followings_stubs

    assert_user_list_sort(:followings, {"sort" => "favorites"}, "pengwynn  sferik")
  end

  def test_followings_with_sort_followers
    followings_stubs

    assert_user_list_sort(:followings, {"sort" => "followers"}, "sferik    pengwynn")
  end

  def test_followings_with_sort_friends
    followings_stubs

    assert_user_list_sort(:followings, {"sort" => "friends"}, "sferik    pengwynn")
  end

  def test_followings_with_sort_listed
    followings_stubs

    assert_user_list_sort(:followings, {"sort" => "listed"}, "sferik    pengwynn")
  end

  def test_followings_with_sort_since
    followings_stubs

    assert_user_list_sort(:followings, {"sort" => "since"}, "sferik    pengwynn")
  end

  def test_followings_with_sort_tweets
    followings_stubs

    assert_user_list_sort(:followings, {"sort" => "tweets"}, "pengwynn  sferik")
  end

  def test_followings_with_sort_tweeted
    followings_stubs

    assert_user_list_sort(:followings, {"sort" => "tweeted"}, "pengwynn  sferik")
  end

  def test_followings_with_unsorted
    followings_stubs

    assert_user_list_sort(:followings, {"unsorted" => true}, "pengwynn  sferik")
  end

  def test_followings_with_user_passed
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.followings("sferik")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_followings_with_user_passed_looks_up_users
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.followings("sferik")

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_followings_with_id
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.followings("7505382")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_followings_with_id_looks_up_users
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.followings("7505382")

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  # followings_following

  def followings_following_stubs
    stub_v2_user_by_name("sferik")
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
  end

  def test_followings_following_requests_following_list
    followings_following_stubs
    @cli.followings_following("sferik")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_followings_following_requests_followers_list
    followings_following_stubs
    @cli.followings_following("sferik")

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_followings_following_looks_up_user_details
    followings_following_stubs
    @cli.followings_following("sferik")

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_followings_following_has_the_correct_output
    followings_following_stubs
    @cli.followings_following("sferik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_followings_following_with_csv
    followings_following_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.followings_following("sferik")

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_followings_following_with_long
    followings_following_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.followings_following("sferik")

    assert_includes($stdout.string, "14100886")
  end

  def test_followings_following_with_reverse
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"reverse" => true}, "sferik    pengwynn", "sferik")
  end

  def test_followings_following_with_sort_favorites
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"sort" => "favorites"}, "pengwynn  sferik", "sferik")
  end

  def test_followings_following_with_sort_followers
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"sort" => "followers"}, "sferik    pengwynn", "sferik")
  end

  def test_followings_following_with_sort_friends
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"sort" => "friends"}, "sferik    pengwynn", "sferik")
  end

  def test_followings_following_with_sort_listed
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"sort" => "listed"}, "sferik    pengwynn", "sferik")
  end

  def test_followings_following_with_sort_since
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"sort" => "since"}, "sferik    pengwynn", "sferik")
  end

  def test_followings_following_with_sort_tweets
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"sort" => "tweets"}, "pengwynn  sferik", "sferik")
  end

  def test_followings_following_with_sort_tweeted
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"sort" => "tweeted"}, "pengwynn  sferik", "sferik")
  end

  def test_followings_following_with_unsorted
    followings_following_stubs

    assert_user_list_sort(:followings_following, {"unsorted" => true}, "pengwynn  sferik", "sferik")
  end

  def test_followings_following_with_two_users_requests_following
    followings_following_stubs
    stub_v2_get("users/14100886/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.followings_following("sferik", "pengwynn")

    assert_requested(:get, v2_pattern("users/14100886/following"))
  end

  def test_followings_following_with_two_users_requests_followers
    followings_following_stubs
    stub_v2_get("users/14100886/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.followings_following("sferik", "pengwynn")

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_followings_following_with_two_users_looks_up_details
    followings_following_stubs
    stub_v2_get("users/14100886/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.followings_following("sferik", "pengwynn")

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_followings_following_with_two_users_and_id
    followings_following_stubs
    stub_v2_get("users/14100886/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    @cli.followings_following("7505382", "14100886")

    assert_requested(:get, v2_pattern("users/14100886/following"))
  end

  # followers

  def followers_stubs
    user_list_stubs("followers")
  end

  def test_followers_looks_up_current_user
    followers_stubs
    @cli.followers

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_followers_requests_followers_list
    followers_stubs
    @cli.followers

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_followers_looks_up_user_details
    followers_stubs
    @cli.followers

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_followers_has_the_correct_output
    followers_stubs
    @cli.followers

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_followers_with_csv
    followers_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.followers

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_followers_with_long
    followers_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.followers

    assert_includes($stdout.string, "14100886")
  end

  def test_followers_with_reverse
    followers_stubs

    assert_user_list_sort(:followers, {"reverse" => true}, "sferik    pengwynn")
  end

  def test_followers_with_sort_favorites
    followers_stubs

    assert_user_list_sort(:followers, {"sort" => "favorites"}, "pengwynn  sferik")
  end

  def test_followers_with_sort_followers
    followers_stubs

    assert_user_list_sort(:followers, {"sort" => "followers"}, "sferik    pengwynn")
  end

  def test_followers_with_sort_friends
    followers_stubs

    assert_user_list_sort(:followers, {"sort" => "friends"}, "sferik    pengwynn")
  end

  def test_followers_with_sort_listed
    followers_stubs

    assert_user_list_sort(:followers, {"sort" => "listed"}, "sferik    pengwynn")
  end

  def test_followers_with_sort_since
    followers_stubs

    assert_user_list_sort(:followers, {"sort" => "since"}, "sferik    pengwynn")
  end

  def test_followers_with_sort_tweets
    followers_stubs

    assert_user_list_sort(:followers, {"sort" => "tweets"}, "pengwynn  sferik")
  end

  def test_followers_with_sort_tweeted
    followers_stubs

    assert_user_list_sort(:followers, {"sort" => "tweeted"}, "pengwynn  sferik")
  end

  def test_followers_with_unsorted
    followers_stubs

    assert_user_list_sort(:followers, {"unsorted" => true}, "pengwynn  sferik")
  end

  def test_followers_with_user_passed
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.followers("sferik")

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_followers_with_user_and_id
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.options = @cli.options.merge("id" => true)
    @cli.followers("7505382")

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  # friends

  def friends_stubs
    stub_v2_current_user
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
  end

  def test_friends_looks_up_current_user
    friends_stubs
    @cli.friends

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_friends_requests_following
    friends_stubs
    @cli.friends

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_friends_requests_followers
    friends_stubs
    @cli.friends

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_friends_looks_up_user_details
    friends_stubs
    @cli.friends

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_friends_has_the_correct_output
    friends_stubs
    @cli.friends

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_friends_with_csv
    friends_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.friends

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_friends_with_long
    friends_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.friends

    assert_includes($stdout.string, "14100886")
  end

  def test_friends_with_reverse
    friends_stubs

    assert_user_list_sort(:friends, {"reverse" => true}, "sferik    pengwynn")
  end

  def test_friends_with_sort_favorites
    friends_stubs

    assert_user_list_sort(:friends, {"sort" => "favorites"}, "pengwynn  sferik")
  end

  def test_friends_with_sort_followers
    friends_stubs

    assert_user_list_sort(:friends, {"sort" => "followers"}, "sferik    pengwynn")
  end

  def test_friends_with_sort_friends
    friends_stubs

    assert_user_list_sort(:friends, {"sort" => "friends"}, "sferik    pengwynn")
  end

  def test_friends_with_sort_listed
    friends_stubs

    assert_user_list_sort(:friends, {"sort" => "listed"}, "sferik    pengwynn")
  end

  def test_friends_with_sort_since
    friends_stubs

    assert_user_list_sort(:friends, {"sort" => "since"}, "sferik    pengwynn")
  end

  def test_friends_with_sort_tweets
    friends_stubs

    assert_user_list_sort(:friends, {"sort" => "tweets"}, "pengwynn  sferik")
  end

  def test_friends_with_sort_tweeted
    friends_stubs

    assert_user_list_sort(:friends, {"sort" => "tweeted"}, "pengwynn  sferik")
  end

  def test_friends_with_unsorted
    friends_stubs

    assert_user_list_sort(:friends, {"unsorted" => true}, "pengwynn  sferik")
  end

  def test_friends_with_user_passed_requests_following
    friends_stubs
    @cli.friends("sferik")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_friends_with_user_passed_requests_followers
    friends_stubs
    @cli.friends("sferik")

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_friends_with_user_passed_looks_up_details
    friends_stubs
    @cli.friends("sferik")

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_friends_with_user_and_id
    friends_stubs
    @cli.options = @cli.options.merge("id" => true)
    @cli.friends("7505382")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  # groupies

  def groupies_stubs
    stub_v2_current_user
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/follower_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
  end

  def test_groupies_looks_up_current_user
    groupies_stubs
    @cli.groupies

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_groupies_requests_followers
    groupies_stubs
    @cli.groupies

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_groupies_requests_following
    groupies_stubs
    @cli.groupies

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_groupies_looks_up_user_details
    groupies_stubs
    @cli.groupies

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_groupies_has_the_correct_output
    groupies_stubs
    @cli.groupies

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_groupies_with_csv
    groupies_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.groupies

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_groupies_with_long
    groupies_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.groupies

    assert_includes($stdout.string, "14100886")
  end

  def test_groupies_with_reverse
    groupies_stubs

    assert_user_list_sort(:groupies, {"reverse" => true}, "sferik    pengwynn")
  end

  def test_groupies_with_sort_favorites
    groupies_stubs

    assert_user_list_sort(:groupies, {"sort" => "favorites"}, "pengwynn  sferik")
  end

  def test_groupies_with_sort_followers
    groupies_stubs

    assert_user_list_sort(:groupies, {"sort" => "followers"}, "sferik    pengwynn")
  end

  def test_groupies_with_sort_friends
    groupies_stubs

    assert_user_list_sort(:groupies, {"sort" => "friends"}, "sferik    pengwynn")
  end

  def test_groupies_with_sort_listed
    groupies_stubs

    assert_user_list_sort(:groupies, {"sort" => "listed"}, "sferik    pengwynn")
  end

  def test_groupies_with_sort_since
    groupies_stubs

    assert_user_list_sort(:groupies, {"sort" => "since"}, "sferik    pengwynn")
  end

  def test_groupies_with_sort_tweets
    groupies_stubs

    assert_user_list_sort(:groupies, {"sort" => "tweets"}, "pengwynn  sferik")
  end

  def test_groupies_with_sort_tweeted
    groupies_stubs

    assert_user_list_sort(:groupies, {"sort" => "tweeted"}, "pengwynn  sferik")
  end

  def test_groupies_with_unsorted
    groupies_stubs

    assert_user_list_sort(:groupies, {"unsorted" => true}, "pengwynn  sferik")
  end

  def test_groupies_with_user_passed
    groupies_stubs
    @cli.groupies("sferik")

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_groupies_with_user_and_id
    groupies_stubs
    @cli.options = @cli.options.merge("id" => true)
    @cli.groupies("7505382")

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  # intersection

  def intersection_stubs
    @cli.options = @cli.options.merge("type" => "followings")
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json"))
    stub_v2_user_by_name("sferik")
    stub_v2_user_by_name("testcli")
  end

  def test_intersection_requests_following
    intersection_stubs
    @cli.intersection("sferik")

    assert_requested(:get, v2_pattern("users/7505382/following"), at_least_times: 1)
  end

  def test_intersection_looks_up_users
    intersection_stubs
    @cli.intersection("sferik")

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_intersection_has_the_correct_output
    intersection_stubs
    @cli.intersection("sferik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_intersection_with_csv
    intersection_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.intersection("sferik")

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_intersection_with_long
    intersection_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.intersection("sferik")

    assert_includes($stdout.string, "14100886")
  end

  def test_intersection_with_reverse
    intersection_stubs

    assert_user_list_sort(:intersection, {"reverse" => true, "type" => "followings"}, "sferik    pengwynn", "sferik")
  end

  def test_intersection_with_sort_favorites
    intersection_stubs

    assert_user_list_sort(:intersection, {"sort" => "favorites", "type" => "followings"}, "pengwynn  sferik", "sferik")
  end

  def test_intersection_with_sort_followers
    intersection_stubs

    assert_user_list_sort(:intersection, {"sort" => "followers", "type" => "followings"}, "sferik    pengwynn", "sferik")
  end

  def test_intersection_with_sort_friends
    intersection_stubs

    assert_user_list_sort(:intersection, {"sort" => "friends", "type" => "followings"}, "sferik    pengwynn", "sferik")
  end

  def test_intersection_with_sort_listed
    intersection_stubs

    assert_user_list_sort(:intersection, {"sort" => "listed", "type" => "followings"}, "sferik    pengwynn", "sferik")
  end

  def test_intersection_with_sort_since
    intersection_stubs

    assert_user_list_sort(:intersection, {"sort" => "since", "type" => "followings"}, "sferik    pengwynn", "sferik")
  end

  def test_intersection_with_sort_tweets
    intersection_stubs

    assert_user_list_sort(:intersection, {"sort" => "tweets", "type" => "followings"}, "pengwynn  sferik", "sferik")
  end

  def test_intersection_with_sort_tweeted
    intersection_stubs

    assert_user_list_sort(:intersection, {"sort" => "tweeted", "type" => "followings"}, "pengwynn  sferik", "sferik")
  end

  def test_intersection_with_type_followers
    intersection_stubs
    @cli.options = @cli.options.merge("type" => "followers")
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/follower_ids.json"))
    @cli.intersection("sferik")

    assert_requested(:get, v2_pattern("users/7505382/followers"), at_least_times: 1)
  end

  def test_intersection_with_type_followers_has_correct_output
    intersection_stubs
    @cli.options = @cli.options.merge("type" => "followers")
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/follower_ids.json"))
    @cli.intersection("sferik")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_intersection_with_unsorted
    intersection_stubs

    assert_user_list_sort(:intersection, {"unsorted" => true, "type" => "followings"}, "pengwynn  sferik", "sferik")
  end

  def test_intersection_with_two_users
    intersection_stubs
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_get("users/14100886/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.intersection("sferik", "pengwynn")

    assert_requested(:get, v2_pattern("users/14100886/following"))
  end

  def test_intersection_with_two_users_and_id
    intersection_stubs
    stub_v2_user_by_name("pengwynn", "v2/pengwynn.json")
    stub_v2_get("users/14100886/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    @cli.options = @cli.options.merge("id" => true)
    @cli.intersection("7505382", "14100886")

    assert_requested(:get, v2_pattern("users/14100886/following"))
  end

  # leaders

  def leaders_stubs
    stub_v2_current_user
    stub_v2_get("users/7505382/following").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
  end

  def test_leaders_looks_up_current_user
    leaders_stubs
    @cli.leaders

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_leaders_requests_following
    leaders_stubs
    @cli.leaders

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_leaders_requests_followers
    leaders_stubs
    @cli.leaders

    assert_requested(:get, v2_pattern("users/7505382/followers"))
  end

  def test_leaders_looks_up_user_details
    leaders_stubs
    @cli.leaders

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_leaders_has_the_correct_output
    leaders_stubs
    @cli.leaders

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_leaders_with_csv
    leaders_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.leaders

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_leaders_with_long
    leaders_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.leaders

    assert_includes($stdout.string, "14100886")
  end

  def test_leaders_with_reverse
    leaders_stubs

    assert_user_list_sort(:leaders, {"reverse" => true}, "sferik    pengwynn")
  end

  def test_leaders_with_sort_favorites
    leaders_stubs

    assert_user_list_sort(:leaders, {"sort" => "favorites"}, "pengwynn  sferik")
  end

  def test_leaders_with_sort_followers
    leaders_stubs

    assert_user_list_sort(:leaders, {"sort" => "followers"}, "sferik    pengwynn")
  end

  def test_leaders_with_sort_friends
    leaders_stubs

    assert_user_list_sort(:leaders, {"sort" => "friends"}, "sferik    pengwynn")
  end

  def test_leaders_with_sort_listed
    leaders_stubs

    assert_user_list_sort(:leaders, {"sort" => "listed"}, "sferik    pengwynn")
  end

  def test_leaders_with_sort_since
    leaders_stubs

    assert_user_list_sort(:leaders, {"sort" => "since"}, "sferik    pengwynn")
  end

  def test_leaders_with_sort_tweets
    leaders_stubs

    assert_user_list_sort(:leaders, {"sort" => "tweets"}, "pengwynn  sferik")
  end

  def test_leaders_with_sort_tweeted
    leaders_stubs

    assert_user_list_sort(:leaders, {"sort" => "tweeted"}, "pengwynn  sferik")
  end

  def test_leaders_with_unsorted
    leaders_stubs

    assert_user_list_sort(:leaders, {"unsorted" => true}, "pengwynn  sferik")
  end

  def test_leaders_with_user_passed
    leaders_stubs
    @cli.leaders("sferik")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  def test_leaders_with_user_and_id
    leaders_stubs
    @cli.options = @cli.options.merge("id" => true)
    @cli.leaders("7505382")

    assert_requested(:get, v2_pattern("users/7505382/following"))
  end

  # lists

  def lists_stubs
    stub_v2_current_user
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/lists.json"))
  end

  def test_lists_requests_correct_resource
    lists_stubs
    @cli.lists

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_lists_has_the_correct_output
    lists_stubs
    @cli.lists

    assert_equal("@pengwynn/rubyists  @twitter/team       @sferik/test", $stdout.string.chomp)
  end

  def test_lists_with_csv
    lists_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.lists

    assert_includes($stdout.string, "ID,Created at,Screen name,Slug")
  end

  def test_lists_with_long
    lists_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.lists

    assert_includes($stdout.string, "1129440")
    assert_includes($stdout.string, "@pengwynn")
  end

  def test_lists_with_reverse
    lists_stubs
    @cli.options = @cli.options.merge("reverse" => true)
    @cli.lists

    assert_equal("@sferik/test        @twitter/team       @pengwynn/rubyists", $stdout.string.chomp)
  end

  def test_lists_with_sort_members
    lists_stubs
    @cli.options = @cli.options.merge("sort" => "members")
    @cli.lists

    assert_equal("@sferik/test        @pengwynn/rubyists  @twitter/team", $stdout.string.chomp)
  end

  def test_lists_with_sort_mode
    lists_stubs
    @cli.options = @cli.options.merge("sort" => "mode")
    @cli.lists

    assert_equal("@twitter/team       @sferik/test        @pengwynn/rubyists", $stdout.string.chomp)
  end

  def test_lists_with_sort_since
    lists_stubs
    @cli.options = @cli.options.merge("sort" => "since")
    @cli.lists

    assert_equal("@twitter/team       @pengwynn/rubyists  @sferik/test", $stdout.string.chomp)
  end

  def test_lists_with_sort_subscribers
    lists_stubs
    @cli.options = @cli.options.merge("sort" => "subscribers")
    @cli.lists

    assert_equal("@sferik/test        @pengwynn/rubyists  @twitter/team", $stdout.string.chomp)
  end

  def test_lists_with_unsorted
    lists_stubs
    @cli.options = @cli.options.merge("unsorted" => true)
    @cli.lists

    assert_equal("@pengwynn/rubyists  @twitter/team       @sferik/test", $stdout.string.chomp)
  end

  def test_lists_with_user_passed
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/lists.json"))
    @cli.lists("sferik")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  def test_lists_with_user_and_id
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/lists.json"))
    @cli.options = @cli.options.merge("id" => true)
    @cli.lists("7505382")

    assert_requested(:get, v2_pattern("users/7505382/owned_lists"))
  end

  # matrix

  def test_matrix_streams_from_filtered_stream
    received_endpoint = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:stream) { |endpoint, &_block| received_endpoint = endpoint }
    @cli.stub(:install_matrix_stream_rules, []) do
      @cli.stub(:bearer_client, fake_client) do
        @cli.matrix
      end
    end

    assert_match(%r{tweets/search/stream}, received_endpoint)
  end

  def test_matrix_sets_up_stream_rules
    rules_set_up = false
    fake_client = Object.new
    fake_client.define_singleton_method(:stream) { |_endpoint, &_block| nil }
    @cli.stub(:install_matrix_stream_rules, -> { 
      rules_set_up = true
      []
    }) do
      @cli.stub(:bearer_client, fake_client) do
        @cli.matrix
      end
    end

    assert(rules_set_up, "expected install_matrix_stream_rules to be called")
  end

  def test_matrix_has_output
    tweet = {"data" => {"text" => "テストあいう", "id" => "1"}}
    fake_client = Object.new
    fake_client.define_singleton_method(:stream) { |_endpoint, &block| block.call(tweet) }
    @cli.shell = Thor::Shell::Basic.new
    @cli.stub(:install_matrix_stream_rules, []) do
      @cli.stub(:bearer_client, fake_client) do
        @cli.matrix
      end
    end

    refute_empty($stdout.string)
  end

  def test_matrix_skips_nil_tweets
    fake_client = Object.new
    fake_client.define_singleton_method(:stream) { |_endpoint, &block| block.call({}) }
    @cli.shell = Thor::Shell::Basic.new
    @cli.stub(:install_matrix_stream_rules, []) do
      @cli.stub(:bearer_client, fake_client) do
        @cli.matrix
      end
    end

    assert_empty($stdout.string)
  end

  def test_matrix_skips_tweets_without_hiragana
    tweet = {"data" => {"text" => "Hello world", "id" => "1"}}
    fake_client = Object.new
    fake_client.define_singleton_method(:stream) { |_endpoint, &block| block.call(tweet) }
    @cli.shell = Thor::Shell::Basic.new
    @cli.stub(:install_matrix_stream_rules, []) do
      @cli.stub(:bearer_client, fake_client) do
        @cli.matrix
      end
    end

    assert_empty($stdout.string)
  end

  def test_matrix_installs_and_removes_rules
    stub_v2_post("tweets/search/stream/rules").to_return(
      body: '{"data":[{"id":"42","value":"の lang:ja"}]}', headers: V2_JSON_HEADERS
    )
    fake_bearer = build_matrix_bearer_client
    @cli.stub(:bearer_client, fake_bearer) do
      @cli.matrix
    end

    assert_requested(:post, v2_pattern("tweets/search/stream/rules"), times: 2)
    assert_not_requested(:get, v2_pattern("tweets/search/stream/rules"))
  end

  def build_matrix_bearer_client
    bearer = X::Client.new(bearer_token: "test-token")
    bearer.define_singleton_method(:stream) { |_endpoint, &_block| nil }
    bearer
  end

  # mentions

  def mentions_stubs
    stub_v2_current_user
    stub_v2_get("users/7505382/mentions").to_return(v2_return("v2/statuses.json"))
  end

  def test_mentions_requests_correct_resource
    mentions_stubs
    @cli.mentions

    assert_requested(:get, v2_pattern("users/7505382/mentions"))
  end

  def test_mentions_has_the_correct_output
    mentions_stubs
    @cli.mentions

    assert_includes($stdout.string, "@mutgoff")
    assert_includes($stdout.string, "@dwiskus")
  end

  def test_mentions_with_csv
    mentions_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.mentions

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
  end

  def test_mentions_with_decode_uris_requests_resource
    mentions_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.mentions

    assert_requested(:get, v2_pattern("users/7505382/mentions"))
  end

  def test_mentions_with_decode_uris_decodes_urls
    mentions_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.mentions

    assert_includes($stdout.string, "https://twitter.com/sferik/status/243988000076337152")
  end

  def test_mentions_with_long
    mentions_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.mentions

    assert_includes($stdout.string, "4611686018427387904")
  end

  def test_mentions_with_long_and_reverse
    mentions_stubs
    @cli.options = @cli.options.merge("long" => true, "reverse" => true)
    @cli.mentions

    assert_includes($stdout.string, "244099460672679938")
  end

  def test_mentions_with_number_1
    mentions_stubs
    @cli.options = @cli.options.merge("number" => 1)
    @cli.mentions

    assert_requested(:get, v2_pattern("users/7505382/mentions"))
  end

  def test_mentions_with_number_201
    mentions_stubs
    @cli.options = @cli.options.merge("number" => 201)
    @cli.mentions

    assert_requested(:get, v2_pattern("users/7505382/mentions"), at_least_times: 1)
  end

  # mute

  def test_mute_requests_correct_resource
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_post("users/7505382/muting").to_return(v2_return("v2/post_response.json"))
    @cli.mute("sferik")

    assert_requested(:post, v2_pattern("users/7505382/muting"))
  end

  def test_mute_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_post("users/7505382/muting").to_return(v2_return("v2/post_response.json"))
    @cli.mute("sferik")

    assert_match(/^@testcli muted 1 user/, $stdout.string)
  end

  def test_mute_with_id
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc", "id" => true)
    stub_v2_current_user
    stub_v2_user_by_id("7505382")
    stub_v2_post("users/7505382/muting").to_return(v2_return("v2/post_response.json"))
    @cli.mute("7505382")

    assert_requested(:post, v2_pattern("users/7505382/muting"))
  end

  # muted

  def test_muted_requests_correct_resource
    stub_v2_current_user
    stub_v2_get("users/7505382/muting").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.muted

    assert_requested(:get, v2_pattern("users/7505382/muting"))
  end

  def test_muted_has_output
    stub_v2_current_user
    stub_v2_get("users/7505382/muting").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.muted

    refute_empty($stdout.string.chomp)
  end

  # open

  def test_open_does_not_raise_error
    @cli.options = @cli.options.merge("display-uri" => true)
    @cli.open("sferik")
  end

  def test_open_with_id
    @cli.options = @cli.options.merge("display-uri" => true, "id" => true)
    stub_v2_user_by_id("420")
    @cli.open("420")

    assert_requested(:get, v2_pattern("users/420"))
  end

  def test_open_with_status_requests_resource
    @cli.options = @cli.options.merge("display-uri" => true, "status" => true)
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    @cli.open("55709764298092545")

    assert_requested(:get, v2_pattern("tweets/55709764298092545"))
  end

  def test_open_with_status_does_not_raise_error
    @cli.options = @cli.options.merge("display-uri" => true, "status" => true)
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    @cli.open("55709764298092545")
  end

  # reach

  def reach_stubs
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    stub_v2_get("tweets/55709764298092545/retweeted_by").to_return(v2_return("v2/following_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/7505382/followers").to_return(v2_return("v2/follower_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/20009713/followers").to_return(v2_return("v2/follower_ids.json")).then.to_return(v2_return("v2/empty.json"))
    stub_v2_get("users/14100886/followers").to_return(v2_return("v2/follower_ids.json")).then.to_return(v2_return("v2/empty.json"))
  end

  def test_reach_requests_tweet
    reach_stubs
    @cli.reach("55709764298092545")

    assert_requested(:get, v2_pattern("tweets/55709764298092545"), at_least_times: 1)
  end

  def test_reach_requests_retweeters
    reach_stubs
    @cli.reach("55709764298092545")

    assert_requested(:get, v2_pattern("tweets/55709764298092545/retweeted_by"))
  end

  def test_reach_requests_followers
    reach_stubs
    @cli.reach("55709764298092545")

    assert_requested(:get, v2_pattern("users/7505382/followers"), at_least_times: 1)
  end

  def test_reach_requests_other_followers
    reach_stubs
    @cli.reach("55709764298092545")

    assert_requested(:get, v2_pattern("users/14100886/followers"))
  end

  def test_reach_has_the_correct_output
    reach_stubs
    @cli.reach("55709764298092545")

    assert_equal("2", $stdout.string.split("\n").first)
  end

  # reply

  def reply_stubs
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc", "location" => nil)
    stub_v2_current_user
    stub_v2_get("tweets/263813522369159169").to_return(v2_return("v2/status_with_mention.json"))
    stub_v2_post("tweets").to_return(v2_return("v2/post_response.json"))
    stub_request(:get, "http://checkip.dyndns.org/").to_return(body: fixture("checkip.html"), headers: {content_type: "text/html"})
    stub_request(:get, "http://www.geoplugin.net/xml.gp?ip=50.131.22.169").to_return(body: fixture("geoplugin.xml"), headers: {content_type: "application/xml"})
  end

  def test_reply_fetches_tweet
    reply_stubs
    @cli.reply("263813522369159169", "Testing")

    assert_requested(:get, v2_pattern("tweets/263813522369159169"))
  end

  def test_reply_posts_reply
    reply_stubs
    @cli.reply("263813522369159169", "Testing")

    assert_requested(:post, v2_pattern("tweets"))
  end

  def test_reply_does_not_look_up_location_checkip
    reply_stubs
    @cli.reply("263813522369159169", "Testing")

    assert_not_requested(:get, "http://checkip.dyndns.org/")
  end

  def test_reply_does_not_look_up_location_geoplugin
    reply_stubs
    @cli.reply("263813522369159169", "Testing")

    assert_not_requested(:get, "http://www.geoplugin.net/xml.gp?ip=50.131.22.169")
  end

  def test_reply_has_the_correct_output
    reply_stubs
    @cli.reply("263813522369159169", "Testing")

    assert_equal("Reply posted by @testcli to @joshfrench.", $stdout.string.split("\n").first)
  end

  def test_reply_with_all
    reply_stubs
    @cli.options = @cli.options.merge("all" => true)
    @cli.reply("263813522369159169", "Testing")

    assert_equal("Reply posted by @testcli to @joshfrench @sferik.", $stdout.string.split("\n").first)
  end

  def test_reply_with_file_uploads_media
    reply_stubs
    @cli.options = @cli.options.merge("file" => "#{fixture_path}/long.png")
    stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json").to_return(body: fixture("upload.json"), headers: {content_type: "application/json; charset=utf-8"})
    @cli.reply("263813522369159169", "Testing")

    assert_requested(:post, "https://upload.twitter.com/1.1/media/upload.json")
  end

  def test_reply_with_file_posts_tweet
    reply_stubs
    @cli.options = @cli.options.merge("file" => "#{fixture_path}/long.png")
    stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json").to_return(body: fixture("upload.json"), headers: {content_type: "application/json; charset=utf-8"})
    @cli.reply("263813522369159169", "Testing")

    assert_requested(:post, v2_pattern("tweets"))
  end

  def test_reply_with_location_looks_up_ip
    reply_stubs
    @cli.options = @cli.options.merge("location" => "location")
    @cli.reply("263813522369159169", "Testing")

    assert_requested(:get, "http://checkip.dyndns.org/")
  end

  def test_reply_with_location_looks_up_geoplugin
    reply_stubs
    @cli.options = @cli.options.merge("location" => "location")
    @cli.reply("263813522369159169", "Testing")

    assert_requested(:get, "http://www.geoplugin.net/xml.gp?ip=50.131.22.169")
  end

  def test_reply_with_location_coordinates_does_not_look_up_ip
    reply_stubs
    @cli.options = @cli.options.merge("location" => "41.03132,28.9869")
    @cli.reply("263813522369159169", "Testing")

    assert_not_requested(:get, "http://checkip.dyndns.org/")
  end

  def test_reply_with_no_status_opens_editor
    reply_stubs
    T::Editor.stub(:gets, "Testing") do
      @cli.reply("263813522369159169")

      assert_requested(:post, v2_pattern("tweets"))
    end
  end

  # report_spam

  def test_report_spam_requests_correct_resource
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/users/report_spam.json").with(body: {screen_name: "sferik"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @cli.report_spam("sferik")

    assert_requested(:post, "https://api.twitter.com/1.1/users/report_spam.json", body: {screen_name: "sferik"})
  end

  def test_report_spam_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/users/report_spam.json").with(body: {screen_name: "sferik"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @cli.report_spam("sferik")

    assert_match(/^@testcli reported 1 user/, $stdout.string)
  end

  def test_report_spam_with_id
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc", "id" => true)
    stub_v2_user_by_id("7505382")
    stub_post("/1.1/users/report_spam.json").with(body: {user_id: "7505382"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @cli.report_spam("7505382")

    assert_requested(:post, "https://api.twitter.com/1.1/users/report_spam.json", body: {user_id: "7505382"})
  end

  # retweet

  def test_retweet_requests_correct_resource
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_post("users/7505382/retweets").to_return(v2_return("v2/post_response.json"))
    @cli.retweet("26755176471724032")

    assert_requested(:post, v2_pattern("users/7505382/retweets"))
  end

  def test_retweet_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_post("users/7505382/retweets").to_return(v2_return("v2/post_response.json"))
    @cli.retweet("26755176471724032")

    assert_match(/^@testcli retweeted 1 tweet.$/, $stdout.string)
  end

  # retweets

  def retweets_stubs
    stub_v2_current_user
    stub_v2_get("users/reposts_of_me").to_return(v2_return("v2/statuses.json"))
  end

  def test_retweets_requests_correct_resource
    retweets_stubs
    @cli.retweets

    assert_requested(:get, v2_pattern("users/reposts_of_me"))
  end

  def test_retweets_has_the_correct_output
    retweets_stubs
    @cli.retweets

    assert_includes($stdout.string, "@mutgoff")
    assert_includes($stdout.string, "@dwiskus")
  end

  def test_retweets_with_csv
    retweets_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.retweets

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
  end

  def test_retweets_with_decode_uris
    retweets_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.retweets

    assert_requested(:get, v2_pattern("users/reposts_of_me"))
  end

  def test_retweets_with_long
    retweets_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.retweets

    assert_includes($stdout.string, "4611686018427387904")
  end

  def test_retweets_with_long_and_reverse
    retweets_stubs
    @cli.options = @cli.options.merge("long" => true, "reverse" => true)
    @cli.retweets

    assert_includes($stdout.string, "244099460672679938")
  end

  def test_retweets_with_number_1
    retweets_stubs
    @cli.options = @cli.options.merge("number" => 1)
    @cli.retweets

    assert_requested(:get, v2_pattern("users/reposts_of_me"))
  end

  def test_retweets_with_number_201
    retweets_stubs
    @cli.options = @cli.options.merge("number" => 201)
    @cli.retweets

    assert_requested(:get, v2_pattern("users/reposts_of_me"), at_least_times: 1)
  end

  def test_retweets_with_user_passed
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.retweets("sferik")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_retweets_with_user_and_id
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    @cli.retweets("7505382")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  # retweets_of_me

  def retweets_of_me_stubs
    stub_v2_get("users/reposts_of_me").to_return(v2_return("v2/statuses.json"))
  end

  def test_retweets_of_me_requests_correct_resource
    retweets_of_me_stubs
    @cli.retweets_of_me

    assert_requested(:get, v2_pattern("users/reposts_of_me"))
  end

  def test_retweets_of_me_has_the_correct_output
    retweets_of_me_stubs
    @cli.retweets_of_me

    assert_includes($stdout.string, "@mutgoff")
    assert_includes($stdout.string, "@dwiskus")
  end

  def test_retweets_of_me_with_csv
    retweets_of_me_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.retweets_of_me

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
  end

  def test_retweets_of_me_with_decode_uris
    retweets_of_me_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.retweets_of_me

    assert_requested(:get, v2_pattern("users/reposts_of_me"))
  end

  def test_retweets_of_me_with_long
    retweets_of_me_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.retweets_of_me

    assert_includes($stdout.string, "4611686018427387904")
  end

  def test_retweets_of_me_with_long_and_reverse
    retweets_of_me_stubs
    @cli.options = @cli.options.merge("long" => true, "reverse" => true)
    @cli.retweets_of_me

    assert_includes($stdout.string, "244099460672679938")
  end

  def test_retweets_of_me_with_number_1
    retweets_of_me_stubs
    @cli.options = @cli.options.merge("number" => 1)
    @cli.retweets_of_me

    assert_requested(:get, v2_pattern("users/reposts_of_me"))
  end

  def test_retweets_of_me_with_number_201
    retweets_of_me_stubs
    @cli.options = @cli.options.merge("number" => 201)
    @cli.retweets_of_me

    assert_requested(:get, v2_pattern("users/reposts_of_me"), at_least_times: 1)
  end

  # ruler

  def test_ruler_outputs_single_line
    @cli.ruler
    lines = $stdout.string.lines.map(&:chomp)

    assert_equal(1, lines.size)
  end

  def test_ruler_line_length
    @cli.ruler
    lines = $stdout.string.lines.map(&:chomp)

    assert_equal(280, lines[0].length)
  end

  def test_ruler_labels_at_every_20_chars
    @cli.ruler
    ruler = $stdout.string.lines.first.chomp
    (20..280).step(20) do |marker|
      label = marker.to_s
      start = marker - label.length - 1

      assert_equal(label, ruler[start, label.length])
    end
  end

  def test_ruler_pipe_markers_at_every_20_chars
    @cli.ruler
    ruler = $stdout.string.lines.first.chomp

    (20..280).step(20) do |marker|
      assert_equal("|", ruler[marker - 1])
    end
  end

  def test_ruler_with_indentation_outputs_single_line
    @cli.options = @cli.options.merge("indent" => 2)
    @cli.ruler

    assert_equal(1, $stdout.string.lines.map(&:chomp).size)
  end

  def test_ruler_with_indentation_starts_with_spaces
    @cli.options = @cli.options.merge("indent" => 2)
    @cli.ruler

    assert($stdout.string.lines.first.chomp.start_with?("  "))
  end

  def test_ruler_with_indentation_correct_length
    @cli.options = @cli.options.merge("indent" => 2)
    @cli.ruler
    ruler = $stdout.string.lines.first.chomp.delete_prefix("  ")

    assert_equal(280, ruler.length)
  end

  def test_ruler_with_indentation_labels
    @cli.options = @cli.options.merge("indent" => 2)
    @cli.ruler
    ruler = $stdout.string.lines.first.chomp.delete_prefix("  ")
    (20..280).step(20) do |marker|
      label = marker.to_s

      assert_equal(label, ruler[marker - label.length - 1, label.length])
    end
  end

  def test_ruler_with_indentation_pipe_markers
    @cli.options = @cli.options.merge("indent" => 2)
    @cli.ruler
    ruler = $stdout.string.lines.first.chomp.delete_prefix("  ")

    (20..280).step(20) do |marker|
      assert_equal("|", ruler[marker - 1])
    end
  end

  # status

  def status_stubs
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
  end

  def test_status_requests_correct_resource
    status_stubs
    @cli.status("55709764298092545")

    assert_requested(:get, v2_pattern("tweets/55709764298092545"))
  end

  def test_status_has_the_correct_output
    status_stubs
    @cli.status("55709764298092545")
    expected_output = <<~EOS
      ID           55709764298092545
      Text         The problem with your code is that it's doing exactly what you told it to do.
      Screen name  @sferik
      Posted at    Apr  6  2011 (8 months ago)
      Retweets     320
      Favorites    50
      Source       Twitter for iPhone
      Location     Blowfish Sushi To Die For, 2170 Bryant St, San Francisco, California, United States
    EOS
    assert_equal(expected_output, $stdout.string)
  end

  def test_status_with_csv
    status_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
    assert_includes($stdout.string, "55709764298092545")
  end

  def test_status_with_no_street_address
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_street_address.json"))
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "Blowfish Sushi To Die For, San Francisco, California, United States")
  end

  def test_status_with_no_locality
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_locality.json"))
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "Blowfish Sushi To Die For, San Francisco, California, United States")
  end

  def test_status_with_no_attributes
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_attributes.json"))
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "Blowfish Sushi To Die For, San Francisco, United States")
  end

  def test_status_with_no_country
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_country.json"))
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "Blowfish Sushi To Die For, San Francisco")
  end

  def test_status_with_no_full_name
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_full_name.json"))
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "Blowfish Sushi To Die For")
  end

  def test_status_with_no_place
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_place.json"))
    stub_request(:get, "https://maps.google.com/maps/api/geocode/json").with(query: {latlng: "37.75963095,-122.410067", sensor: "false"}).to_return(body: fixture("geo.json"), headers: {content_type: "application/json; charset=UTF-8"})
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "San Francisco, CA, United States")
  end

  def test_status_with_no_place_and_no_city
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_place.json"))
    stub_request(:get, "https://maps.google.com/maps/api/geocode/json").with(query: {latlng: "37.75963095,-122.410067", sensor: "false"}).to_return(body: fixture("geo_no_city.json"), headers: {content_type: "application/json; charset=UTF-8"})
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "CA, United States")
  end

  def test_status_with_no_place_and_no_state
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_place.json"))
    stub_request(:get, "https://maps.google.com/maps/api/geocode/json").with(query: {latlng: "37.75963095,-122.410067", sensor: "false"}).to_return(body: fixture("geo_no_state.json"), headers: {content_type: "application/json; charset=UTF-8"})
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "United States")
  end

  def test_status_with_long
    status_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "55709764298092545")
    assert_includes($stdout.string, "@sferik")
  end

  def test_status_with_relative_dates
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    stub_v2_user_by_name("sferik")
    @cli.options = @cli.options.merge("relative_dates" => true)
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "8 months ago")
  end

  def test_status_with_relative_dates_whois
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    stub_v2_user_by_name("sferik")
    @cli.options = @cli.options.merge("relative_dates" => true)
    @cli.whois("sferik")

    assert_includes($stdout.string, "4 years ago")
  end

  def test_status_with_relative_dates_and_csv
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    stub_v2_user_by_name("sferik")
    @cli.options = @cli.options.merge("relative_dates" => true, "csv" => true)
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "2011-04-06 19:13:37 +0000")
  end

  def test_status_with_relative_dates_and_long
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status.json"))
    stub_v2_user_by_name("sferik")
    @cli.options = @cli.options.merge("relative_dates" => true, "long" => true)
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "8 months ago")
  end

  # timeline

  def timeline_stubs
    stub_v2_current_user
    stub_v2_get("users/7505382/timelines/reverse_chronological").to_return(v2_return("v2/statuses.json"))
  end

  def test_timeline_requests_correct_resource
    timeline_stubs
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"))
  end

  def test_timeline_has_the_correct_output
    timeline_stubs
    @cli.timeline

    assert_includes($stdout.string, "@mutgoff")
    assert_includes($stdout.string, "@dwiskus")
  end

  def test_timeline_with_csv
    timeline_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.timeline

    assert_includes($stdout.string, "ID,Posted at,Screen name,Text")
  end

  def test_timeline_with_decode_uris_requests_resource
    timeline_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"))
  end

  def test_timeline_with_decode_uris_decodes_urls
    timeline_stubs
    @cli.options = @cli.options.merge("decode_uris" => true)
    @cli.timeline

    assert_includes($stdout.string, "https://twitter.com/sferik/status/243988000076337152")
  end

  def test_timeline_with_exclude_replies
    timeline_stubs
    @cli.options = @cli.options.merge("exclude" => "replies")
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"))
  end

  def test_timeline_with_exclude_retweets
    timeline_stubs
    @cli.options = @cli.options.merge("exclude" => "retweets")
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"))
  end

  def test_timeline_with_long
    timeline_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.timeline

    assert_includes($stdout.string, "4611686018427387904")
  end

  def test_timeline_with_long_and_reverse
    timeline_stubs
    @cli.options = @cli.options.merge("long" => true, "reverse" => true)
    @cli.timeline

    assert_includes($stdout.string, "244099460672679938")
  end

  def test_timeline_with_max_id
    timeline_stubs
    @cli.options = @cli.options.merge("max_id" => 244_104_558_433_951_744)
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"))
  end

  def test_timeline_with_number_1
    timeline_stubs
    @cli.options = @cli.options.merge("number" => 1)
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"))
  end

  def test_timeline_with_number_201
    timeline_stubs
    @cli.options = @cli.options.merge("number" => 201)
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"), at_least_times: 1)
  end

  def test_timeline_with_since_id
    timeline_stubs
    @cli.options = @cli.options.merge("since_id" => 244_104_558_433_951_744)
    @cli.timeline

    assert_requested(:get, v2_pattern("users/7505382/timelines/reverse_chronological"))
  end

  def test_timeline_with_user_passed
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.timeline("sferik")

    assert_requested(:get, v2_pattern("users/7505382/tweets"))
  end

  def test_timeline_with_user_and_id
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.timeline("7505382")

    assert_requested(:get, v2_pattern("users/7505382/tweets"))
  end

  def test_timeline_with_user_and_max_id
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("max_id" => 244_104_558_433_951_744)
    @cli.timeline("sferik")

    assert_requested(:get, v2_pattern("users/7505382/tweets"))
  end

  def test_timeline_with_user_and_number_1
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("number" => 1)
    @cli.timeline("sferik")

    assert_requested(:get, v2_pattern("users/7505382/tweets"))
  end

  def test_timeline_with_user_and_number_201
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("number" => 201)
    @cli.timeline("sferik")

    assert_requested(:get, v2_pattern("users/7505382/tweets"), at_least_times: 1)
  end

  def test_timeline_with_user_and_since_id
    stub_v2_user_by_name("sferik")
    stub_v2_get("users/7505382/tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("since_id" => 244_104_558_433_951_744)
    @cli.timeline("sferik")

    assert_requested(:get, v2_pattern("users/7505382/tweets"))
  end

  # trends

  def trends_stubs
    stub_v2_get("trends/by/woeid/1").to_return(v2_return("v2/trends.json"))
  end

  def test_trends_requests_correct_resource
    trends_stubs
    @cli.trends

    assert_requested(:get, v2_pattern("trends/by/woeid/1"))
  end

  def test_trends_has_the_correct_output
    trends_stubs
    @cli.trends

    assert_equal("#sevenwordsaftersex  Walkman              Allen Iverson", $stdout.string.chomp)
  end

  def test_trends_with_exclude_hashtags_requests_resource
    @cli.options = @cli.options.merge("exclude-hashtags" => true)
    stub_v2_get("trends/by/woeid/1").to_return(v2_return("v2/trends.json"))
    @cli.trends

    assert_requested(:get, v2_pattern("trends/by/woeid/1"))
  end

  def test_trends_with_exclude_hashtags_has_correct_output
    @cli.options = @cli.options.merge("exclude-hashtags" => true)
    stub_v2_get("trends/by/woeid/1").to_return(v2_return("v2/trends.json"))
    @cli.trends

    assert_equal("Walkman        Allen Iverson", $stdout.string.chomp)
  end

  def test_trends_with_woeid
    stub_v2_get("trends/by/woeid/2487956").to_return(v2_return("v2/trends.json"))
    @cli.trends("2487956")

    assert_requested(:get, v2_pattern("trends/by/woeid/2487956"))
  end

  def test_trends_with_woeid_has_correct_output
    stub_v2_get("trends/by/woeid/2487956").to_return(v2_return("v2/trends.json"))
    @cli.trends("2487956")

    assert_equal("#sevenwordsaftersex  Walkman              Allen Iverson", $stdout.string.chomp)
  end

  # trend_locations

  def trend_locations_stubs
    stub_get("/1.1/trends/available.json").to_return(body: fixture("locations.json"), headers: {content_type: "application/json; charset=utf-8"})
  end

  def test_trend_locations_requests_correct_resource
    trend_locations_stubs
    @cli.trend_locations

    assert_requested(:get, "https://api.twitter.com/1.1/trends/available.json")
  end

  def test_trend_locations_has_the_correct_output
    trend_locations_stubs
    @cli.trend_locations

    assert_equal("San Francisco  Soweto         United States  Worldwide", $stdout.string.chomp)
  end

  def test_trend_locations_with_csv
    trend_locations_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.trend_locations

    assert_includes($stdout.string, "WOEID,Parent ID,Type,Name,Country")
    assert_includes($stdout.string, "2487956")
  end

  def test_trend_locations_with_long
    trend_locations_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.trend_locations

    assert_includes($stdout.string, "2487956")
    assert_includes($stdout.string, "San Francisco")
  end

  def test_trend_locations_with_reverse
    trend_locations_stubs
    @cli.options = @cli.options.merge("reverse" => true)
    @cli.trend_locations

    assert_equal("Worldwide      United States  Soweto         San Francisco", $stdout.string.chomp)
  end

  def test_trend_locations_with_sort_country
    trend_locations_stubs
    @cli.options = @cli.options.merge("sort" => "country")
    @cli.trend_locations

    assert_equal("Worldwide      Soweto         San Francisco  United States", $stdout.string.chomp)
  end

  def test_trend_locations_with_sort_parent
    trend_locations_stubs
    @cli.options = @cli.options.merge("sort" => "parent")
    @cli.trend_locations

    assert_equal("Worldwide      United States  Soweto         San Francisco", $stdout.string.chomp)
  end

  def test_trend_locations_with_sort_type
    trend_locations_stubs
    @cli.options = @cli.options.merge("sort" => "type")
    @cli.trend_locations

    assert_equal("United States  Worldwide      San Francisco  Soweto", $stdout.string.chomp)
  end

  def test_trend_locations_with_sort_woeid
    trend_locations_stubs
    @cli.options = @cli.options.merge("sort" => "woeid")
    @cli.trend_locations

    assert_equal("Worldwide      Soweto         San Francisco  United States", $stdout.string.chomp)
  end

  def test_trend_locations_with_unsorted
    trend_locations_stubs
    @cli.options = @cli.options.merge("unsorted" => true)
    @cli.trend_locations

    assert_equal("Worldwide      San Francisco  United States  Soweto", $stdout.string.chomp)
  end

  # unfollow

  def test_unfollow_requests_correct_resource
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/following/7505382").to_return(v2_return("v2/post_response.json"))
    @cli.unfollow("sferik")

    assert_requested(:delete, v2_pattern("users/7505382/following/7505382"))
  end

  def test_unfollow_has_the_correct_output
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/following/7505382").to_return(v2_return("v2/post_response.json"))
    @cli.unfollow("sferik")

    assert_match(/^@testcli is no longer following 1 user\.$/, $stdout.string)
  end

  def test_unfollow_with_id
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc", "id" => true)
    stub_v2_current_user
    stub_v2_user_by_id("7505382")
    stub_v2_delete("users/7505382/following/7505382").to_return(v2_return("v2/post_response.json"))
    @cli.unfollow("7505382")

    assert_requested(:delete, v2_pattern("users/7505382/following/7505382"))
  end

  def test_unfollow_when_twitter_is_down_raises_error
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/following/7505382").to_return(status: 502, body: '{"errors":[{"message":"Bad Gateway"}]}', headers: V2_JSON_HEADERS)
    assert_raises(X::BadGateway) { @cli.unfollow("sferik") }
  end

  def test_unfollow_when_twitter_is_down_retries
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/following/7505382").to_return(status: 502, body: '{"errors":[{"message":"Bad Gateway"}]}', headers: V2_JSON_HEADERS)
    begin
      @cli.unfollow("sferik")
    rescue X::BadGateway # rubocop:disable Lint/SuppressedException
    end

    assert_requested(:delete, v2_pattern("users/7505382/following/7505382"), times: 3)
  end

  # update

  def update_stubs
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_post("tweets").to_return(v2_return("v2/post_response.json"))
    stub_request(:get, "http://checkip.dyndns.org/").to_return(body: fixture("checkip.html"), headers: {content_type: "text/html"})
    stub_request(:get, "http://www.geoplugin.net/xml.gp?ip=50.131.22.169").to_return(body: fixture("geoplugin.xml"), headers: {content_type: "application/xml"})
  end

  def test_update_posts_tweet
    update_stubs
    @cli.update("Testing")

    assert_requested(:post, v2_pattern("tweets"))
  end

  def test_update_does_not_look_up_location_checkip
    update_stubs
    @cli.update("Testing")

    assert_not_requested(:get, "http://checkip.dyndns.org/")
  end

  def test_update_does_not_look_up_location_geoplugin
    update_stubs
    @cli.update("Testing")

    assert_not_requested(:get, "http://www.geoplugin.net/xml.gp?ip=50.131.22.169")
  end

  def test_update_has_the_correct_output
    update_stubs
    @cli.update("Testing")

    assert_equal("Tweet posted by @testcli.", $stdout.string.split("\n").first)
  end

  def test_update_with_file_uploads_media
    update_stubs
    @cli.options = @cli.options.merge("file" => "#{fixture_path}/long.png")
    stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json").to_return(body: fixture("upload.json"), headers: {content_type: "application/json; charset=utf-8"})
    @cli.update("Testing")

    assert_requested(:post, "https://upload.twitter.com/1.1/media/upload.json")
  end

  def test_update_with_file_posts_tweet
    update_stubs
    @cli.options = @cli.options.merge("file" => "#{fixture_path}/long.png")
    stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json").to_return(body: fixture("upload.json"), headers: {content_type: "application/json; charset=utf-8"})
    @cli.update("Testing")

    assert_requested(:post, v2_pattern("tweets"))
  end

  def test_update_with_location_looks_up_ip
    update_stubs
    @cli.options = @cli.options.merge("location" => "location")
    @cli.update("Testing")

    assert_requested(:get, "http://checkip.dyndns.org/")
  end

  def test_update_with_location_looks_up_geoplugin
    update_stubs
    @cli.options = @cli.options.merge("location" => "location")
    @cli.update("Testing")

    assert_requested(:get, "http://www.geoplugin.net/xml.gp?ip=50.131.22.169")
  end

  def test_update_with_location_has_correct_output
    update_stubs
    @cli.options = @cli.options.merge("location" => "location")
    @cli.update("Testing")

    assert_equal("Tweet posted by @testcli.", $stdout.string.split("\n").first)
  end

  def test_update_with_location_coordinates_posts_tweet
    update_stubs
    @cli.options = @cli.options.merge("location" => "41.03132,28.9869")
    @cli.update("Testing")

    assert_requested(:post, v2_pattern("tweets"))
  end

  def test_update_with_location_coordinates_does_not_look_up_ip
    update_stubs
    @cli.options = @cli.options.merge("location" => "41.03132,28.9869")
    @cli.update("Testing")

    assert_not_requested(:get, "http://checkip.dyndns.org/")
  end

  def test_update_with_no_status_opens_editor
    update_stubs
    T::Editor.stub(:gets, "Testing") do
      @cli.update

      assert_requested(:post, v2_pattern("tweets"))
    end
  end

  # users

  def users_stubs
    stub_v2_get("users/by").to_return(v2_return("v2/users_list.json"))
  end

  def test_users_requests_correct_resource
    users_stubs
    @cli.users("sferik", "pengwynn")

    assert_requested(:get, v2_pattern("users/by"))
  end

  def test_users_has_the_correct_output
    users_stubs
    @cli.users("sferik", "pengwynn")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_csv
    users_stubs
    @cli.options = @cli.options.merge("csv" => true)
    @cli.users("sferik", "pengwynn")

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_users_with_long
    users_stubs
    @cli.options = @cli.options.merge("long" => true)
    @cli.users("sferik", "pengwynn")

    assert_includes($stdout.string, "14100886")
  end

  def test_users_with_reverse
    users_stubs
    @cli.options = @cli.options.merge("reverse" => true)
    @cli.users("sferik", "pengwynn")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_favorites
    users_stubs
    @cli.options = @cli.options.merge("sort" => "favorites")
    @cli.users("sferik", "pengwynn")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_sort_followers
    users_stubs
    @cli.options = @cli.options.merge("sort" => "followers")
    @cli.users("sferik", "pengwynn")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_friends
    users_stubs
    @cli.options = @cli.options.merge("sort" => "friends")
    @cli.users("sferik", "pengwynn")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_id
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_users_lookup.to_return(v2_return("v2/users_list.json"))
    @cli.users("7505382", "14100886")

    assert_requested(:get, v2_pattern("users"), at_least_times: 1)
  end

  def test_users_with_sort_listed
    users_stubs
    @cli.options = @cli.options.merge("sort" => "listed")
    @cli.users("sferik", "pengwynn")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_since
    users_stubs
    @cli.options = @cli.options.merge("sort" => "since")
    @cli.users("sferik", "pengwynn")

    assert_equal("sferik    pengwynn", $stdout.string.chomp)
  end

  def test_users_with_sort_tweets
    users_stubs
    @cli.options = @cli.options.merge("sort" => "tweets")
    @cli.users("sferik", "pengwynn")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_sort_tweeted
    users_stubs
    @cli.options = @cli.options.merge("sort" => "tweeted")
    @cli.users("sferik", "pengwynn")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  def test_users_with_unsorted
    users_stubs
    @cli.options = @cli.options.merge("unsorted" => true)
    @cli.users("sferik", "pengwynn")

    assert_equal("pengwynn  sferik", $stdout.string.chomp)
  end

  # version

  def test_version_has_the_correct_output
    @cli.version

    assert_equal(T::Version.to_s, $stdout.string.chomp)
  end

  # whois

  def test_whois_requests_correct_resource
    stub_v2_user_by_name("sferik")
    @cli.whois("sferik")

    assert_requested(:get, v2_pattern("users/by/username/sferik"))
  end

  def test_whois_has_the_correct_output
    stub_v2_user_by_name("sferik")
    @cli.whois("sferik")
    expected_output = <<~EOS
      ID           7505382
      Since        Jul 16  2007 (4 years ago)
      Last update  @goldman You're near my home town! Say hi to Woodstock for me. (7 months ago)
      Screen name  @sferik
      Name         Erik Michaels-Ober
      Tweets       7,890
      Favorites    3,755
      Listed       118
      Following    212
      Followers    2,262
      Bio          Vagabond.
      Location     San Francisco
      URL          https://github.com/sferik
    EOS
    assert_equal(expected_output, $stdout.string)
  end

  def test_whois_with_csv
    stub_v2_user_by_name("sferik")
    @cli.options = @cli.options.merge("csv" => true)
    @cli.whois("sferik")

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
    assert_includes($stdout.string, "7505382")
  end

  def test_whois_with_id
    @cli.options = @cli.options.merge("id" => true)
    stub_v2_user_by_id("7505382")
    @cli.whois("7505382")

    assert_requested(:get, v2_pattern("users/7505382"))
  end

  def test_whois_with_long
    stub_v2_user_by_name("sferik")
    @cli.options = @cli.options.merge("long" => true)
    @cli.whois("sferik")

    assert_includes($stdout.string, "7505382")
    assert_includes($stdout.string, "Jul 16  2007")
  end

  # whoami

  def test_whoami_calls_users_me
    stub_v2_current_user("v2/sferik.json")
    @cli.whoami

    assert_requested(:get, v2_pattern("users/me"))
  end

  def test_whoami_does_not_call_whois
    stub_v2_current_user("v2/sferik.json")
    @cli.whoami

    assert_not_requested(:get, v2_pattern("users/by/username/testcli"))
  end

  def test_whoami_has_the_correct_output
    stub_v2_current_user("v2/sferik.json")
    @cli.whoami

    assert_includes($stdout.string, "7505382")
    assert_includes($stdout.string, "@sferik")
  end

  def test_whoami_with_csv
    stub_v2_current_user("v2/sferik.json")
    @cli.options = @cli.options.merge("csv" => true)
    @cli.whoami

    assert_includes($stdout.string, "ID,Since,Last tweeted at")
  end

  def test_whoami_with_long
    stub_v2_current_user("v2/sferik.json")
    @cli.options = @cli.options.merge("long" => true)
    @cli.whoami

    assert_includes($stdout.string, "7505382")
  end

  def test_whoami_with_no_configuration
    T::RCFile.instance.path = ""
    cli = T::CLI.new
    cli.whoami

    assert_equal("You haven't authorized an account, run `t authorize` to get started.\n", $stderr.string)
  end

  # accounts (branch coverage)

  def test_accounts_without_profile_option
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @cli.options = @cli.options.merge("profile" => nil)
    @cli.accounts
    expected_output = <<~EOS
      testcli
        abc123 (active)
    EOS
    assert_equal(expected_output, $stdout.string)
  end

  def test_accounts_with_non_active_key_marks_active
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc_multi")
    @cli.accounts

    assert_includes($stdout.string, "abc123 (active)")
  end

  def test_accounts_with_non_active_key_includes_other_key
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc_multi")
    @cli.accounts

    assert_includes($stdout.string, "def456")
  end

  def test_accounts_with_non_active_key_does_not_mark_other_as_active
    @cli.options = @cli.options.merge("profile" => "#{fixture_path}/.trc_multi")
    @cli.accounts

    refute_includes($stdout.string, "def456 (active)")
  end

  # authorize (branch coverage)

  def test_authorize_without_profile_option
    auth_tmp_path = "#{project_path}/tmp/authorize_branch_cov"
    T::RCFile.instance.path = auth_tmp_path
    @cli.options = @cli.options.merge("profile" => nil, "display-uri" => true)
    stub_post("/oauth/request_token").to_return(body: fixture("request_token"))
    stub_post("/oauth/access_token").to_return(body: fixture("access_token"))
    stub_get("/1.1/account/verify_credentials.json?skip_status=true").to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    stub_v2_current_user
    Readline.stub(:readline, authorize_readline_stub) do
      @cli.authorize
    end
  ensure
    FileUtils.rm_f(auth_tmp_path)
  end

  # direct_messages (branch coverage)

  def test_direct_messages_empty_with_csv
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(v2_return("v2/empty_dm_events.json"))
    @cli.options = @cli.options.merge("csv" => true)
    @cli.direct_messages

    assert_equal("", $stdout.string)
  end

  def test_direct_messages_empty_default_output
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(v2_return("v2/empty_dm_events.json"))
    @cli.direct_messages

    assert_equal("", $stdout.string)
  end

  # direct_messages_sent (branch coverage)

  def test_direct_messages_sent_empty_with_csv
    stub_v2_current_user
    stub_v2_get("dm_events").to_return(v2_return("v2/empty_dm_events.json"))
    @cli.options = @cli.options.merge("csv" => true)
    @cli.direct_messages_sent

    assert_equal("", $stdout.string)
  end

  # favorites (branch coverage)

  def test_favorites_with_exclude_replies
    stub_v2_current_user
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("exclude" => "replies")
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  def test_favorites_with_exclude_retweets
    stub_v2_current_user
    stub_v2_get("users/7505382/liked_tweets").to_return(v2_return("v2/statuses.json"))
    @cli.options = @cli.options.merge("exclude" => "retweets")
    @cli.favorites

    assert_requested(:get, v2_pattern("users/7505382/liked_tweets"))
  end

  # intersection (branch coverage)

  def test_intersection_with_unrecognized_type
    @cli.options = @cli.options.merge("type" => "other")
    stub_v2_users_lookup.to_return(v2_return("v2/empty.json"))
    stub_v2_user_by_name("sferik")
    stub_v2_user_by_name("testcli")
    stub_v2_get("users/by").to_return(v2_return("v2/empty.json"))
    @cli.intersection("sferik")

    assert_equal("", $stdout.string)
  end

  # status (branch coverage)

  def test_status_with_no_place_and_no_geo_excludes_location
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_geo.json"))
    @cli.status("55709764298092545")

    refute_includes($stdout.string, "Location")
  end

  def test_status_with_no_place_and_no_geo_includes_id
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_geo.json"))
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "55709764298092552")
  end

  def test_status_with_no_place_no_geo_csv_includes_id
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_geo.json"))
    @cli.options = @cli.options.merge("csv" => true)
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "55709764298092552")
  end

  def test_status_with_no_place_no_geo_csv_includes_header
    stub_v2_get("tweets/55709764298092545").to_return(v2_return("v2/status_no_geo.json"))
    @cli.options = @cli.options.merge("csv" => true)
    @cli.status("55709764298092545")

    assert_includes($stdout.string, "ID,Posted at,Screen name")
  end

  # trend_locations (branch coverage)

  def test_trend_locations_empty_with_csv
    stub_get("/1.1/trends/available.json").to_return(body: "[]", headers: {content_type: "application/json; charset=utf-8"})
    @cli.options = @cli.options.merge("csv" => true)
    @cli.trend_locations

    assert_equal("", $stdout.string)
  end

  # whois (branch coverage)

  def test_whois_user_no_status_excludes_last_update
    stub_v2_user_by_name("sferik", "v2/user_no_status.json")
    @cli.whois("sferik")

    refute_includes($stdout.string, "Last update")
  end

  def test_whois_user_no_status_includes_id
    stub_v2_user_by_name("sferik", "v2/user_no_status.json")
    @cli.whois("sferik")

    assert_includes($stdout.string, "7505382")
  end

  def test_whois_user_no_status_includes_screen_name
    stub_v2_user_by_name("sferik", "v2/user_no_status.json")
    @cli.whois("sferik")

    assert_includes($stdout.string, "@sferik")
  end

  def test_whois_user_no_status_includes_name
    stub_v2_user_by_name("sferik", "v2/user_no_status.json")
    @cli.whois("sferik")

    assert_includes($stdout.string, "Erik Michaels-Ober")
  end

  def test_whois_user_minimal_excludes_last_update
    stub_v2_user_by_name("sferik", "v2/user_minimal.json")
    @cli.whois("sferik")

    refute_includes($stdout.string, "Last update")
  end

  def test_whois_user_minimal_excludes_name
    stub_v2_user_by_name("sferik", "v2/user_minimal.json")
    @cli.whois("sferik")

    refute_includes($stdout.string, "Name")
  end

  def test_whois_user_minimal_excludes_bio
    stub_v2_user_by_name("sferik", "v2/user_minimal.json")
    @cli.whois("sferik")

    refute_includes($stdout.string, "Bio")
  end

  def test_whois_user_minimal_excludes_location
    stub_v2_user_by_name("sferik", "v2/user_minimal.json")
    @cli.whois("sferik")

    refute_includes($stdout.string, "Location")
  end

  def test_whois_user_minimal_excludes_url
    stub_v2_user_by_name("sferik", "v2/user_minimal.json")
    @cli.whois("sferik")

    refute_includes($stdout.string, "URL")
  end

  def test_whois_user_minimal_includes_id
    stub_v2_user_by_name("sferik", "v2/user_minimal.json")
    @cli.whois("sferik")

    assert_includes($stdout.string, "7505382")
  end

  def test_whois_user_minimal_includes_screen_name
    stub_v2_user_by_name("sferik", "v2/user_minimal.json")
    @cli.whois("sferik")

    assert_includes($stdout.string, "@sferik")
  end

  def test_whois_user_verified_shows_verified_label
    stub_v2_user_by_name("sferik", "v2/user_verified.json")
    @cli.whois("sferik")

    assert_includes($stdout.string, "Name (Verified)")
  end

  def test_whois_user_verified_shows_name
    stub_v2_user_by_name("sferik", "v2/user_verified.json")
    @cli.whois("sferik")

    assert_includes($stdout.string, "Erik Michaels-Ober")
  end

  # extract_mentioned_screen_names (branch coverage)

  def test_extract_mentioned_screen_names_nil
    result = @cli.send(:extract_mentioned_screen_names, nil)

    assert_equal([], result)
  end

  def test_extract_mentioned_screen_names_no_mentions
    result = @cli.send(:extract_mentioned_screen_names, "no mentions here")

    assert_equal([], result)
  end

  def test_extract_mentioned_screen_names_with_mentions
    result = @cli.send(:extract_mentioned_screen_names, "hello @sferik and @pengwynn")

    assert_equal(%w[sferik pengwynn], result)
  end
end
