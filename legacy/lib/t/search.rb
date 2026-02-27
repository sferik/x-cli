require "thor"
require "t/collectable"
require "t/printable"
require "t/rcfile"
require "t/requestable"
require "t/utils"

module T
  class Search < Thor
    include T::Collectable
    include T::Printable
    include T::Requestable
    include T::Utils

    DEFAULT_NUM_RESULTS = 20
    MAX_NUM_RESULTS = 200
    MAX_SEARCH_RESULTS = 100

    check_unknown_options!

    def initialize(*)
      @rcfile = T::RCFile.instance
      super
    end

    desc "all QUERY", "Returns the #{DEFAULT_NUM_RESULTS} most recent Tweets that match the specified query."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def all(query)
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = {count: MAX_SEARCH_RESULTS, include_entities: !!options["decode_uris"]}
      tweets = x_search(query, opts).take(count)
      tweets.reverse! if options["reverse"]
      print_search_results(tweets)
    end

    desc "favorites [USER] QUERY", "Returns Tweets you've favorited that match the specified query."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def favorites(*args)
      query = args.pop
      user = args.pop
      opts = {count: MAX_NUM_RESULTS}
      opts[:include_entities] = !!options["decode_uris"]
      if user
        user = options["id"] ? user.to_i : user.tr("@", "")
        tweets = collect_with_max_id do |max_id|
          opts[:max_id] = max_id unless max_id.nil?
          x_favorites(user, opts)
        end
      else
        tweets = collect_with_max_id do |max_id|
          opts[:max_id] = max_id unless max_id.nil?
          x_favorites(opts)
        end
      end
      tweets = tweets.select do |tweet|
        /#{query}/i.match(tweet["full_text"])
      end
      print_tweets(tweets)
    end
    map %w[faves] => :favorites

    desc "list [USER/]LIST QUERY", "Returns Tweets on a list that match the specified query."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def list(user_list, query)
      owner, list_name = extract_owner(user_list, options)
      opts = {count: MAX_NUM_RESULTS}
      opts[:include_entities] = !!options["decode_uris"]
      tweets = collect_with_max_id do |max_id|
        opts[:max_id] = max_id unless max_id.nil?
        x_list_timeline(owner, list_name, opts)
      end
      tweets = tweets.select do |tweet|
        /#{query}/i.match(tweet["full_text"])
      end
      print_tweets(tweets)
    end

    desc "mentions QUERY", "Returns Tweets mentioning you that match the specified query."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def mentions(query)
      opts = {count: MAX_NUM_RESULTS}
      opts[:include_entities] = !!options["decode_uris"]
      tweets = collect_with_max_id do |max_id|
        opts[:max_id] = max_id unless max_id.nil?
        x_mentions(opts)
      end
      tweets = tweets.select do |tweet|
        /#{query}/i.match(tweet["full_text"])
      end
      print_tweets(tweets)
    end
    map %w[replies] => :mentions

    desc "retweets [USER] QUERY", "Returns Tweets you've retweeted that match the specified query."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def retweets(*args)
      query = args.pop
      user = args.pop
      opts = {count: MAX_NUM_RESULTS}
      opts[:include_entities] = !!options["decode_uris"]
      if user
        user = options["id"] ? user.to_i : user.tr("@", "")
        tweets = collect_with_max_id do |max_id|
          opts[:max_id] = max_id unless max_id.nil?
          x_retweeted_by_user(user, opts)
        end
      else
        tweets = collect_with_max_id do |max_id|
          opts[:max_id] = max_id unless max_id.nil?
          x_retweeted_by_me(opts)
        end
      end
      tweets = tweets.select do |tweet|
        /#{query}/i.match(tweet["full_text"])
      end
      print_tweets(tweets)
    end
    map %w[rts] => :retweets

    desc "timeline [USER] QUERY", "Returns Tweets in your timeline that match the specified query."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "exclude", aliases: "-e", type: :string, enum: %w[replies retweets], desc: "Exclude certain types of Tweets from the results.", banner: "TYPE"
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "max_id", aliases: "-m", type: :numeric, desc: "Returns only the results with an ID less than the specified ID."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "since_id", aliases: "-s", type: :numeric, desc: "Returns only the results with an ID greater than the specified ID."
    def timeline(*args)
      query = args.pop
      user = args.pop
      opts = build_timeline_opts.merge(count: MAX_NUM_RESULTS)
      user = resolve_user_input(user) if user
      tweets = collect_with_max_id do |max_id|
        opts[:max_id] = max_id unless max_id.nil?
        user ? x_user_timeline(user, opts) : x_home_timeline(opts)
      end
      tweets = tweets.select { |tweet| /#{query}/i.match(tweet["full_text"]) }
      print_tweets(tweets)
    end
    map %w[tl] => :timeline

    desc "users QUERY", "Returns users that match the specified query."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def users(query)
      users = collect_with_page do |page|
        x_user_search(query, page:)
      end
      print_users(users)
    end

  private

    def print_search_results(tweets)
      if options["csv"]
        require "csv"
        say TWEET_HEADINGS.to_csv unless tweets.empty?
        tweets.each { |tweet| print_csv_tweet(tweet) }
      elsif options["long"]
        array = tweets.collect { |tweet| build_long_tweet(tweet) }
        format = options["format"] || Array.new(TWEET_HEADINGS.size) { "%s" }
        print_table_with_headings(array, TWEET_HEADINGS, format)
      else
        print_search_messages(tweets)
      end
    end

    def print_search_messages(tweets)
      say unless tweets.empty?
      tweets.each { |tweet| print_message(tweet["user"]["screen_name"], decode_full_text(tweet, decode_full_uris: options["decode_uris"])) }
    end
  end
end
