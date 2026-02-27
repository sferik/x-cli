require "tempfile"
require "shellwords"

module T
  class Editor
    class << self
      def gets
        file = tempfile
        edit(file.path)
        File.read(file).strip
      ensure
        file.close
        file.unlink
      end

      def tempfile
        Tempfile.new("TWEET_EDITMSG")
      end

      def edit(path)
        system(Shellwords.join([editor, path]))
      end

      def editor
        ENV["VISUAL"] || ENV["EDITOR"] || system_editor
      end

      def system_editor
        /mswin|mingw/.match?(RbConfig::CONFIG["host_os"]) ? "notepad" : "vi"
      end
    end
  end
end
