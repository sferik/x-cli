require "x"
require "retriable"

module T
  module Collectable
    MAX_NUM_RESULTS = 200
    MAX_PAGE = 51

    def collect_with_until_id(collection = [], until_id = nil, &)
      tweets = Retriable.retriable(tries: 3, on: X::Error, base_interval: 0) do
        yield(until_id)
      end
      return collection if tweets.nil?

      collection += tweets
      tweets.empty? ? collection.flatten : collect_with_until_id(collection, tweets.last["id"] - 1, &)
    end

    def collect_with_count(count)
      opts = {}
      opts[:count] = MAX_NUM_RESULTS
      collect_with_until_id do |until_id|
        opts[:until_id] = until_id unless until_id.nil?
        opts[:count] = count unless count >= MAX_NUM_RESULTS
        if count.positive?
          tweets = yield opts
          count -= tweets.length
          tweets
        end
      end.flatten.compact
    end

    def collect_with_page(collection = ::Set.new, page = 1, previous = nil, &)
      tweets = Retriable.retriable(tries: 3, on: X::Error, base_interval: 0) do
        yield page
      end
      return collection if tweets.nil? || tweets == previous || page >= MAX_PAGE

      collection += tweets
      tweets.empty? ? collection.flatten : collect_with_page(collection, page + 1, tweets, &)
    end
  end
end
