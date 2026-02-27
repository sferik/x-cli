require "test_helper"

class TestDelete < TTestCase
  def setup
    super
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
    $stdout = StringIO.new
    def $stdout.tty? = true
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @delete_cmd = T::Delete.new
  end

  def teardown
    T::RCFile.instance.reset
    $stderr = @original_stderr
    $stdout = @original_stdout
    super
  end

  # block

  def test_block_requests_the_correct_resource
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/blocking/7505382").to_return(v2_return("v2/post_response.json"))
    @delete_cmd.block("sferik")

    assert_requested(:delete, v2_pattern("users/7505382/blocking/7505382"))
  end

  def test_block_has_the_correct_output
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/blocking/7505382").to_return(v2_return("v2/post_response.json"))
    @delete_cmd.block("sferik")

    assert_match(/^@testcli unblocked 1 user\.$/, $stdout.string)
  end

  def test_block_with_id_requests_the_correct_resource
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc", "id" => true)
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_user_by_id("7505382")
    stub_v2_delete("users/7505382/blocking/7505382").to_return(v2_return("v2/post_response.json"))
    @delete_cmd.block("7505382")

    assert_requested(:delete, v2_pattern("users/7505382/blocking/7505382"))
  end

  # dm

  def setup_dm
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_get("dm_events/1773478249").to_return(v2_return("v2/dm_event.json"))
    stub_v2_user_by_id("14100886", "v2/pengwynn.json")
    stub_v2_delete("dm_events/1773478249").to_return(v2_return("v2/post_response.json"))
  end

  def test_dm_requests_the_dm_event_resource
    setup_dm
    Readline.stub(:readline, "yes") do
      @delete_cmd.dm("1773478249")
    end

    assert_requested(:get, v2_pattern("dm_events/1773478249"))
  end

  def test_dm_requests_the_dm_delete_resource
    setup_dm
    Readline.stub(:readline, "yes") do
      @delete_cmd.dm("1773478249")
    end

    assert_requested(:delete, v2_pattern("dm_events/1773478249"))
  end

  def test_dm_with_yes_has_the_correct_output
    setup_dm
    Readline.stub(:readline, "yes") do
      @delete_cmd.dm("1773478249")
    end

    assert_equal('@testcli deleted the direct message sent to @pengwynn: "testing"', $stdout.string.chomp)
  end

  def test_dm_with_no_has_the_correct_output
    setup_dm
    Readline.stub(:readline, "no") do
      @delete_cmd.dm("1773478249")
    end

    assert_empty($stdout.string.chomp)
  end

  def test_dm_with_force_requests_the_correct_resource
    setup_dm
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.dm("1773478249")

    assert_requested(:delete, v2_pattern("dm_events/1773478249"))
  end

  def test_dm_with_force_has_the_correct_output
    setup_dm
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.dm("1773478249")

    assert_equal("@testcli deleted 1 direct message.", $stdout.string.chomp)
  end

  def test_dm_with_force_pluralizes_when_deleting_multiple_direct_messages
    setup_dm
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    stub_v2_delete("dm_events/9999999").to_return(v2_return("v2/post_response.json"))
    @delete_cmd.dm("1773478249", "9999999")

    assert_equal("@testcli deleted 2 direct messages.", $stdout.string.chomp)
  end

  def test_dm_skips_the_message_when_direct_message_not_found
    setup_dm
    stub_v2_get("dm_events/9999999").to_return(v2_return("v2/empty.json"))
    @delete_cmd.dm("9999999")

    assert_empty($stdout.string.chomp)
  end

  # favorite

  def setup_favorite
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_get("tweets/28439861609").to_return(v2_return("v2/status.json"))
    stub_v2_delete("users/7505382/likes/28439861609").to_return(v2_return("v2/post_response.json"))
  end

  def test_favorite_requests_the_tweet_resource
    setup_favorite
    Readline.stub(:readline, "yes") do
      @delete_cmd.favorite("28439861609")
    end

    assert_requested(:get, v2_pattern("tweets/28439861609"), at_least_times: 1)
  end

  def test_favorite_requests_the_unlike_resource
    setup_favorite
    Readline.stub(:readline, "yes") do
      @delete_cmd.favorite("28439861609")
    end

    assert_requested(:delete, v2_pattern("users/7505382/likes/28439861609"))
  end

  def test_favorite_with_yes_has_the_correct_output
    setup_favorite
    Readline.stub(:readline, "yes") do
      @delete_cmd.favorite("28439861609")
    end

    assert_match(/^@testcli unfavorited @sferik's status: "The problem with your code is that it's doing exactly what you told it to do\."$/, $stdout.string)
  end

  def test_favorite_with_no_has_the_correct_output
    setup_favorite
    Readline.stub(:readline, "no") do
      @delete_cmd.favorite("28439861609")
    end

    assert_empty($stdout.string.chomp)
  end

  def test_favorite_with_force_requests_the_correct_resource
    setup_favorite
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.favorite("28439861609")

    assert_requested(:delete, v2_pattern("users/7505382/likes/28439861609"))
  end

  def test_favorite_with_force_has_the_correct_output
    setup_favorite
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.favorite("28439861609")

    assert_match(/^@testcli unfavorited Tweet 28439861609\.$/, $stdout.string)
  end

  # list

  def setup_list
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_get("users/7505382/owned_lists").to_return(v2_return("v2/list.json"))
    stub_v2_get("lists/8863586").to_return(v2_return("v2/list.json"))
    stub_v2_delete("lists/8863586").to_return(v2_return("v2/post_response.json"))
  end

  def test_list_requests_the_correct_resource
    setup_list
    Readline.stub(:readline, "yes") do
      @delete_cmd.list("presidents")
    end

    assert_requested(:delete, v2_pattern("lists/8863586"))
  end

  def test_list_with_yes_has_the_correct_output
    setup_list
    Readline.stub(:readline, "yes") do
      @delete_cmd.list("presidents")
    end

    assert_equal('@testcli deleted the list "presidents".', $stdout.string.chomp)
  end

  def test_list_with_no_has_the_correct_output
    setup_list
    Readline.stub(:readline, "no") do
      @delete_cmd.list("presidents")
    end

    assert_empty($stdout.string.chomp)
  end

  def test_list_with_force_requests_the_correct_resource
    setup_list
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.list("presidents")

    assert_requested(:delete, v2_pattern("lists/8863586"))
  end

  def test_list_with_force_has_the_correct_output
    setup_list
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.list("presidents")

    assert_equal('@testcli deleted the list "presidents".', $stdout.string.chomp)
  end

  def test_list_with_id_requests_the_correct_resource
    setup_list
    @delete_cmd.options = @delete_cmd.options.merge("id" => true)
    Readline.stub(:readline, "yes") do
      @delete_cmd.list("8863586")
    end

    assert_requested(:delete, v2_pattern("lists/8863586"))
  end

  # mute

  def test_mute_requests_the_correct_resource
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/muting/7505382").to_return(v2_return("v2/post_response.json"))
    @delete_cmd.mute("sferik")

    assert_requested(:delete, v2_pattern("users/7505382/muting/7505382"))
  end

  def test_mute_has_the_correct_output
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_delete("users/7505382/muting/7505382").to_return(v2_return("v2/post_response.json"))
    @delete_cmd.mute("sferik")

    assert_match(/^@testcli unmuted 1 user\.$/, $stdout.string)
  end

  def test_mute_with_id_requests_the_correct_resource
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc", "id" => true)
    stub_v2_current_user
    stub_v2_user_by_name("sferik")
    stub_v2_user_by_id("7505382")
    stub_v2_delete("users/7505382/muting/7505382").to_return(v2_return("v2/post_response.json"))
    @delete_cmd.mute("7505382")

    assert_requested(:delete, v2_pattern("users/7505382/muting/7505382"))
  end

  # account

  def setup_account
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    delete_cli = {
      "delete_cli" => {
        "dw123" => {
          "consumer_key" => "abc123",
          "secret" => "epzrjvxtumoc",
          "token" => "428004849-cebdct6bwobn",
          "username" => "deletecli",
          "consumer_secret" => "asdfasd223sd2",
        },
        "dw1234" => {
          "consumer_key" => "abc1234",
          "secret" => "epzrjvxtumoc",
          "token" => "428004849-cebdct6bwobn",
          "username" => "deletecli",
          "consumer_secret" => "asdfasd223sd2",
        },
      },
    }
    rcfile = @delete_cmd.instance_variable_get(:@rcfile)
    rcfile.profiles.merge!(delete_cli)
    rcfile.send(:write)
  end

  def teardown_account
    rcfile = @delete_cmd.instance_variable_get(:@rcfile)
    rcfile.delete_profile("delete_cli")
  end

  def test_account_deletes_the_key
    setup_account
    @delete_cmd.account("delete_cli", "dw1234")
    rcfile = @delete_cmd.instance_variable_get(:@rcfile)

    refute(rcfile.profiles["delete_cli"].key?("dw1234"))
  ensure
    teardown_account
  end

  def test_account_deletes_the_account
    setup_account
    @delete_cmd.account("delete_cli")
    rcfile = @delete_cmd.instance_variable_get(:@rcfile)

    refute(rcfile.profiles.key?("delete_cli"))
  ensure
    teardown_account
  end

  # status

  def setup_status
    @delete_cmd.options = @delete_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_v2_current_user
    stub_v2_get("tweets/26755176471724032").to_return(v2_return("v2/status.json"))
    stub_v2_delete("tweets/26755176471724032").to_return(v2_return("v2/post_response.json"))
  end

  def test_status_requests_the_tweet_resource
    setup_status
    Readline.stub(:readline, "yes") do
      @delete_cmd.status("26755176471724032")
    end

    assert_requested(:get, v2_pattern("tweets/26755176471724032"), at_least_times: 1)
  end

  def test_status_requests_the_delete_tweet_resource
    setup_status
    Readline.stub(:readline, "yes") do
      @delete_cmd.status("26755176471724032")
    end

    assert_requested(:delete, v2_pattern("tweets/26755176471724032"))
  end

  def test_status_with_yes_has_the_correct_output
    setup_status
    Readline.stub(:readline, "yes") do
      @delete_cmd.status("26755176471724032")
    end

    assert_equal("@testcli deleted the Tweet: \"The problem with your code is that it's doing exactly what you told it to do.\"", $stdout.string.chomp)
  end

  def test_status_with_no_has_the_correct_output
    setup_status
    Readline.stub(:readline, "no") do
      @delete_cmd.status("26755176471724032")
    end

    assert_empty($stdout.string.chomp)
  end

  def test_status_with_force_requests_the_correct_resource
    setup_status
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.status("26755176471724032")

    assert_requested(:delete, v2_pattern("tweets/26755176471724032"))
  end

  def test_status_with_force_has_the_correct_output
    setup_status
    @delete_cmd.options = @delete_cmd.options.merge("force" => true)
    @delete_cmd.status("26755176471724032")

    assert_equal("@testcli deleted Tweet 26755176471724032.", $stdout.string.chomp)
  end
end
