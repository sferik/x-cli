require 'singleton'

module T
  class RCFile
    include Singleton
    attr_reader :path
    FILE_NAME = '.trc'.freeze

    def initialize
      @path = File.join(File.expand_path('~'), FILE_NAME)
      @data = load_file
    end

    def [](username)
      profiles[find(username)]
    end

    def find(username)
      possibilities = Array(find_case_insensitive_match(username) || find_case_insensitive_possibilities(username))
      raise(ArgumentError.new("Username #{username} is #{possibilities.empty? ? 'not found.' : 'ambiguous, matching ' + possibilities.join(', ')}")) unless possibilities.size == 1

      possibilities.first
    end

    def find_case_insensitive_match(username)
      profiles.keys.detect { |u| username.casecmp(u).zero? }
    end

    def find_case_insensitive_possibilities(username)
      profiles.keys.select { |u| username.casecmp(u[0, username.length]).zero? }
    end

    def []=(username, profile)
      profiles[username] ||= {}
      profiles[username].merge!(profile)
      write
    end

    def configuration
      @data['configuration']
    end

    def active_consumer_key
      profiles[active_profile[0]][active_profile[1]]['consumer_key'] if active_profile?
    end

    def active_consumer_secret
      profiles[active_profile[0]][active_profile[1]]['consumer_secret'] if active_profile?
    end

    def active_profile
      configuration['default_profile']
    end

    def active_profile=(profile)
      configuration['default_profile'] = [profile['username'], profile['consumer_key']]
      write
    end

    def active_secret
      profiles[active_profile[0]][active_profile[1]]['secret'] if active_profile?
    end

    def active_token
      profiles[active_profile[0]][active_profile[1]]['token'] if active_profile?
    end

    def delete
      File.delete(@path) if File.exist?(@path)
    end

    def empty?
      @data == default_structure
    end

    def load_file
      require 'yaml'
      YAML.load_file(@path)
    rescue Errno::ENOENT
      default_structure
    end

    def path=(path)
      @path = path
      @data = load_file
    end

    def profiles
      @data['profiles']
    end

    def reset
      send(:initialize)
    end

    def delete_profile(profile)
      profiles.delete(profile)
      write
    end

    def delete_key(profile, key)
      profiles[profile].delete(key)
      write
    end

  private

    def active_profile?
      active_profile && profiles[active_profile[0]] && profiles[active_profile[0]][active_profile[1]]
    end

    def default_structure
      {'configuration' => {}, 'profiles' => {}}
    end

    def write
      require 'yaml'
      File.open(@path, File::RDWR | File::TRUNC | File::CREAT, 0o0600) do |rcfile|
        rcfile.write @data.to_yaml
      end
    end
  end
end
