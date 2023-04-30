require "thor"
require "twitter"
require "t/collectable"
require "t/printable"
require "t/rcfile"
require "t/requestable"
require "t/utils"

module T
  class List < Thor
    include T::Collectable
    include T::Printable
    include T::Requestable
    include T::Utils

    DEFAULT_NUM_RESULTS = 20

    check_unknown_options!

    def initialize(*)
      @rcfile = T::RCFile.instance
      super
    end

    desc "add LIST USER [USER...]", "Add members to a list."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    def add(list_name, user, *users)
      added_users, number = fetch_users(users.unshift(user), options) do |users_to_add|
        client.add_list_members(list_name, users_to_add)
        users_to_add
      end
      say "@#{@rcfile.active_profile[0]} added #{pluralize(number, 'member')} to the list \"#{list_name}\"."
      say
      if options["id"]
        say "Run `#{File.basename($PROGRAM_NAME)} list remove --id #{list_name} #{added_users.join(' ')}` to undo."
      else
        say "Run `#{File.basename($PROGRAM_NAME)} list remove #{list_name} #{added_users.collect { |added_user| "@#{added_user}" }.join(' ')}` to undo."
      end
    end

    desc "create LIST [DESCRIPTION]", "Create a new list."
    method_option "private", aliases: "-p", type: :boolean
    def create(list_name, description = nil)
      opts = description ? {description: description} : {}
      opts[:mode] = "private" if options["private"]
      client.create_list(list_name, opts)
      say "@#{@rcfile.active_profile[0]} created the list \"#{list_name}\"."
    end

    desc "information [USER/]LIST", "Retrieves detailed information about a Twitter list."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    def information(user_list)
      owner, list_name = extract_owner(user_list, options)
      list = client.list(owner, list_name)
      if options["csv"]
        require "csv"
        say ["ID", "Description", "Slug", "Screen name", "Created at", "Members", "Subscribers", "Following", "Mode", "URL"].to_csv
        say [list.id, list.description, list.slug, list.user.screen_name, csv_formatted_time(list), list.member_count, list.subscriber_count, list.following?, list.mode, list.uri].to_csv
      else
        array = []
        array << ["ID", list.id.to_s]
        array << ["Description", list.description] unless list.description.nil?
        array << ["Slug", list.slug]
        array << ["Screen name", "@#{list.user.screen_name}"]
        array << ["Created at", "#{ls_formatted_time(list, :created_at, false)} (#{time_ago_in_words(list.created_at)} ago)"]
        array << ["Members", number_with_delimiter(list.member_count)]
        array << ["Subscribers", number_with_delimiter(list.subscriber_count)]
        array << ["Status", list.following? ? "Following" : "Not following"]
        array << ["Mode", list.mode]
        array << ["URL", list.uri]
        print_table(array)
      end
    end
    map %w[details] => :information

    desc "members [USER/]LIST", "Returns the members of a Twitter list."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    method_option "sort", aliases: "-s", type: :string, enum: %w[favorites followers friends listed screen_name since tweets tweeted], default: "screen_name", desc: "Specify the order of the results.", banner: "ORDER"
    method_option "unsorted", aliases: "-u", type: :boolean, desc: "Output is not sorted."
    def members(user_list)
      owner, list_name = extract_owner(user_list, options)
      users = client.list_members(owner, list_name).to_a
      print_users(users)
    end

    desc "remove LIST USER [USER...]", "Remove members from a list."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify input as Twitter user IDs instead of screen names."
    def remove(list_name, user, *users)
      removed_users, number = fetch_users(users.unshift(user), options) do |users_to_remove|
        client.remove_list_members(list_name, users_to_remove)
        users_to_remove
      end
      say "@#{@rcfile.active_profile[0]} removed #{pluralize(number, 'member')} from the list \"#{list_name}\"."
      say
      if options["id"]
        say "Run `#{File.basename($PROGRAM_NAME)} list add --id #{list_name} #{removed_users.join(' ')}` to undo."
      else
        say "Run `#{File.basename($PROGRAM_NAME)} list add #{list_name} #{removed_users.collect { |removed_user| "@#{removed_user}" }.join(' ')}` to undo."
      end
    end

    desc "timeline [USER/]LIST", "Show tweet timeline for members of the specified list."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify user via ID instead of screen name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: DEFAULT_NUM_RESULTS, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def timeline(user_list)
      owner, list_name = extract_owner(user_list, options)
      count = options["number"] || DEFAULT_NUM_RESULTS
      opts = {}
      opts[:include_entities] = !!options["decode_uris"]
      tweets = collect_with_count(count) do |count_opts|
        client.list_timeline(owner, list_name, count_opts.merge(opts))
      end
      print_tweets(tweets)
    end
    map %w[tl] => :timeline
  end
end
