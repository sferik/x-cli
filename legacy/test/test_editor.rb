require "test_helper"
require "shellwords"

class TestEditor < TTestCase
  def setup
    super
    @original_host_os = RbConfig::CONFIG["host_os"]
    @original_editor = ENV.fetch("EDITOR", nil)
    @original_visual = ENV.fetch("VISUAL", nil)
  end

  def teardown
    RbConfig::CONFIG["host_os"] = @original_host_os
    ENV["EDITOR"] = @original_editor
    ENV["VISUAL"] = @original_visual
    super
  end

  def test_gets_returns_tweet_content
    T::Editor.stub(:edit, ->(path) { File.binwrite(path, "A tweet!!!!") }) do
      assert_equal("A tweet!!!!", T::Editor.gets)
    end
  end

  def test_editor_returns_vi_on_mac_when_no_env_set
    ENV["EDITOR"] = ENV["VISUAL"] = nil
    RbConfig::CONFIG["host_os"] = "darwin12.2.0"

    assert_equal("vi", T::Editor.editor)
  end

  def test_editor_returns_vi_on_linux_when_no_env_set
    ENV["EDITOR"] = ENV["VISUAL"] = nil
    RbConfig::CONFIG["host_os"] = "3.2.0-4-amd64"

    assert_equal("vi", T::Editor.editor)
  end

  def test_editor_returns_notepad_on_windows_when_no_env_set
    ENV["EDITOR"] = ENV["VISUAL"] = nil
    RbConfig::CONFIG["host_os"] = "mswin"

    assert_equal("notepad", T::Editor.editor)
  end

  def test_editor_returns_visual_when_visual_is_set
    ENV["EDITOR"] = nil
    ENV["VISUAL"] = "/my/vim/install"

    assert_equal("/my/vim/install", T::Editor.editor)
  end

  def test_editor_returns_editor_when_editor_is_set
    ENV["EDITOR"] = "/usr/bin/subl"
    ENV["VISUAL"] = nil

    assert_equal("/usr/bin/subl", T::Editor.editor)
  end

  def test_editor_prefers_visual_over_editor
    ENV["EDITOR"] = "/my/vastly/superior/editor"
    ENV["VISUAL"] = "/usr/bin/emacs"

    assert_equal("/usr/bin/emacs", T::Editor.editor)
  end

  def test_system_editor_returns_vi_on_mac
    RbConfig::CONFIG["host_os"] = "darwin12.2.0"

    assert_equal("vi", T::Editor.system_editor)
  end

  def test_system_editor_returns_notepad_on_windows
    RbConfig::CONFIG["host_os"] = "mswin"

    assert_equal("notepad", T::Editor.system_editor)
  end

  def test_edit_runs_editor_command_with_shell_escaped_path
    path = "/tmp/a path with spaces.txt"
    expected_cmd = Shellwords.join(["/usr/bin/vim", path])
    received_cmd = nil

    T::Editor.stub(:editor, "/usr/bin/vim") do
      T::Editor.stub(:system, ->(cmd) { received_cmd = cmd }) do
        T::Editor.edit(path)
      end
    end

    assert_equal(expected_cmd, received_cmd)
  end
end
