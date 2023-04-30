module T
  module Utils
  private

    # https://github.com/rails/rails/blob/bd8a970/actionpack/lib/action_view/helpers/date_helper.rb
    def distance_of_time_in_words(from_time, to_time = Time.now) # rubocop:disable Metrics/CyclomaticComplexity
      seconds = (to_time - from_time).abs
      minutes = seconds / 60
      case minutes
      when 0...1
        case seconds
        when 0...1
          'a split second'
        when 1...2
          'a second'
        when 2...60
          format('%<seconds>d seconds', seconds: seconds)
        end
      when 1...2
        'a minute'
      when 2...60
        format('%<minutes>d minutes', minutes: minutes)
      when 60...120
        'an hour'
      # 120 minutes up to 23.5 hours
      when 120...1410
        format('%<hours>d hours', hours: (minutes.to_f / 60.0).round)
      # 23.5 hours up to 48 hours
      when 1410...2880
        'a day'
      # 48 hours up to 29.5 days
      when 2880...42_480
        format('%<days>d days', days: (minutes.to_f / 1440.0).round)
      # 29.5 days up to 60 days
      when 42_480...86_400
        'a month'
      # 60 days up to 11.5 months
      when 86_400...503_700
        format('%<months>d months', months: (minutes.to_f / 43_800.0).round)
      # 11.5 months up to 2 years
      when 503_700...1_051_200
        'a year'
      else
        format('%<years>d years', years: (minutes.to_f / 525_600.0).round)
      end
    end
    alias time_ago_in_words distance_of_time_in_words
    alias time_from_now_in_words distance_of_time_in_words

    def fetch_users(users, options)
      format_users!(users, options)
      require 'retryable'
      users = Retryable.retryable(tries: 3, on: Twitter::Error, sleep: 0) do
        yield users
      end
      [users, users.length]
    end

    def format_users!(users, options)
      require 't/core_ext/string'
      options['id'] ? users.collect!(&:to_i) : users.collect!(&:strip_ats)
    end

    def extract_owner(user_list, options)
      owner, list_name = user_list.split('/')
      if list_name.nil?
        list_name = owner
        owner = @rcfile.active_profile[0]
      else
        require 't/core_ext/string'
        owner = options['id'] ? owner.to_i : owner.strip_ats
      end
      [owner, list_name]
    end

    def strip_tags(html)
      html.gsub(/<.+?>/, '')
    end

    def number_with_delimiter(number, delimiter = ',')
      digits = number.to_s.chars
      groups = digits.reverse.each_slice(3).collect(&:join)
      groups.join(delimiter).reverse
    end

    def pluralize(count, singular, plural = nil)
      "#{count || 0} " + (count == 1 || count =~ /^1(\.0+)?$/ ? singular : (plural || "#{singular}s"))
    end

    def decode_full_text(message, decode_full_uris = false)
      require 'htmlentities'
      text = HTMLEntities.new.decode(message.full_text)
      text = decode_uris(text, message.uris) if decode_full_uris
      text
    end

    def decode_uris(full_text, uri_entities)
      return full_text if uri_entities.nil?

      uri_entities.each do |uri_entity|
        full_text = full_text.gsub(uri_entity.uri.to_s, uri_entity.expanded_uri.to_s)
      end

      full_text
    end

    def open_or_print(uri, options)
      Launchy.open(uri, options) do
        say "Open: #{uri}"
      end
    end

    def parallel_map(enumerable)
      enumerable.collect { |object| Thread.new { yield object } }.collect(&:value)
    end
  end
end
