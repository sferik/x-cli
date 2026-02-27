require_relative "printable/rendering"
require_relative "printable/messaging"

module T
  module Printable
    include Printable::Rendering
    include Printable::Messaging

    LIST_HEADINGS = ["ID", "Created at", "Screen name", "Slug", "Members", "Subscribers", "Mode", "Description"].freeze
    TWEET_HEADINGS = ["ID", "Posted at", "Screen name", "Text"].freeze
    USER_HEADINGS = ["ID", "Since", "Last tweeted at", "Tweets", "Favorites", "Listed", "Following", "Followers", "Screen name", "Name", "Verified", "Protected", "Bio", "Status", "Location", "URL"].freeze
    MONTH_IN_SECONDS = 2_592_000

    LISTS_SORT_MAP = {
      "members" => ->(list) { list["member_count"] },
      "mode" => ->(list) { list["mode"] },
      "since" => ->(list) { list["created_at"].to_s },
      "subscribers" => ->(list) { list["subscriber_count"] },
    }.freeze

    USERS_SORT_MAP = {
      "favorites" => ->(user) { user["favorites_count"].to_i },
      "followers" => ->(user) { user["followers_count"].to_i },
      "friends" => ->(user) { user["friends_count"].to_i },
      "listed" => ->(user) { user["listed_count"].to_i },
      "since" => ->(user) { user["created_at"].to_s },
      "tweets" => ->(user) { user["statuses_count"].to_i },
      "tweeted" => ->(user) { user["status"] ? user["status"]["created_at"].to_s : "" },
    }.freeze

  private

    def print_lists(lists)
      lists = sort_collection(lists, LISTS_SORT_MAP, ->(list) { list["slug"].downcase })
      format_lists(lists)
    end

    def format_lists(lists)
      if options["csv"]
        require "csv"
        say LIST_HEADINGS.to_csv unless lists.empty?
        lists.each { |list| print_csv_list(list) }
      elsif options["long"]
        array = lists.collect { |list| build_long_list(list) }
        format = options["format"] || Array.new(LIST_HEADINGS.size) { "%s" }
        print_table_with_headings(array, LIST_HEADINGS, format)
      else
        print_attribute(lists, "full_name")
      end
    end

    def sort_collection(collection, sort_map, default_sort)
      unless options["unsorted"]
        sort_fn = sort_map[options["sort"]] || default_sort
        collection = collection.sort_by(&sort_fn)
      end
      collection.reverse! if options["reverse"]
      collection
    end

    def print_tweets(tweets)
      tweets.reverse! if options["reverse"]
      format_tweets(tweets)
    end

    def format_tweets(tweets)
      if options["csv"]
        require "csv"
        say TWEET_HEADINGS.to_csv unless tweets.empty?
        tweets.each { |tweet| print_csv_tweet(tweet) }
      elsif options["long"]
        array = tweets.collect { |tweet| build_long_tweet(tweet) }
        format = options["format"] || Array.new(TWEET_HEADINGS.size) { "%s" }
        print_table_with_headings(array, TWEET_HEADINGS, format)
      else
        print_tweet_messages(tweets)
      end
    end

    def print_tweet_messages(tweets)
      tweets.each do |tweet|
        print_message(tweet["user"]["screen_name"], decode_uris(tweet["full_text"], options["decode_uris"] ? tweet["uris"] : nil))
      end
    end

    def print_users(users)
      users = sort_collection(users, USERS_SORT_MAP, ->(user) { user["screen_name"].downcase })
      format_users(users)
    end

    def format_users(users)
      if options["csv"]
        require "csv"
        say USER_HEADINGS.to_csv unless users.empty?
        users.each { |user| print_csv_user(user) }
      elsif options["long"]
        array = users.collect { |user| build_long_user(user) }
        format = options["format"] || Array.new(USER_HEADINGS.size) { "%s" }
        print_table_with_headings(array, USER_HEADINGS, format)
      else
        print_attribute(users, "screen_name")
      end
    end
  end
end
