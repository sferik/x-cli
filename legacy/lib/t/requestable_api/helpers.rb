module T
  module RequestableAPI
    module Helpers
    private

      def normalize_id_list(ids)
        Array(ids).flatten.compact.map(&:to_s)
      end

      def single_or_array(input, values)
        input.is_a?(Array) ? values : values.first
      end

      def timeline_v2_params(opts)
        params = {
          "tweet.fields": V2_TWEET_FIELDS,
          expansions: V2_TWEET_EXPANSIONS,
          "user.fields": V2_USER_FIELDS,
          "place.fields": V2_PLACE_FIELDS,
        }
        count = opts[:count] || DEFAULT_NUM_RESULTS
        params[:max_results] = count.to_i.clamp(1, MAX_SEARCH_RESULTS).to_s
        excludes = build_v2_excludes(opts)
        params[:exclude] = excludes unless excludes.empty?
        params[:until_id] = opts[:max_id].to_s if opts[:max_id]
        params[:since_id] = opts[:since_id].to_s if opts[:since_id]
        params
      end

      def build_v2_excludes(opts)
        excludes = []
        excludes << "replies" if opts[:exclude_replies]
        excludes << "retweets" if opts.key?(:include_rts) && opts[:include_rts] == false
        excludes.join(",")
      end

      def user_lookup_params
        {
          "user.fields": V2_USER_FIELDS,
          expansions: V2_USER_EXPANSIONS,
          "tweet.fields": V2_TWEET_FIELDS,
        }
      end

      def list_lookup_params
        {
          "list.fields": V2_LIST_FIELDS,
          expansions: "owner_id",
          "user.fields": V2_USER_FIELDS,
        }
      end

      def v2_tweet_params
        {
          "tweet.fields": V2_TWEET_FIELDS,
          expansions: V2_TWEET_EXPANSIONS,
          "user.fields": V2_USER_FIELDS,
          "place.fields": V2_PLACE_FIELDS,
        }
      end

      def entity_like?(obj)
        obj.is_a?(Hash)
      end

      def value_id(value)
        return nil unless entity_like?(value)

        value["id_str"] || value["id"]&.to_s
      end

      def strip_at(value)
        value.to_s.delete_prefix("@")
      end

      def slugify_list_name(value)
        slug = value.to_s.downcase.gsub(/[^a-z0-9_]+/, "-")
        slug.gsub(/\A-+|-+\z/, "")
      end

      def numeric_identifier?(value)
        value.to_s.match?(/\A\d+\z/)
      end
    end
  end
end
