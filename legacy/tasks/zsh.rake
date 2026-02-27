namespace :completion do
  desc "Generate zsh completion file"
  task :zsh do
    Bundler.require(:default)

    output_path = "etc/t-completion.zsh"
    file_path = File.expand_path(output_path)
    puts "Compiling zsh completion to #{output_path}"
    File.write(file_path, zsh_completion)

    git_status = `git status -s`
    if git_status[/M #{output_path}/]
      cmd = "git add #{output_path} && git commit -m 'Updating Zsh completion'"
      result = system cmd
      raise("Could not commit changes") unless result
    end
  end
end

def zsh_completion
  %(#compdef t

# Completion for Zsh. Source from somewhere in your $fpath.

_t (){
  local -a t_general_options

  #{general_options_completions}

  if (( CURRENT > 2 )); then
    (( CURRENT-- ))
    shift words
    _call_function 1 _t_${words[1]}
  else
    _values "t command" \\
#{task_completions}

  fi
}

#{command_functions}

#{subcommand_arguments_functions}

#{subcommand_functions}
)
end

def general_options_completions
  %(t_general_options=("(-H --host)"{-H,--host=}"[Twitter API server]:URL:_urls"
    "(-C --color)"{-C,--color}"[Control how color is used in output]"
    "(-U --no-ssl)"{-U,--no-ssl}"[Disable SSL]"
    "(-P --profile)"{-P,--profile=}"[Path to RC file]:file:_files"
    $nul_arg
  )
)
end

def option_completion(thor_option)
  aliases = thor_option.aliases
  name = thor_option.name
  desc = thor_option.description.to_s.gsub "'", "\\\\'"
  %("(#{aliases.join(' ')} --#{name})"{#{aliases.join(',')},--#{name}}"[#{desc}]" \\)
end

def command_function_arguments(command)
  body = command.options.collect { |_, option| option_completion(option) }
  body << "$t_general_options && ret=0"

  body.join("\n    ")
end

def task_completions
  T::CLI.tasks.collect(&:last).collect do |task|
    desc = task.description.to_s.gsub "'", "\\\\'"
    %(      "#{task.name}[#{desc}]" \\)
  end.join("\n")
end

def commands
  T::CLI.tasks.except(*T::CLI.subcommands).collect(&:last)
end

def command_function(command)
  %(_t_#{command.name}() {
  _arguments \\
    #{command_function_arguments(command)}
}
)
end

def command_functions
  commands.
    collect { |t| command_function(t) }.
    join("\n")
end

def subcommands
  T::CLI.tasks.
    slice(*T::CLI.subcommands).
    collect(&:last)
end

def subcommand_function(command)
  %(_t_#{command.name}() {
  _arguments \\
    ":argument:__t_#{command.name}_arguments" \\
    $t_general_options && ret=0
}
)
end

def subcommand_functions
  subcommands.
    collect { |t| subcommand_function(t) }.
    join("\n")
end

def arguments_function(subcommand)
  klass = T.const_get subcommand.name.capitalize
  %(__t_#{subcommand.name}_arguments() {
  _args=(#{klass.tasks.collect { |t| t.last.name }.join("\n    ")}
  )
  compadd "$@" -k _args
}
)
end

def subcommand_arguments_functions
  subcommands.collect { |s| arguments_function(s) }.join("\n")
end
