require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  desc 'Run RuboCop'
  task :rubocop do
    warn 'Rubocop is disabled'
  end
end

Dir.glob('tasks/*.rake').each { |r| import r }

task release: ['completion:zsh', 'completion:bash']
task test: :spec
task default: %i[spec rubocop]
