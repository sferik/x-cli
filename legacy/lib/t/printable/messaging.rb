module T
  module Printable
    module Messaging
    private

      def print_message(from_user, message)
        require "htmlentities"

        case options["color"]
        when "icon"
          print_identicon(from_user, message)
          say
        when "auto"
          say("   @#{from_user}", %i[bold yellow])
          print_wrapped(HTMLEntities.new.decode(message), indent: 3)
        else
          say("   @#{from_user}")
          print_wrapped(HTMLEntities.new.decode(message), indent: 3)
        end
        say
      end

      def print_identicon(from_user, message)
        require "htmlentities"
        require "t/identicon"
        icon = Identicon.for_user_name(from_user)

        lines = wrapped(HTMLEntities.new.decode(message), indent: 2, width: Thor::Shell::Terminal.terminal_width - (6 + 5))
        lines.unshift(set_color("  @#{from_user}", :bold, :yellow))
        lines.concat(Array.new([3 - lines.length, 0].max) { "" })

        $stdout.puts(lines.zip(icon.lines).map { |x, i| "  #{i || '      '}#{x}" })
      end

      def wrapped(message, options = {})
        indent = options[:indent] || 0
        width = options[:width] || (Thor::Shell::Terminal.terminal_width - indent)
        paras = message.split("\n\n")

        paras.map! do |unwrapped|
          unwrapped.strip.squeeze(" ").gsub(/.{1,#{width}}(?:\s|\Z)/) { (::Regexp.last_match(0) + 5.chr).gsub(/\n\005/, "\n").gsub(/\005/, "\n") }
        end

        lines = paras.inject([]) do |memo, para|
          memo.concat(para.split("\n").map { |line| line.insert(0, " " * indent) })
          memo.push ""
        end

        lines.pop
        lines
      end
    end
  end
end
