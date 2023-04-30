namespace :completion do
  desc "Generate bash completion file"
  task :bash do
    Bundler.require(:default)

    output_path = "etc/t-completion.sh"
    file_path = File.expand_path(output_path)
    puts "Compiling bash completion to #{output_path}"
    File.write(file_path, BashCompletion.generate)

    git_status = `git status -s`
    if git_status[/M #{output_path}/]
      cmd = "git add #{output_path} && git commit -m 'Updating Bash completion'"
      result = system cmd
      raise("Could not commit changes") unless result
    end
  end
end

# using a module to avoid namespace conflicts
module BashCompletion
  class << self
    def generate
      %[# Completion for Bash. Copy it in /etc/bash_completion.d/ or source it
      # somewhere in your ~/.bashrc

      _t() {

        local cur prev completions

        COMPREPLY=()
        cur=${COMP_WORDS[COMP_CWORD]}
        topcmd=${COMP_WORDS[1]}
        prev=${COMP_WORDS[COMP_CWORD-1]}

        COMMANDS='#{commands.collect(&:name).join(' ')}'

        case "$topcmd" in
          #{comp_cases}
          *) completions="$COMMANDS" ;;
        esac

        COMPREPLY=( $( compgen -W "$completions" -- $cur ))
        return 0

      }

      complete -F _t $filenames t
      ]
    end

    def comp_cases
      commands.collect do |cmd|
        options_str = options(cmd).join(" ")
        subcmds = subcommands(cmd)

        opts_args = cmd.options.collect do |_, opt|
          cases = opt.enum
          if cases
            %[#{option_str(opt).tr(' ', '|')})
               completions='#{cases.join(' ')}' ;;]
          end
        end.compact

        if subcmds.empty?
          %[#{cmd.name})
              case "$prev" in
              #{opts_args.join("\n") unless opts_args.empty?}
              #{global_options_args}
              *) completions='#{options_str}' ;;
              esac;;\n]
        else
          subcommands_cases = subcmds.collect do |sn|
            "#{sn}) completions='#{options_str}' ;;"
          end.join("\n")

          %[#{cmd.name})
              case "$prev" in
              #{cmd.name}) completions='#{subcmds.join(' ')}';;
              #{subcommands_cases}
              #{opts_args.join("\n") unless opts_args.empty?}
              #{global_options_args}
              *) completions='#{options_str}';;
              esac;;\n]
        end
      end.join("\n")
    end

    def options(cmd)
      cmd.options.collect { |_, o| option_str(o) }.concat(global_options)
    end

    def option_str(opt)
      if opt.aliases
        "--#{opt.name} #{o.aliases.join(' ')}"
      else
        "--#{opt.name}"
      end
    end

    def commands
      T::CLI.tasks.collect(&:last)
    end

    def global_options
      %w[-H --host -C --color -P --profile]
    end

    def global_options_args
      "-C|--color) completions='auto never' ;;\n"
    end

    def subcommands(cmd)
      return [] unless T::CLI.subcommands.include?(cmd.name)

      klass = T.const_get cmd.name.capitalize

      klass.tasks.collect { |_, t| t.name }
    end
  end
end
