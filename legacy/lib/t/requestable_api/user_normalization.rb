module T
  module RequestableAPI
    module UserNormalization
    private

      def extract_users(value)
        return value if value.is_a?(Array)
        return value.fetch("users", []) if value["users"].is_a?(Array)

        users = value["data"]
        includes_tweets = index_items_by_id(value.dig("includes", "tweets"))
        return users.map { |user| normalize_user_with_pinned_status(user, includes_tweets) } if users.is_a?(Array)
        return [normalize_user_with_pinned_status(users, includes_tweets)] if users.is_a?(Hash)

        extract_bare_v1_user(value)
      end

      def extract_bare_v1_user(value)
        return [value] if value.is_a?(Hash) && (value.key?("screen_name") || value.key?("id"))

        []
      end

      def normalize_user_with_pinned_status(user, includes_tweets)
        normalized = normalize_v2_user(user || {})
        pinned_id = user["pinned_tweet_id"]
        normalized["status"] = normalize_v2_tweet(includes_tweets[pinned_id], {}, {}) if pinned_id && includes_tweets[pinned_id]
        normalized
      end

      def normalize_v2_user(user)
        return user if user.is_a?(Hash) && user.key?("screen_name")

        object = build_v2_user_core(user)
        apply_v2_user_metrics(object, user)
        object
      end

      def build_v2_user_core(user)
        object = {}
        apply_v2_id(object, user)
        username = user["username"] || user["screen_name"]
        if username
          object["screen_name"] = username
          object["username"] = username
        end
        %w[created_at name verified protected description location url].each do |field|
          object[field] = user[field] if user.key?(field)
        end
        object
      end

      def apply_v2_user_metrics(object, user)
        return unless user["public_metrics"].is_a?(Hash)

        metrics = user["public_metrics"]
        object["statuses_count"] = metrics["tweet_count"] if metrics.key?("tweet_count")
        if metrics.key?("like_count")
          object["favourites_count"] = metrics["like_count"]
          object["favorites_count"] = metrics["like_count"]
        end
        object["listed_count"] = metrics["listed_count"] if metrics.key?("listed_count")
        object["friends_count"] = metrics["following_count"] if metrics.key?("following_count")
        object["followers_count"] = metrics["followers_count"] if metrics.key?("followers_count")
      end
    end
  end
end
