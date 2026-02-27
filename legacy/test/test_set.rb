require "test_helper"

class TestSet < TTestCase
  def setup
    super
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
    $stdout = StringIO.new
    def $stdout.tty? = true
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @set_cmd = T::Set.new
  end

  def teardown
    T::RCFile.instance.reset
    $stderr = @original_stderr
    $stdout = @original_stdout
    super
  end

  # active

  def test_active_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc_set")
    @set_cmd.active("testcli", "abc123")

    assert_equal("Active account has been updated to testcli.", $stdout.string.chomp)
  end

  def test_active_accepts_account_name_without_consumer_key
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc_set")
    @set_cmd.active("testcli")

    assert_equal("Active account has been updated to testcli.", $stdout.string.chomp)
  end

  def test_active_is_case_insensitive
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc_set")
    @set_cmd.active("TestCLI", "abc123")

    assert_equal("Active account has been updated to testcli.", $stdout.string.chomp)
  end

  def test_active_raises_error_if_username_is_ambiguous
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc_set")
    e = assert_raises(ArgumentError) { @set_cmd.active("test", "abc123") }
    assert_match(/Username test is ambiguous/, e.message)
  end

  def test_active_raises_error_if_username_is_not_found
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc_set")
    e = assert_raises(ArgumentError) { @set_cmd.active("clitest") }
    assert_match(/Username clitest is not found/, e.message)
  end

  def test_active_without_profile_option_uses_default_rcfile_path
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc_set")
    @set_cmd.options = @set_cmd.options.except("profile")
    @set_cmd.active("testcli", "abc123")

    assert_equal("Active account has been updated to testcli.", $stdout.string.chomp)
  end

  # bio

  def test_bio_requests_correct_resource
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {description: "Vagabond."}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.bio("Vagabond.")

    assert_requested(:post, "https://api.twitter.com/1.1/account/update_profile.json", body: {description: "Vagabond."})
  end

  def test_bio_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {description: "Vagabond."}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.bio("Vagabond.")

    assert_equal("@testcli's bio has been updated.", $stdout.string.chomp)
  end

  # language

  def test_language_requests_correct_resource
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/settings.json").with(body: {lang: "en"}).to_return(body: fixture("settings.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.language("en")

    assert_requested(:post, "https://api.twitter.com/1.1/account/settings.json", body: {lang: "en"})
  end

  def test_language_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/settings.json").with(body: {lang: "en"}).to_return(body: fixture("settings.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.language("en")

    assert_equal("@testcli's language has been updated.", $stdout.string.chomp)
  end

  # location

  def test_location_requests_correct_resource
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {location: "San Francisco"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.location("San Francisco")

    assert_requested(:post, "https://api.twitter.com/1.1/account/update_profile.json", body: {location: "San Francisco"})
  end

  def test_location_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {location: "San Francisco"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.location("San Francisco")

    assert_equal("@testcli's location has been updated.", $stdout.string.chomp)
  end

  # name

  def test_name_requests_correct_resource
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {name: "Erik Michaels-Ober"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.name("Erik Michaels-Ober")

    assert_requested(:post, "https://api.twitter.com/1.1/account/update_profile.json", body: {name: "Erik Michaels-Ober"})
  end

  def test_name_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {name: "Erik Michaels-Ober"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.name("Erik Michaels-Ober")

    assert_equal("@testcli's name has been updated.", $stdout.string.chomp)
  end

  # profile_background_image

  def test_profile_background_image_requests_correct_resource
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile_background_image.json").to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.profile_background_image("#{fixture_path}/we_concept_bg2.png")

    assert_requested(:post, "https://api.twitter.com/1.1/account/update_profile_background_image.json")
  end

  def test_profile_background_image_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile_background_image.json").to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.profile_background_image("#{fixture_path}/we_concept_bg2.png")

    assert_equal("@testcli's background image has been updated.", $stdout.string.chomp)
  end

  # profile_image

  def test_profile_image_requests_correct_resource
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile_image.json").to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.profile_image("#{fixture_path}/me.jpg")

    assert_requested(:post, "https://api.twitter.com/1.1/account/update_profile_image.json")
  end

  def test_profile_image_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile_image.json").to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.profile_image("#{fixture_path}/me.jpg")

    assert_equal("@testcli's image has been updated.", $stdout.string.chomp)
  end

  # website

  def test_website_requests_correct_resource
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {url: "https://github.com/sferik"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.website("https://github.com/sferik")

    assert_requested(:post, "https://api.twitter.com/1.1/account/update_profile.json", body: {url: "https://github.com/sferik"})
  end

  def test_website_has_correct_output
    @set_cmd.options = @set_cmd.options.merge("profile" => "#{fixture_path}/.trc")
    stub_post("/1.1/account/update_profile.json").with(body: {url: "https://github.com/sferik"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
    @set_cmd.website("https://github.com/sferik")

    assert_equal("@testcli's website has been updated.", $stdout.string.chomp)
  end
end
