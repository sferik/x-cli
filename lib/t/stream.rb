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
      streaming_client.before_request do
        if options["csv"]
          require "csv"
          say TWEET_HEADINGS.to_csv
        elsif options["long"] && STDOUT.tty?
          headings = Array.new(TWEET_HEADINGS.size) do |index|
            TWEET_HEADINGS_FORMATTING[index] % TWEET_HEADINGS[index]
          end
          print_table([headings])
        end
      end
      streaming_client.sample do |tweet|
        next unless tweet.is_a?(Twitter::Tweet)

        if options["csv"]
          print_csv_tweet(tweet)
        elsif options["long"]
          array = build_long_tweet(tweet).each_with_index.collect do |element, index|
            TWEET_HEADINGS_FORMATTING[index] % element
          end
          print_table([array], truncate: STDOUT.tty?)
        else
          print_message(tweet.user.screen_name, tweet.text)
        end
      end
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
      streaming_client.before_request do
        list = T::List.new
        list.options = list.options.merge(options)
        list.options = list.options.merge(reverse: true)
        list.options = list.options.merge(format: TWEET_HEADINGS_FORMATTING)
        list.timeline(user_list)
      end
      user_ids = client.list_members(owner, list_name).collect(&:id)
      streaming_client.filter(follow: user_ids.join(",")) do |tweet|
        next unless tweet.is_a?(Twitter::Tweet)

        if options["csv"]
          print_csv_tweet(tweet)
        elsif options["long"]
          array = build_long_tweet(tweet).each_with_index.collect do |element, index|
            TWEET_HEADINGS_FORMATTING[index] % element
          end
          print_table([array], truncate: STDOUT.tty?)
        else
          print_message(tweet.user.screen_name, tweet.text)
        end
      end
    end
    map %w[tl] => :timeline

    desc "matrix", "Unfortunately, no one can be told what the Matrix is. You have to see it for yourself."
    def matrix
      require "t/cli"
      streaming_client.before_request do
        cli = T::CLI.new
        cli.matrix
      end
      streaming_client.sample(language: "ja") do |tweet|
        next unless tweet.is_a?(Twitter::Tweet)

        say(tweet.text.gsub(/[^\u3000\u3040-\u309f]/, "").reverse, %i[bold green on_black], false)
      end
    end

    desc "search KEYWORD [KEYWORD...]", "Stream Tweets that contain specified keywords, joined with logical ORs (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    def search(keyword, *keywords)
      keywords.unshift(keyword)
      require "t/search"
      streaming_client.before_request do
        search = T::Search.new
        search.options = search.options.merge(options)
        search.options = search.options.merge(reverse: true)
        search.options = search.options.merge(format: TWEET_HEADINGS_FORMATTING)
        search.all(keywords.join(" OR "))
      end
      streaming_client.filter(track: keywords.join(",")) do |tweet|
        next unless tweet.is_a?(Twitter::Tweet)

        if options["csv"]
          print_csv_tweet(tweet)
        elsif options["long"]
          array = build_long_tweet(tweet).each_with_index.collect do |element, index|
            TWEET_HEADINGS_FORMATTING[index] % element
          end
          print_table([array], truncate: STDOUT.tty?)
        else
          print_message(tweet.user.screen_name, tweet.text)
        end
      end
    end

    desc "timeline", "Stream your timeline (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    def timeline
      require "t/cli"
      streaming_client.before_request do
        cli = T::CLI.new
        cli.options = cli.options.merge(options)
        cli.options = cli.options.merge(reverse: true)
        cli.options = cli.options.merge(format: TWEET_HEADINGS_FORMATTING)
        cli.timeline
      end
      streaming_client.user do |tweet|
        next unless tweet.is_a?(Twitter::Tweet)

        if options["csv"]
          print_csv_tweet(tweet)
        elsif options["long"]
          array = build_long_tweet(tweet).each_with_index.collect do |element, index|
            TWEET_HEADINGS_FORMATTING[index] % element
          end
          print_table([array], truncate: STDOUT.tty?)
        else
          print_message(tweet.user.screen_name, tweet.text)
        end
      end
    end

    desc "users USER_ID [USER_ID...]", "Stream Tweets either from or in reply to specified users (Control-C to stop)"
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    def users(user_id, *user_ids)
      user_ids.unshift(user_id)
      user_ids.collect!(&:to_i)
      streaming_client.before_request do
        if options["csv"]
          require "csv"
          say TWEET_HEADINGS.to_csv
        elsif options["long"] && STDOUT.tty?
          headings = Array.new(TWEET_HEADINGS.size) do |index|
            TWEET_HEADINGS_FORMATTING[index] % TWEET_HEADINGS[index]
          end
          print_table([headings])
        end
      end
      streaming_client.filter(follow: user_ids.join(",")) do |tweet|
        next unless tweet.is_a?(Twitter::Tweet)

        if options["csv"]
          print_csv_tweet(tweet)
        elsif options["long"]
          array = build_long_tweet(tweet).each_with_index.collect do |element, index|
            TWEET_HEADINGS_FORMATTING[index] % element
          end
          print_table([array], truncate: STDOUT.tty?)
        else
          print_message(tweet.user.screen_name, tweet.text)
        end
      end
    end

  private

    def streaming_client
      return @streaming_client if @streaming_client

      @rcfile.path = options["profile"] if options["profile"]
      @streaming_client = Twitter::Streaming::Client.new do |config|
        config.consumer_key        = @rcfile.active_consumer_key
        config.consumer_secret     = @rcfile.active_consumer_secret
        config.access_token        = @rcfile.active_token
        config.access_token_secret = @rcfile.active_secret
      end
    end
  end
end
