require "test_helper"

class TestCollection < TTestCase
  def setup
    super
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
    $stdout = StringIO.new
    def $stdout.tty? = true
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @collection_cmd = T::Collection.new
  end

  def teardown
    T::RCFile.instance.reset
    $stderr = @original_stderr
    $stdout = @original_stdout
    super
  end

  def test_initialize
    assert_instance_of T::Collection, @collection_cmd
  end
end
