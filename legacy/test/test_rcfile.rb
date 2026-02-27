# encoding: utf-8

require "test_helper"

class RCFileTest < TTestCase
  def setup
    super
    FileUtils.mkdir_p("#{project_path}/tmp")
  end

  def teardown
    T::RCFile.instance.reset
    FileUtils.rm_f("#{project_path}/tmp/trc")
    super
  end

  def test_is_a_class
    assert_kind_of(Class, T::RCFile)
  end

  def test_raises_no_method_error_when_calling_new
    e = assert_raises(NoMethodError) { T::RCFile.new }
    assert_match(/private method (`|')new' called/, e.message)
  end

  # #[]

  def test_bracket_returns_profiles_for_a_user
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal(%w[abc123], rcfile["testcli"].keys)
  end

  # #[]=

  def test_bracket_equals_adds_a_profile_for_a_user
    rcfile = T::RCFile.instance
    rcfile.path = "#{project_path}/tmp/trc"
    rcfile["testcli"] = profile_data

    assert_equal(%w[abc123], rcfile["testcli"].keys)
  end

  def test_bracket_equals_is_not_world_writable
    rcfile = T::RCFile.instance
    rcfile.path = "#{project_path}/tmp/trc"
    rcfile["testcli"] = profile_data

    assert_nil(File.world_writable?(rcfile.path))
  end

  def test_bracket_equals_is_not_world_readable
    rcfile = T::RCFile.instance
    rcfile.path = "#{project_path}/tmp/trc"
    rcfile["testcli"] = profile_data

    assert_nil(File.world_readable?(rcfile.path))
  end

  # #configuration

  def test_configuration_returns_configuration
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal(%w[default_profile], rcfile.configuration.keys)
  end

  # #active_consumer_key

  def test_active_consumer_key_returns_default_consumer_key
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal("abc123", rcfile.active_consumer_key)
  end

  def test_active_consumer_key_returns_nil_when_no_active_profile
    rcfile = T::RCFile.instance
    rcfile.path = File.expand_path("fixtures/foo", __dir__)

    assert_nil(rcfile.active_consumer_key)
  end

  # #active_consumer_secret

  def test_active_consumer_secret_returns_default_consumer_secret
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal("asdfasd223sd2", rcfile.active_consumer_secret)
  end

  def test_active_consumer_secret_returns_nil_when_no_active_profile
    rcfile = T::RCFile.instance
    rcfile.path = File.expand_path("fixtures/foo", __dir__)

    assert_nil(rcfile.active_consumer_secret)
  end

  # #active_profile

  def test_active_profile_returns_default_profile
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal(%w[testcli abc123], rcfile.active_profile)
  end

  # #active_profile=

  def test_active_profile_equals_sets_default_profile
    rcfile = T::RCFile.instance
    rcfile.path = "#{project_path}/tmp/trc"
    rcfile.active_profile = {"username" => "testcli", "consumer_key" => "abc123"}

    assert_equal(%w[testcli abc123], rcfile.active_profile)
  end

  # #active_token

  def test_active_token_returns_default_token
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal("428004849-cebdct6bwobn", rcfile.active_token)
  end

  def test_active_token_returns_nil_when_no_active_profile
    rcfile = T::RCFile.instance
    rcfile.path = File.expand_path("fixtures/foo", __dir__)

    assert_nil(rcfile.active_token)
  end

  # #active_secret

  def test_active_secret_returns_default_secret
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal("epzrjvxtumoc", rcfile.active_secret)
  end

  def test_active_secret_returns_nil_when_no_active_profile
    rcfile = T::RCFile.instance
    rcfile.path = File.expand_path("fixtures/foo", __dir__)

    assert_nil(rcfile.active_secret)
  end

  # #delete

  def test_delete_confirms_rcfile_exists_before_deletion
    path = "#{project_path}/tmp/trc"
    File.write(path, YAML.dump({}))

    assert_path_exists(path)
  end

  def test_delete_removes_rcfile_after_deletion
    path = "#{project_path}/tmp/trc"
    File.write(path, YAML.dump({}))
    rcfile = T::RCFile.instance
    rcfile.path = path
    rcfile.delete

    refute_path_exists(path)
  end

  # #empty?

  def test_empty_returns_false_when_non_empty_file_exists
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    refute_empty(rcfile)
  end

  def test_empty_returns_true_when_file_does_not_exist
    rcfile = T::RCFile.instance
    rcfile.path = File.expand_path("fixtures/foo", __dir__)

    assert_empty(rcfile)
  end

  # #load_file

  def test_load_file_loads_data_when_file_exists
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal("testcli", rcfile.load_file["profiles"]["testcli"]["abc123"]["username"])
  end

  def test_load_file_loads_default_structure_when_file_does_not_exist
    rcfile = T::RCFile.instance
    rcfile.path = File.expand_path("fixtures/foo", __dir__)

    assert_equal(%w[configuration profiles], rcfile.load_file.keys.sort)
  end

  # .default_path

  def test_default_path_returns_xrc_when_xrc_exists
    xrc_path = File.join(File.expand_path("~"), ".xrc")
    original_exist = File.method(:exist?)

    File.stub(:exist?, ->(path) { path == xrc_path ? true : original_exist.call(path) }) do
      assert_equal(xrc_path, T::RCFile.default_path)
    end
  end

  def test_default_path_returns_trc_when_xrc_does_not_exist
    xrc_path = File.join(File.expand_path("~"), ".xrc")
    trc_path = File.join(File.expand_path("~"), ".trc")
    original_exist = File.method(:exist?)

    File.stub(:exist?, ->(path) { path == xrc_path ? false : original_exist.call(path) }) do
      assert_equal(trc_path, T::RCFile.default_path)
    end
  end

  # #path

  def test_path_defaults_to_default_path
    T::RCFile.instance.reset

    assert_equal(T::RCFile.default_path, T::RCFile.instance.path)
  end

  # #path=

  def test_path_equals_overrides_path
    rcfile = T::RCFile.instance
    rcfile.path = "#{project_path}/tmp/trc"

    assert_equal("#{project_path}/tmp/trc", rcfile.path)
  end

  def test_path_equals_reloads_data
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal("testcli", rcfile["testcli"]["abc123"]["username"])
  end

  # #profiles

  def test_profiles_returns_profiles
    rcfile = T::RCFile.instance
    rcfile.path = "#{fixture_path}/.trc"

    assert_equal(%w[testcli], rcfile.profiles.keys)
  end

private

  def profile_data
    {"abc123" => {username: "testcli", consumer_key: "abc123",
                  consumer_secret: "def456", token: "ghi789", secret: "jkl012"}}
  end
end
