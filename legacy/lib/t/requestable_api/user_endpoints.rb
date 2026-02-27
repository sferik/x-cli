module T
  module RequestableAPI
    module UserEndpoints
      def x_verify_credentials
        extract_users(t_get_v2("users/me", user_lookup_params)).first || {}
      rescue X::Error
        t_get_v1("account/verify_credentials.json")
      end

      def x_user(user = nil, _opts = {}, &)
        if block_given? && user.nil?
          @requestable_api_before_request&.call
          x_home_timeline(count: 100).each(&)
          return
        end

        fetch_single_user(user)
      rescue X::ServiceUnavailable
        t_get_v1("users/show.json", screen_name: strip_at(user.to_s))
      end

      def x_users(users)
        users = Array(users).flatten.compact
        return [] if users.empty?

        ids, names = users.partition { |entry| numeric_identifier?(entry) }
        results = []
        ids.each_slice(100) do |chunk|
          results.concat(extract_users(t_get_v2("users", user_lookup_params.merge(ids: chunk.join(",")))))
        end
        names.each_slice(100) do |chunk|
          results.concat(extract_users(t_get_v2("users/by", user_lookup_params.merge(usernames: chunk.map { |name| strip_at(name) }.join(",")))))
        end
        results
      end

      def x_user_search(query, page:)
        page = page.to_i
        return [] if page > 1 && @requestable_api_user_search_tokens[[query, page - 1]].to_s.empty?

        params = {
          query: query.to_s,
          max_results: "100",
          "user.fields": V2_USER_FIELDS,
          expansions: V2_USER_EXPANSIONS,
          "tweet.fields": V2_TWEET_FIELDS,
        }
        params[:next_token] = @requestable_api_user_search_tokens[[query, page - 1]] if page > 1
        response = t_get_v2("users/search", params)
        @requestable_api_user_search_tokens[[query, page]] = response.dig("meta", "next_token")
        extract_users(response)
      end

      def x_friendship?(user1, user2)
        user1_id = resolve_user_id(user1)
        user2_id = resolve_user_id(user2)
        fetch_relationship_ids(user1_id, "following").include?(user2_id.to_s)
      end

      def x_friend_ids(user = nil)
        user_id = user.nil? ? current_user_id : resolve_user_id(user)
        fetch_relationship_ids(user_id, "following")
      end

      def x_follower_ids(user = nil)
        user_id = user.nil? ? current_user_id : resolve_user_id(user)
        fetch_relationship_ids(user_id, "followers")
      end

    private

      def fetch_single_user(user)
        response = if numeric_identifier?(user)
          t_get_v2("users/#{user}", user_lookup_params)
        else
          t_get_v2("users/by/username/#{strip_at(user)}", user_lookup_params)
        end
        extract_users(response).first || {}
      end
    end
  end
end
