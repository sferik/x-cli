module T
  module Utils
    # https://github.com/rails/rails/blob/bd8a970/actionpack/lib/action_view/helpers/date_helper.rb
    DISTANCE_THRESHOLDS = [
      [2, "a minute"],
      [60, ->(m) { format("%<minutes>d minutes", minutes: m) }],
      [120, "an hour"],
      [1410, ->(m) { format("%<hours>d hours", hours: (m.to_f / 60.0).round) }],
      [2880, "a day"],
      [42_480, ->(m) { format("%<days>d days", days: (m.to_f / 1440.0).round) }],
      [86_400, "a month"],
      [503_700, ->(m) { format("%<months>d months", months: (m.to_f / 43_800.0).round) }],
      [1_051_200, "a year"],
    ].freeze

  private

    def distance_of_time_in_words(from_time, to_time = Time.now)
      seconds = (to_time - from_time).abs
      minutes = seconds / 60
      return distance_in_seconds(seconds) if minutes < 1

      DISTANCE_THRESHOLDS.each do |threshold, result|
        return (result.is_a?(Proc) ? result.call(minutes) : result) if minutes < threshold
      end
      format("%<years>d years", years: (minutes.to_f / 525_600.0).round)
    end

    def distance_in_seconds(seconds)
      return "a split second" if seconds < 1
      return "a second" if seconds < 2

      format("%<seconds>d seconds", seconds:)
    end
    alias time_ago_in_words distance_of_time_in_words
    alias time_from_now_in_words distance_of_time_in_words

    def fetch_users(users, options)
      format_users!(users, options)
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        yield users
      end
      [users, users.length]
    end

    def format_users!(users, options)
      options["id"] ? users.collect!(&:to_i) : users.collect! { |u| u.tr("@", "") }
    end

    def extract_owner(user_list, options)
      owner, list_name = user_list.split("/")
      if list_name.nil?
        list_name = owner
        owner = @rcfile.active_profile[0]
      else
        owner = options["id"] ? owner.to_i : owner.tr("@", "")
      end
      [owner, list_name]
    end

    def strip_tags(html)
      html.gsub(/<.+?>/, "")
    end

    def number_with_delimiter(number, delimiter = ",")
      number.to_s.chars.reverse.each_slice(3).collect(&:join).join(delimiter).reverse
    end

    def pluralize(count, singular, plural = nil)
      "#{count || 0} " + (count == 1 || count.to_s =~ /^1(\.0+)?$/ ? singular : (plural || "#{singular}s"))
    end

    def decode_full_text(message, decode_full_uris: false)
      require "htmlentities"
      text = HTMLEntities.new.decode(message["full_text"])
      decode_full_uris ? decode_uris(text, message["uris"]) : text
    end

    def decode_uris(full_text, uri_entities)
      return full_text if uri_entities.nil?

      uri_entities.each do |uri_entity|
        uri, expanded_uri = extract_uri_pair(uri_entity)
        full_text = full_text.gsub(uri.to_s, expanded_uri.to_s)
      end

      full_text
    end

    def extract_uri_pair(uri_entity)
      uri = uri_entity["url"] || uri_entity[:url]
      expanded = uri_entity["expanded_url"] || uri_entity[:expanded_url] || uri
      [uri, expanded]
    end

    def build_timeline_opts
      {include_entities: !!options["decode_uris"]}.tap do |opts|
        opts[:exclude_replies] = true if options["exclude"] == "replies"
        opts[:include_rts] = false if options["exclude"] == "retweets"
        opts[:max_id] = options["max_id"] if options["max_id"]
        opts[:since_id] = options["since_id"] if options["since_id"]
      end
    end

    def resolve_user_input(user)
      options["id"] ? user.to_i : user.tr("@", "")
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
