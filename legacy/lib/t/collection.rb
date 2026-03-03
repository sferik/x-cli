require "thor"
require "t/collectable"
require "t/printable"
require "t/rcfile"
require "t/requestable"
require "t/utils"

module T
  class Collection < Thor
    include T::Collectable
    include T::Printable
    include T::Requestable
    include T::Utils

    check_unknown_options!

    def initialize(*)
      @rcfile = T::RCFile.instance
      super
    end

    desc "add COLLECTION TWEET_ID [TWEET_ID...]", "Add tweets to a collection."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify collection via ID instead of name."
    def add(collection, tweet_id, *tweet_ids); end

    desc "create NAME [DESCRIPTION]", "Create a new collection."
    method_option "url", aliases: "-u", type: :string, desc: "A fully-qualified URL to associate with this collection."
    method_option "timeline_order", aliases: "-o", type: :string, enum: %w[curation_reverse_chron tweet_chron tweet_reverse_chron], desc: "Order of tweets in the collection.", banner: "ORDER"
    def create(name, description = nil); end

    desc "entries COLLECTION", "Show tweets in a collection."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "decode_uris", aliases: "-d", type: :boolean, desc: "Decodes t.co URLs into their original form."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify collection via ID instead of name."
    method_option "long", aliases: "-l", type: :boolean, desc: "Output in long format."
    method_option "number", aliases: "-n", type: :numeric, default: 20, desc: "Limit the number of results."
    method_option "relative_dates", aliases: "-a", type: :boolean, desc: "Show relative dates."
    method_option "reverse", aliases: "-r", type: :boolean, desc: "Reverse the order of the sort."
    def entries(collection); end

    desc "information COLLECTION", "Retrieves detailed information about a collection."
    method_option "csv", aliases: "-c", type: :boolean, desc: "Output in CSV format."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify collection via ID instead of name."
    def information(collection); end
    map %w[details] => :information

    desc "remove COLLECTION TWEET_ID [TWEET_ID...]", "Remove tweets from a collection."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify collection via ID instead of name."
    def remove(collection, tweet_id, *tweet_ids); end

    desc "update COLLECTION", "Update a collection's metadata."
    method_option "id", aliases: "-i", type: :boolean, desc: "Specify collection via ID instead of name."
    method_option "name", type: :string, desc: "The new name for the collection."
    method_option "description", type: :string, desc: "The new description for the collection."
    method_option "url", aliases: "-u", type: :string, desc: "A fully-qualified URL to associate with this collection."
    def update(collection); end
  end
end
