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
        RbConfig::CONFIG["host_os"] =~ /mswin|mingw/ ? "notepad" : "vi"
      end
    end
  end
end
