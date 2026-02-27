module T
  module RequestableAPI
    module TweetNormalization
    private

      def extract_tweets(value)
        return value if value.is_a?(Array)
        return value.fetch("statuses", []) if value["statuses"].is_a?(Array)

        users_by_id = index_items_by_id(value.dig("includes", "users"))
        places_by_id = index_items_by_id(value.dig("includes", "places"))
        return value["data"].map { |tweet| normalize_v2_tweet(tweet, users_by_id, places_by_id) } if value["data"].is_a?(Array)
        return [normalize_v2_tweet(value["data"], users_by_id, places_by_id)] if value["data"].is_a?(Hash)

        []
      end

      def normalize_v2_tweet(tweet, users_by_id, places_by_id)
        return tweet if tweet.is_a?(Hash) && tweet.key?("user")

        object = build_v2_tweet_core(tweet)
        apply_v2_tweet_entities(object, tweet)
        apply_v2_tweet_metrics(object, tweet)
        apply_v2_tweet_author(object, tweet, users_by_id)
        apply_v2_tweet_geo(object, tweet, places_by_id)
        object
      end

      def build_v2_tweet_core(tweet)
        object = {}
        apply_v2_id(object, tweet)
        text = tweet["full_text"] || tweet["text"]
        if text
          object["text"] = text
          object["full_text"] = text
        end
        object["created_at"] = tweet["created_at"] if tweet["created_at"]
        object["source"] = tweet["source"] if tweet["source"]
        object
      end

      def apply_v2_tweet_entities(object, tweet)
        return unless tweet["entities"]

        object["entities"] = tweet["entities"]
        object["uris"] = tweet.dig("entities", "urls") if tweet.dig("entities", "urls")
      end

      def apply_v2_tweet_metrics(object, tweet)
        return unless tweet["public_metrics"].is_a?(Hash)

        metrics = tweet["public_metrics"]
        object["retweet_count"] = metrics["retweet_count"] if metrics.key?("retweet_count")
        object["favorite_count"] = metrics["like_count"] if metrics.key?("like_count")
      end

      def apply_v2_tweet_author(object, tweet, users_by_id)
        author_id = tweet["author_id"]
        object["user"] = normalize_v2_user(users_by_id[author_id] || {"id" => author_id, "username" => author_id}) if author_id
      end

      def apply_v2_tweet_geo(object, tweet, places_by_id)
        geo = tweet["geo"]
        return unless geo.is_a?(Hash)

        place_id = geo["place_id"]
        object["place"] = places_by_id[place_id] if place_id && places_by_id[place_id]
        coords = geo.dig("coordinates", "coordinates")
        object["geo"] = {"type" => "Point", "coordinates" => coords} if coords.is_a?(Array) && coords.size == 2 && !place_id
      end

      def extract_ids(response)
        data = response["data"]
        return [] unless data.is_a?(Array)

        data.filter_map { |entry| value_id(entry) }
      end

      def index_items_by_id(values)
        Array(values).each_with_object({}) do |entry, memo|
          id = value_id(entry)
          memo[id] = entry if id
        end
      end
    end
  end
end
