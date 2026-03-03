require "thor"
require "t/printable"
require "t/rcfile"
require "t/requestable"
require "t/utils"

module T
  class Stream < Thor
    include T::Printable
    include T::Requestable
    include T::Utils

    TWEET_HEADINGS_FORMATTING = [
      "%-18s",  # Add padding to maximum length of a Tweet ID
      "%-12s",  # Add padding to length of a timestamp formatted with ls_formatted_time
      "%-20s",  # Add padding to maximum length of a Twitter screen name
      "%s",     # Last element does not need special formatting
    ].freeze

    STREAM_FIELDS = "tweet.fields=author_id,created_at,entities,text&expansions=author_id&user.fields=username,name".freeze

    check_unknown_options!

    def initialize(*)
      @rcfile = T::RCFile.instance
      super
    end

    desc "all", "Stream a random sample of all Tweets (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    def all
      print_stream_headings
      stream_tweets("tweets/sample/stream") { |tweet| print_stream_tweet(tweet) }
    end

    desc "list [USER/]LIST", "Stream a timeline for members of the specified list (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def list(user_list)
      owner, list_name = extract_owner(user_list, options)
      require "t/list"
      list_obj = T::List.new
      list_obj.options = list_obj.options.merge(options)
      list_obj.options = list_obj.options.merge(reverse: true)
      list_obj.options = list_obj.options.merge(format: TWEET_HEADINGS_FORMATTING)
      list_obj.timeline(user_list)
      members = fetch_list_members_v1(owner, list_name)
      user_ids = members.collect { |member| member["id"] }
      rule_ids = setup_stream_rules([{value: user_ids.map { |id| "from:#{id}" }.join(" OR ")}])
      stream_tweets("tweets/search/stream") { |tweet| print_stream_tweet(tweet) }
    ensure
      remove_stream_rules(rule_ids || [])
    end
    map %w[tl] => :timeline

    desc "matrix", "Unfortunately, no one can be told what the Matrix is. You have to see it for yourself."
    def matrix
      rule_ids = setup_stream_rules([{value: "の lang:ja"}])
      stream_tweets("tweets/search/stream") do |tweet|
        text = (tweet["text"] || tweet["full_text"] || "").gsub(/[^\u3000\u3040-\u309f]/, "").reverse
        say(text, %i[bold green on_black], false) unless text.empty?
      end
    ensure
      remove_stream_rules(rule_ids || [])
    end

    desc "search KEYWORD [KEYWORD...]", "Stream Tweets that contain specified keywords, joined with logical ORs (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    def search(keyword, *keywords)
      keywords.unshift(keyword)
      require "t/search"
      search_obj = T::Search.new
      search_obj.options = search_obj.options.merge(options)
      search_obj.options = search_obj.options.merge(reverse: true)
      search_obj.options = search_obj.options.merge(format: TWEET_HEADINGS_FORMATTING)
      search_obj.all(keywords.join(" OR "))
      rule_ids = setup_stream_rules([{value: keywords.join(" OR ")}])
      stream_tweets("tweets/search/stream") { |tweet| print_stream_tweet(tweet) }
    ensure
      remove_stream_rules(rule_ids || [])
    end

    desc "timeline", "Stream your timeline (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    def timeline
      require "t/cli"
      cli = T::CLI.new
      cli.options = cli.options.merge(options)
      cli.options = cli.options.merge(reverse: true)
      cli.options = cli.options.merge(format: TWEET_HEADINGS_FORMATTING)
      cli.timeline
      username = @rcfile.active_profile[0]
      rule_ids = setup_stream_rules([{value: "from:#{username} OR to:#{username}"}])
      stream_tweets("tweets/search/stream") { |tweet| print_stream_tweet(tweet) }
    ensure
      remove_stream_rules(rule_ids || [])
    end

    desc "users USER_ID [USER_ID...]", "Stream Tweets either from or in reply to specified users (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    def users(user_id, *user_ids)
      user_ids.unshift(user_id)
      user_ids.collect!(&:to_i)
      print_stream_headings
      rule_ids = setup_stream_rules([{value: user_ids.map { |id| "from:#{id}" }.join(" OR ")}])
      stream_tweets("tweets/search/stream") { |tweet| print_stream_tweet(tweet) }
    ensure
      remove_stream_rules(rule_ids || [])
    end

  private

    def stream_tweets(endpoint)
      bearer_client.stream("#{endpoint}?#{STREAM_FIELDS}") do |json|
        tweet = extract_tweets(json).first
        yield tweet if tweet
      end
    end

    def clear_stream_rules
      response = bearer_client.get(t_normalize_path("tweets/search/stream/rules"))
      existing_ids = (response["data"] || []).filter_map { |rule| rule["id"] }
      remove_stream_rules(existing_ids)
    end

    def setup_stream_rules(rules)
      clear_stream_rules
      response = t_post_bearer_json("tweets/search/stream/rules", add: rules)
      (response["data"] || []).filter_map { |rule| rule["id"] }
    end

    def remove_stream_rules(rule_ids)
      return if rule_ids.empty?

      t_post_bearer_json("tweets/search/stream/rules", delete: {ids: rule_ids})
    end

    def print_stream_headings
      if options["csv"]
        require "csv"
        say TWEET_HEADINGS.to_csv
      elsif options["long"] && $stdout.tty?
        headings = Array.new(TWEET_HEADINGS.size) do |index|
          TWEET_HEADINGS_FORMATTING[index] % TWEET_HEADINGS[index]
        end
        print_table([headings])
      end
    end

    def print_stream_tweet(tweet)
      if options["csv"]
        print_csv_tweet(tweet)
      elsif options["long"]
        array = build_long_tweet(tweet).each_with_index.collect do |element, index|
          TWEET_HEADINGS_FORMATTING[index] % element
        end
        print_table([array], truncate: $stdout.tty?)
      else
        print_message(tweet["user"]["screen_name"], tweet["text"])
      end
    end

    def fetch_list_members_v1(owner, slug)
      client # ensure v1_client is initialized
      params = URI.encode_www_form(cursor: -1, owner_screen_name: owner, slug: slug)
      response = v1_client.get("lists/members.json?#{params}")
      response["users"] || []
    end
  end
end
