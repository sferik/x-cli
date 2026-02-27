# encoding: utf-8

require "forwardable"
require "oauth"
require "thor"
require "t/collectable"
require "t/delete"
require "t/editor"
require "t/list"
require "t/printable"
require "t/rcfile"
require "t/requestable"
require "t/search"
require "t/set"
require "t/stream"
require "t/utils"

module T
  class CLI < Thor
    extend Forwardable
    include T::Collectable
    include T::Printable
    include T::Requestable
    include T::Utils

    DEFAULT_NUM_RESULTS = 20
    DIRECT_MESSAGE_HEADINGS = ["ID", "Posted at", "Screen name", "Text"].freeze
    MAX_SEARCH_RESULTS = 100
    TREND_HEADINGS = ["WOEID", "Parent ID", "Type", "Name", "Country"].freeze

    check_unknown_options!

    class_option "color", aliases: "-C", type: :string, enum: %w[icon auto never], default: "auto", desc: "Control how color is used in output"
    class_option "profile", aliases: "-P", type: :string, default: T::RCFile.default_path, desc: "Path to RC file", banner: "FILE"

    def initialize(*)
      @rcfile = T::RCFile.instance
      super
    end

    desc "accounts", "List accounts"
    def accounts
      @rcfile.path = options["profile"] if options["profile"]
      @rcfile.profiles.each do |profile|
        say profile[0]
        profile[1].each_key do |key|
          say "  #{key}#{' (active)' if @rcfile.active_profile[0] == profile[0] && @rcfile.active_profile[1] == key}"
        end
      end
    end

    desc "authorize", "Allows an application to request user authorization"
    method_option "display-uri", aliases: "-d", type: :boolean, desc: "Display the authorization URL instead of attempting to open it."
    def authorize
      @rcfile.path = options["profile"] if options["profile"]
      if @rcfile.empty?
        say "Welcome! Before you can use t, you'll first need to register an"
        say "application with Twitter. Just follow the steps below:"
        say "  1. Sign in to the Twitter Application Management site and click"
        say '     "Create New App".'
        say "  2. Complete the required fields and submit the form."
        say "     Note: Your application must have a unique name."
        say "  3. Go to the Permissions tab of your application, and change the"
        say '     Access setting to "Read, Write and Access direct messages".'
        say "  4. Go to the Keys and Access Tokens tab to view the consumer key"
        say "     and secret which you'll need to copy and paste below when"
        say "     prompted."
      else
        say "It looks like you've already registered an application with Twitter."
        say "To authorize a new account, just follow the steps below:"
        say "  1. Sign in to the Twitter Developer site."
        say "  2. Select the application for which you'd like to authorize an account."
        say "  3. Copy and paste the consumer key and secret below when prompted."
      end
      say
      ask "Press [Enter] to open the Twitter Developer site."
      say
      require "launchy"
      open_or_print("https://apps.twitter.com", dry_run: options["display-uri"])
      key = ask "Enter your API key:"
      secret = ask "Enter your API secret:"
      consumer = OAuth::Consumer.new(key, secret, site: T::RequestableAPI::BASE_URL)
      request_token = consumer.get_request_token
      uri = generate_authorize_uri(consumer, request_token)
      say
      say "In a moment, you will be directed to the Twitter app authorization page."
      say "Perform the following steps to complete the authorization process:"
      say "  1. Sign in to Twitter."
      say '  2. Press "Authorize app".'
      say "  3. Copy and paste the supplied PIN below when prompted."
      say
      ask "Press [Enter] to open the Twitter app authorization page."
      say
      open_or_print(uri, dry_run: options["display-uri"])
      pin = ask "Enter the supplied PIN:"
      access_token = request_token.get_access_token(oauth_verifier: pin.chomp)
      oauth_response = access_token.get("/1.1/account/verify_credentials.json?skip_status=true")
      screen_name = oauth_response.body.match(/"screen_name"\s*:\s*"(.*?)"/).captures.first
      @rcfile[screen_name] = {
        key => {
          "username" => screen_name,
          "consumer_key" => key,
          "consumer_secret" => secret,
          "token" => access_token.token,
          "secret" => access_token.secret,
        },
      }
      @rcfile.active_profile = {"username" => screen_name, "consumer_key" => key}
      say "Authorization successful."
    end

    desc "block USER [USER...]", "Block users."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    def block(user, *users)
      blocked_users, number = fetch_users(users.unshift(user), options) do |users_to_block|
        x_block(users_to_block)
      end
      say "@#{@rcfile.active_profile[0]} blocked #{pluralize(number, 'user')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} delete block #{blocked_users.collect { |blocked_user| "@#{blocked_user['screen_name']}" }.join(' ')}` to unblock."
    end

    desc "direct_messages", "Returns the #{DEFAULT_NUM_RESULTS} most recent Direct Messages sent to you."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def direct_messages
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = {include_entities: !!options["decode_uris"]}
      messages = collect_with_count(count) { |count_opts| x_direct_messages_received(count_opts.merge(opts)) }
      users_hash = build_dm_users_hash(messages.map { |m| m["sender_id"] })
      messages.reverse! if options["reverse"]
      format_direct_messages(messages) { |dm| users_hash[dm["sender_id"]]["screen_name"] }
    end
    map %w[directmessages dms] => :direct_messages

    desc "direct_messages_sent", "Returns the #{DEFAULT_NUM_RESULTS} most recent Direct Messages you've sent."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def direct_messages_sent
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = {include_entities: !!options["decode_uris"]}
      messages = collect_with_count(count) { |count_opts| x_direct_messages_sent(count_opts.merge(opts)) }
      messages.reverse! if options["reverse"]
      format_direct_messages(messages) { |dm| dm["recipient"]["screen_name"] }
    end
    map %w[directmessagessent sent_messages sentmessages sms] => :direct_messages_sent

    desc "dm USER MESSAGE", "Sends that person a Direct Message."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    def dm(user, message)
      recipient = options["id"] ? x_user(user.to_i) : x_user(user.tr("@", ""))
      x_create_direct_message_event(recipient, message)
      say "Direct Message sent from @#{@rcfile.active_profile[0]} to @#{recipient['screen_name']}."
    end
    map %w[d m] => :dm

    desc "does_contain [USER/]LIST USER", "Find out whether a list contains a user."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    def does_contain(user_list, user = nil)
      owner, list_name = extract_owner(user_list, options)
      user = if user.nil?
        @rcfile.active_profile[0]
      else
        options["id"] ? x_user(user.to_i)["screen_name"] : user.tr("@", "")
      end
      if x_list_member?(owner, list_name, user)
        say "Yes, #{list_name} contains @#{user}."
      else
        abort "No, #{list_name} does not contain @#{user}."
      end
    end
    map %w[dc doescontain] => :does_contain

    desc "does_follow USER [USER]", "Find out whether one user follows another."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    def does_follow(user1, user2 = nil)
      abort "No, you are not following yourself." if user2.nil? && @rcfile.active_profile[0].casecmp(user1).zero?
      abort "No, @#{user1} is not following themself." if user1 == user2
      thread1 = Thread.new { resolve_follow_screen_name(user1) }
      thread2 = Thread.new { resolve_follow_screen_name(user2) }
      user1 = thread1.value
      user2 = thread2.value
      if x_friendship?(user1, user2)
        say "Yes, @#{user1} follows @#{user2}."
      else
        abort "No, @#{user1} does not follow @#{user2}."
      end
    end
    map %w[df doesfollow] => :does_follow

    desc "favorite TWEET_ID [TWEET_ID...]", "Marks Tweets as favorites."
    def favorite(status_id, *status_ids)
      status_ids.unshift(status_id)
      status_ids.collect!(&:to_i)
      require "retryable"
      favorites = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_favorite(status_ids)
      end
      number = favorites.length
      say "@#{@rcfile.active_profile[0]} favorited #{pluralize(number, 'tweet')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} delete favorite #{status_ids.join(' ')}` to unfavorite."
    end
    map %w[fave favourite] => :favorite

    desc "favorites [USER]", "Returns the #{DEFAULT_NUM_RESULTS} most recent Tweets you favorited."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "max_id", aliases: "-m", type: :numeric, desc: "Returns only the results with an ID less than the specified ID."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "since_id", aliases: "-s", type: :numeric, desc: "Returns only the results with an ID greater than the specified ID."
    def favorites(user = nil)
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = build_timeline_opts
      user = resolve_user_input(user) if user
      tweets = collect_with_count(count) do |count_opts|
        x_favorites(user, count_opts.merge(opts))
      end
      print_tweets(tweets)
    end
    map %w[faves favourites] => :favorites

    desc "follow USER [USER...]", "Allows you to start following users."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    def follow(user, *users)
      followed_users, number = fetch_users(users.unshift(user), options) do |users_to_follow|
        x_follow(users_to_follow)
      end
      say "@#{@rcfile.active_profile[0]} is now following #{pluralize(number, 'more user')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} unfollow #{followed_users.collect { |followed_user| "@#{followed_user['screen_name']}" }.join(' ')}` to stop."
    end

    desc "followings [USER]", "Returns a list of the people you follow on Twitter."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def followings(user = nil)
      if user
        user = options["id"] ? user.to_i : user.tr("@", "")
      end
      following_ids = x_friend_ids(user).to_a
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(following_ids)
      end
      print_users(users)
    end

    desc "followings_following USER [USER]", "Displays your friends who follow the specified user."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def followings_following(user1, user2 = nil)
      user1 = options["id"] ? user1.to_i : user1.tr("@", "")
      user2 = if user2.nil?
        @rcfile.active_profile[0]
      else
        options["id"] ? user2.to_i : user2.tr("@", "")
      end
      follower_ids = Thread.new { x_follower_ids(user1).to_a }
      following_ids = Thread.new { x_friend_ids(user2).to_a }
      followings_following_ids = follower_ids.value & following_ids.value
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(followings_following_ids)
      end
      print_users(users)
    end
    map %w[ff followingsfollowing] => :followings_following

    desc "followers [USER]", "Returns a list of the people who follow you on Twitter."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def followers(user = nil)
      if user
        user = options["id"] ? user.to_i : user.tr("@", "")
      end
      follower_ids = x_follower_ids(user).to_a
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(follower_ids)
      end
      print_users(users)
    end

    desc "friends [USER]", "Returns the list of people who you follow and follow you back."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def friends(user = nil)
      user = if user
        options["id"] ? user.to_i : user.tr("@", "")
      else
        x_verify_credentials["screen_name"]
      end
      following_ids = Thread.new { x_friend_ids(user).to_a }
      follower_ids = Thread.new { x_follower_ids(user).to_a }
      friend_ids = following_ids.value & follower_ids.value
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(friend_ids)
      end
      print_users(users)
    end

    desc "groupies [USER]", "Returns the list of people who follow you but you don't follow back."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def groupies(user = nil)
      user = if user
        options["id"] ? user.to_i : user.tr("@", "")
      else
        x_verify_credentials["screen_name"]
      end
      follower_ids = Thread.new { x_follower_ids(user).to_a }
      following_ids = Thread.new { x_friend_ids(user).to_a }
      groupie_ids = (follower_ids.value - following_ids.value)
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(groupie_ids)
      end
      print_users(users)
    end
    map %w[disciples] => :groupies

    desc "intersection USER [USER...]", "Displays the intersection of users followed by the specified users."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "type", aliases: "-t", type: :string, enum: %w[followers followings], default: "followings", desc: "Specify the type of intersection."
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def intersection(first_user, *users)
      users.push(first_user)
      # If only one user is specified, compare to the authenticated user
      users.push(@rcfile.active_profile[0]) if users.size == 1
      options["id"] ? users.collect!(&:to_i) : users.collect! { |u| u.tr("@", "") }
      sets = parallel_map(users) do |user|
        case options["type"]
        when "followings"
          x_friend_ids(user).to_a
        when "followers"
          x_follower_ids(user).to_a
        end
      end
      intersection = sets.reduce(:&)
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(intersection)
      end
      print_users(users)
    end
    map %w[overlap] => :intersection

    desc "leaders [USER]", "Returns the list of people who you follow but don't follow you back."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def leaders(user = nil)
      user = if user
        options["id"] ? user.to_i : user.tr("@", "")
      else
        x_verify_credentials["screen_name"]
      end
      following_ids = Thread.new { x_friend_ids(user).to_a }
      follower_ids = Thread.new { x_follower_ids(user).to_a }
      leader_ids = (following_ids.value - follower_ids.value)
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(leader_ids)
      end
      print_users(users)
    end

    desc "lists [USER]", "Returns the lists created by a user."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[members mode since slug subscribers], default: "slug", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def lists(user = nil)
      lists = if user
        user = options["id"] ? user.to_i : user.tr("@", "")
        x_lists(user)
      else
        x_lists
      end
      print_lists(lists)
    end

    desc "matrix", "Unfortunately, no one can be told what the Matrix is. You have to see it for yourself."
    def matrix
      rule_ids = install_matrix_stream_rules
      stream_fields = "tweet.fields=text"
      bearer_client.stream("tweets/search/stream?#{stream_fields}") do |json|
        tweet = extract_tweets(json).first
        next unless tweet

        text = (tweet["text"] || "").gsub(/[^\u3000\u3040-\u309f]/, "").reverse
        say(text, %i[bold green on_black], false) unless text.empty?
      end
    ensure
      remove_matrix_stream_rules(rule_ids || [])
    end

    desc "mentions", "Returns the #{DEFAULT_NUM_RESULTS} most recent Tweets mentioning you."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def mentions
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = {}
      opts[:include_entities] = !!options["decode_uris"]
      tweets = collect_with_count(count) do |count_opts|
        x_mentions(count_opts.merge(opts))
      end
      print_tweets(tweets)
    end
    map %w[replies] => :mentions

    desc "mute USER [USER...]", "Mute users."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    def mute(user, *users)
      muted_users, number = fetch_users(users.unshift(user), options) do |users_to_mute|
        x_mute(users_to_mute)
      end
      say "@#{@rcfile.active_profile[0]} muted #{pluralize(number, 'user')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} delete mute #{muted_users.collect { |muted_user| "@#{muted_user['screen_name']}" }.join(' ')}` to unmute."
    end

    desc "muted [USER]", "Returns a list of the people you have muted on Twitter."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def muted
      muted_ids = x_muted_ids.to_a
      require "retryable"
      muted_users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(muted_ids)
      end
      print_users(muted_users)
    end
    map %w[mutes] => :muted

    desc "open USER", "Opens that user's profile in a web browser."
    method_option "display-uri", aliases: "-d", type: :boolean, desc: "Display the requested URL instead of attempting to open it."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "status", aliases: "-s", type: :boolean, desc: "Specify input as a Twitter status ID instead of a screen name."
    def open(user)
      require "launchy"
      if options["id"]
        user = x_user(user.to_i)
        open_or_print(user["url"], dry_run: options["display-uri"])
      elsif options["status"]
        status = x_status(user.to_i, include_my_retweet: false)
        open_or_print(status["url"], dry_run: options["display-uri"])
      else
        open_or_print("https://twitter.com/#{user.tr('@', '')}", dry_run: options["display-uri"])
      end
    end

    desc "reach TWEET_ID", "Shows the maximum number of people who may have seen the specified tweet in their timeline."
    def reach(tweet_id)
      status_thread = Thread.new { x_status(tweet_id.to_i, include_my_retweet: false) }
      threads = x_retweeters_ids(tweet_id.to_i).collect do |retweeter_id|
        Thread.new(retweeter_id) do |user_id|
          x_follower_ids(user_id).to_a
        end
      end
      status = status_thread.value
      threads << Thread.new(status["user"]["id"]) do |user_id|
        x_follower_ids(user_id).to_a
      end
      reach = ::Set.new
      threads.each { |thread| reach += thread.value }
      reach.delete(status["user"]["id"])
      say number_with_delimiter(reach.size)
    end

    desc "reply TWEET_ID [MESSAGE]", "Post your Tweet as a reply directed at another person."
    method_option "all", aliases: "-a", type: :boolean, desc: "Reply to all users mentioned in the Tweet."
    method_option "location", aliases: "-l", type: :string, default: nil, desc: "Add location information. If the optional 'latitude,longitude' parameter is not supplied, looks up location by IP address."
    method_option "file", aliases: "-f", type: :string, desc: "The path to an image to attach to your tweet."
    def reply(status_id, message = nil)
      message = T::Editor.gets if message.to_s.empty?
      status = x_status(status_id.to_i, include_my_retweet: false)
      users = Array(status["user"]["screen_name"])
      if options["all"]
        users += extract_mentioned_screen_names(status["full_text"])
        users.uniq!
      end
      users.delete(@rcfile.active_profile[0])
      users.collect! { |u| "@#{u}" }
      opts = {in_reply_to_status_id: status["id"]}
      add_location!(options, opts)
      reply = if options["file"]
        x_update_with_media("#{users.join(' ')} #{message}", File.new(File.expand_path(options["file"])), opts)
      else
        x_update("#{users.join(' ')} #{message}", opts)
      end
      say "Reply posted by @#{@rcfile.active_profile[0]} to #{users.join(' ')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} delete status #{reply['id']}` to delete."
    end

    desc "report_spam USER [USER...]", "Report users for spam."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    def report_spam(user, *users)
      _, number = fetch_users(users.unshift(user), options) do |users_to_report|
        x_report_spam(users_to_report)
      end
      say "@#{@rcfile.active_profile[0]} reported #{pluralize(number, 'user')}."
    end
    map %w[report reportspam spam] => :report_spam

    desc "retweet TWEET_ID [TWEET_ID...]", "Sends Tweets to your followers."
    def retweet(status_id, *status_ids)
      status_ids.unshift(status_id)
      status_ids.collect!(&:to_i)
      require "retryable"
      retweets = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_retweet(status_ids)
      end
      number = retweets.length
      say "@#{@rcfile.active_profile[0]} retweeted #{pluralize(number, 'tweet')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} delete status #{retweets.collect { |r| r['id'] }.join(' ')}` to undo."
    end
    map %w[rt] => :retweet

    desc "retweets [USER]", "Returns the #{DEFAULT_NUM_RESULTS} most recent Retweets by a user."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def retweets(user = nil)
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = {}
      opts[:include_entities] = !!options["decode_uris"]
      tweets = if user
        user = options["id"] ? user.to_i : user.tr("@", "")
        collect_with_count(count) do |count_opts|
          x_retweeted_by_user(user, count_opts.merge(opts))
        end
      else
        collect_with_count(count) do |count_opts|
          x_retweeted_by_me(count_opts.merge(opts))
        end
      end
      print_tweets(tweets)
    end
    map %w[rts] => :retweets

    desc "retweets_of_me", "Returns the #{DEFAULT_NUM_RESULTS} most recent Tweets of the authenticated user that have been retweeted by others."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def retweets_of_me
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = {}
      opts[:include_entities] = !!options["decode_uris"]
      tweets = collect_with_count(count) do |count_opts|
        x_retweets_of_me(count_opts.merge(opts))
      end
      print_tweets(tweets)
    end
    map %w[retweetsofme] => :retweets_of_me

    desc "ruler", "Prints a 280-character ruler"
    method_option "indent", aliases: "-i", type: :numeric, default: 0, desc: "The number of spaces to print before the ruler."
    def ruler
      width = 280
      indent = " " * options["indent"].to_i
      line = (1..width).map do |position|
        if (position % 10).zero?
          "|"
        elsif (position % 5).zero?
          ":"
        else
          "."
        end
      end.join

      (20..width).step(20) do |marker|
        label = marker.to_s
        start = marker - label.length - 1
        line[start, label.length] = label
        line[marker - 1] = "|"
      end

      say "#{indent}#{line}"
    end

    desc "status TWEET_ID", "Retrieves detailed information about a Tweet."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def status(status_id)
      opts = {include_my_retweet: false, include_entities: !!options["decode_uris"]}
      status = x_status(status_id.to_i, opts)
      location = extract_status_location(status)
      format_status(status, location)
    end

    desc "timeline [USER]", "Returns the #{DEFAULT_NUM_RESULTS} most recent Tweets posted by a user."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "exclude", aliases: "-e", type: :string, enum: %w[replies retweets], desc: "Exclude certain types of Tweets from the results.", banner: "TYPE"
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "max_id", aliases: "-m", type: :numeric, desc: "Returns only the results with an ID less than the specified ID."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "since_id", aliases: "-s", type: :numeric, desc: "Returns only the results with an ID greater than the specified ID."
    def timeline(user = nil)
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = build_timeline_opts
      tweets = if user
        user = resolve_user_input(user)
        collect_with_count(count) { |count_opts| x_user_timeline(user, count_opts.merge(opts)) }
      else
        collect_with_count(count) { |count_opts| x_home_timeline(count_opts.merge(opts)) }
      end
      print_tweets(tweets)
    end
    map %w[tl] => :timeline

    desc "trends [WOEID]", "Returns the top 50 trending topics."
    method_option "exclude-hashtags", aliases: "-x", type: :boolean, desc: "Remove all hashtags from the trends list."
    def trends(woe_id = 1)
      opts = {}
      opts[:exclude] = "hashtags" if options["exclude-hashtags"]
      trends = x_trends(woe_id, opts)
      print_attribute(trends, "name")
    end

    desc "trend_locations", "Returns the locations for which Twitter has trending topic information."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[country name parent type woeid], default: "name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def trend_locations
      places = x_trend_locations
      places = sort_collection(places, TREND_SORT_MAP, ->(place) { place["name"].downcase })
      format_trend_locations(places)
    end
    map %w[locations trendlocations] => :trend_locations

    desc "unfollow USER [USER...]", "Allows you to stop following users."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    def unfollow(user, *users)
      unfollowed_users, number = fetch_users(users.unshift(user), options) do |users_to_unfollow|
        x_unfollow(users_to_unfollow)
      end
      say "@#{@rcfile.active_profile[0]} is no longer following #{pluralize(number, 'user')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} follow #{unfollowed_users.collect { |unfollowed_user| "@#{unfollowed_user['screen_name']}" }.join(' ')}` to follow again."
    end

    desc "update [MESSAGE]", "Post a Tweet."
    method_option "location", aliases: "-l", type: :string, default: nil, desc: "Add location information. If the optional 'latitude,longitude' parameter is not supplied, looks up location by IP address."
    method_option "file", aliases: "-f", type: :string, desc: "The path to an image to attach to your tweet."
    def update(message = nil)
      message = T::Editor.gets if message.to_s.empty?
      opts = {}
      add_location!(options, opts)
      status = if options["file"]
        x_update_with_media(message, File.new(File.expand_path(options["file"])), opts)
      else
        x_update(message, opts)
      end
      say "Tweet posted by @#{@rcfile.active_profile[0]}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} delete status #{status['id']}` to delete."
    end
    map %w[post tweet] => :update

    desc "users USER [USER...]", "Returns a list of users you specify."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def users(user, *users)
      users.unshift(user)
      options["id"] ? users.collect!(&:to_i) : users.collect! { |u| u.tr("@", "") }
      require "retryable"
      users = Retryable.retryable(tries: 3, on: X::Error, sleep: 0) do
        x_users(users)
      end
      print_users(users)
    end
    map %w[stats] => :users

    desc "version", "Show version."
    def version
      require "t/version"
      say T::Version
    end
    map %w[-v --version] => :version

    desc "whois USER", "Retrieves profile information for the user."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def whois(user)
      user = resolve_user_input(user)
      opts = {include_entities: !!options["decode_uris"]}
      user = x_user(user, opts)
      if options["csv"] || options["long"]
        print_users([user])
      else
        format_whois_default(user)
      end
    end
    map %w[user] => :whois

    desc "whoami", "Retrieves profile information for the authenticated user."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    def whoami
      if @rcfile.active_profile && @rcfile.active_profile[0]
        user = x_verify_credentials
        if options["csv"] || options["long"]
          print_users([user])
        else
          format_whois_default(user)
        end
      else
        warn "You haven't authorized an account, run `t authorize` to get started."
      end
    end

    desc "delete SUBCOMMAND ...ARGS", "Delete Tweets, Direct Messages, etc."
    subcommand "delete", T::Delete

    desc "list SUBCOMMAND ...ARGS", "Do various things with lists."
    subcommand "list", T::List

    desc "search SUBCOMMAND ...ARGS", "Search through Tweets."
    subcommand "search", T::Search

    desc "set SUBCOMMAND ...ARGS", "Change various account settings."
    subcommand "set", T::Set

    desc "stream SUBCOMMAND ...ARGS", "Commands for streaming Tweets."
    subcommand "stream", T::Stream

    TREND_SORT_MAP = {
      "country" => ->(place) { place["country"].to_s.downcase },
      "parent" => ->(place) { place["parent_id"].to_i },
      "type" => ->(place) { place["place_type"].to_s.downcase },
      "woeid" => ->(place) { place["woeid"].to_i },
    }.freeze

  private

    def install_matrix_stream_rules
      response = t_post_bearer_json("tweets/search/stream/rules", add: [{value: "の lang:ja"}])
      (response["data"] || []).filter_map { |rule| rule["id"] }
    end

    def remove_matrix_stream_rules(rule_ids)
      return if rule_ids.empty?

      t_post_bearer_json("tweets/search/stream/rules", delete: {ids: rule_ids})
    end

    def build_dm_users_hash(ids)
      return Hash.new { {} } if ids.empty?

      hash = x_users(ids).to_h { |user| [user["id"], user] }
      hash.default = {}
      hash
    end

    def format_direct_messages(messages, &)
      if options["csv"]
        require "csv"
        say DIRECT_MESSAGE_HEADINGS.to_csv unless messages.empty?
        messages.each { |dm| say [dm["id"], csv_formatted_time(dm), yield(dm), decode_full_text(dm, decode_full_uris: options["decode_uris"])].to_csv }
      elsif options["long"]
        array = messages.collect { |dm| [dm["id"], ls_formatted_time(dm), "@#{yield(dm)}", decode_full_text(dm, decode_full_uris: options["decode_uris"]).gsub(/\n+/, " ")] }
        format = options["format"] || Array.new(DIRECT_MESSAGE_HEADINGS.size) { "%s" }
        print_table_with_headings(array, DIRECT_MESSAGE_HEADINGS, format)
      else
        print_dm_messages(messages, &)
      end
    end

    def extract_status_location(status)
      if status["place"]
        place_location_parts(status["place"]).join(", ")
      elsif status["geo"]
        reverse_geocode(status["geo"])
      end
    end

    def place_location_parts(place)
      attrs = place["attributes"]
      build_detailed_place_parts(place, attrs) || build_compact_place_parts(place, attrs) || [place["name"]]
    end

    def build_detailed_place_parts(place, attrs)
      return nil unless place["name"] && attrs
      return nil unless attrs["locality"] && attrs["region"] && place["country"]

      parts = [place["name"]]
      parts << attrs["street_address"] if attrs["street_address"]
      parts << attrs["locality"]
      parts << attrs["region"]
      parts << place["country"]
      parts
    end

    def build_compact_place_parts(place, attrs)
      return nil unless place["full_name"]

      parts = [place["full_name"]]
      parts << attrs["region"] if attrs&.dig("region")
      parts << place["country"] if place["country"]
      parts
    end

    def format_status(status, location)
      status_headings = ["ID", "Posted at", "Screen name", "Text", "Retweets", "Favorites", "Source", "Location"]
      if options["csv"]
        require "csv"
        say status_headings.to_csv
        say [status["id"], csv_formatted_time(status), status["user"]["screen_name"], decode_full_text(status, decode_full_uris: options["decode_uris"]), status["retweet_count"], status["favorite_count"], strip_tags(status["source"].to_s), location].to_csv
      elsif options["long"]
        array = [status["id"], ls_formatted_time(status), "@#{status['user']['screen_name']}", decode_full_text(status, decode_full_uris: options["decode_uris"]).gsub(/\n+/, " "), status["retweet_count"], status["favorite_count"], strip_tags(status["source"].to_s), location]
        format = options["format"] || Array.new(status_headings.size) { "%s" }
        print_table_with_headings([array], status_headings, format)
      else
        format_status_default(status, location)
      end
    end

    def format_whois_default(user)
      array = []
      array << ["ID", user["id"].to_s]
      array << ["Since", "#{ls_formatted_time(user, 'created_at', allow_relative: false)} (#{time_ago_in_words(parse_time(user['created_at']))} ago)"]
      array << ["Last update", "#{decode_full_text(user['status'], decode_full_uris: options['decode_uris']).gsub(/\n+/, ' ')} (#{time_ago_in_words(parse_time(user['status']['created_at']))} ago)"] unless user["status"].nil?
      array << ["Screen name", "@#{user['screen_name']}"]
      array << [user["verified"] ? "Name (Verified)" : "Name", user["name"]] unless user["name"].nil?
      array << ["Tweets", number_with_delimiter(user["statuses_count"])]
      array << ["Favorites", number_with_delimiter(user["favorites_count"])]
      array << ["Listed", number_with_delimiter(user["listed_count"])]
      array << ["Following", number_with_delimiter(user["friends_count"])]
      array << ["Followers", number_with_delimiter(user["followers_count"])]
      array << ["Bio", user["description"].gsub(/\n+/, " ")] unless user["description"].nil?
      array << ["Location", user["location"]] unless user["location"].nil?
      array << ["URL", user["url"]] unless user["url"].nil?
      print_table(array)
    end

    def format_status_default(status, location)
      array = []
      array << ["ID", status["id"].to_s]
      array << ["Text", decode_full_text(status, decode_full_uris: options["decode_uris"]).gsub(/\n+/, " ")]
      array << ["Screen name", "@#{status['user']['screen_name']}"]
      array << ["Posted at", "#{ls_formatted_time(status, 'created_at', allow_relative: false)} (#{time_ago_in_words(parse_time(status['created_at']))} ago)"]
      array << ["Retweets", number_with_delimiter(status["retweet_count"])]
      array << ["Favorites", number_with_delimiter(status["favorite_count"])]
      array << ["Source", strip_tags(status["source"].to_s)]
      array << ["Location", location] unless location.nil?
      print_table(array)
    end

    def print_dm_messages(messages)
      messages.each { |dm| print_message(yield(dm), dm["text"]) }
    end

    def resolve_follow_screen_name(user)
      if user.nil?
        @rcfile.active_profile[0]
      elsif options["id"]
        x_user(user.to_i)["screen_name"]
      else
        user.tr("@", "")
      end
    end

    def format_trend_locations(places)
      if options["csv"]
        require "csv"
        say TREND_HEADINGS.to_csv unless places.empty?
        places.each { |place| say [place["woeid"], place["parent_id"], place["place_type"], place["name"], place["country"]].to_csv }
      elsif options["long"]
        array = places.collect { |place| [place["woeid"], place["parent_id"], place["place_type"], place["name"], place["country"]] }
        format = options["format"] || Array.new(TREND_HEADINGS.size) { "%s" }
        print_table_with_headings(array, TREND_HEADINGS, format)
      else
        print_attribute(places, "name")
      end
    end

    def extract_mentioned_screen_names(text)
      valid_mention_preceding_chars = /(?:[^a-zA-Z0-9_!#$%&*@＠]|^|RT:?)/o
      at_signs = /[@＠]/
      valid_mentions = /
        (#{valid_mention_preceding_chars})  # $1: Preceeding character
        (#{at_signs})                       # $2: At mark
        ([a-zA-Z0-9_]{1,20})                # $3: Screen name
      /ox

      return [] unless text&.match?(at_signs)

      text.to_s.scan(valid_mentions).collect do |_, _, screen_name|
        screen_name
      end
    end

    def generate_authorize_uri(consumer, request_token)
      request = consumer.create_signed_request(:get, consumer.authorize_path, request_token, pin_auth_parameters)
      params = request["Authorization"].sub(/^OAuth\s+/, "").split(/,\s+/).collect do |param|
        key, value = param.split("=")
        value =~ /"(.*?)"/
        "#{key}=#{CGI.escape(Regexp.last_match[1])}"
      end.join("&")
      "#{T::RequestableAPI::BASE_URL}#{request.path}?#{params}"
    end

    def pin_auth_parameters
      {oauth_callback: "oob"}
    end

    def add_location!(options, opts)
      return nil unless options["location"]

      lat, lng = options["location"] == "location" ? [location.lat, location.lng] : options["location"].split(",").collect(&:to_f)
      opts.merge!(lat:, long: lng)
    end

    def location
      return @location if @location

      require "geokit"
      require "open-uri"
      ip_address = URI.open("http://checkip.dyndns.org/") do |body|
        /(?:\d{1,3}\.){3}\d{1,3}/.match(body.read)[0]
      end
      @location = Geokit::Geocoders::MultiGeocoder.geocode(ip_address)
    end

    def reverse_geocode(geo)
      require "geokit"
      geoloc = Geokit::Geocoders::MultiGeocoder.reverse_geocode(geo["coordinates"])
      if geoloc.city && geoloc.state && geoloc.country
        [geoloc.city, geoloc.state, geoloc.country].join(", ")
      elsif geoloc.state && geoloc.country
        [geoloc.state, geoloc.country].join(", ")
      else
        geoloc.country
      end
    end
  end
end
