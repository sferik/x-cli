module T
  module RequestableAPI
    module TweetEndpoints
      def x_retweets_of_me(opts = {})
        extract_tweets(t_get_v2("users/reposts_of_me", timeline_v2_params(opts)))
      end

      def x_retweeted_by_me(opts = {})
        x_retweets_of_me(opts)
      end

      def x_retweeted_by_user(user, opts = {})
        x_user_timeline(user, opts).select { |tweet| tweet["full_text"].to_s.start_with?("RT @") }
      end

      def x_retweeters_ids(tweet_id)
        ids = []
        params = {"user.fields": "id,username", max_results: "100"}
        MAX_PAGE.times do
          response = t_get_v2("tweets/#{tweet_id}/retweeted_by", params)
          ids.concat(extract_ids(response))
          token = response.dig("meta", "next_token")
          break if token.nil?

          params = params.merge(pagination_token: token)
        end
        ids
      end

      def x_status(status_id, _opts = {})
        extract_tweets(t_get_v2("tweets/#{status_id}", v2_tweet_params)).first || {}
      end

      def x_home_timeline(opts = {})
        me_id = current_user_id
        extract_tweets(t_get_v2("users/#{me_id}/timelines/reverse_chronological", timeline_v2_params(opts)))
      end

      def x_user_timeline(user, opts = {})
        user_id = resolve_user_id(user)
        extract_tweets(t_get_v2("users/#{user_id}/tweets", timeline_v2_params(opts)))
      end

      def x_mentions(opts = {})
        me_id = current_user_id
        extract_tweets(t_get_v2("users/#{me_id}/mentions", timeline_v2_params(opts)))
      end

      def x_favorites(user = nil, opts = {})
        if user.is_a?(Hash) && opts.empty?
          opts = user
          user = nil
        end
        user_id = user.nil? ? current_user_id : resolve_user_id(user)
        extract_tweets(t_get_v2("users/#{user_id}/liked_tweets", timeline_v2_params(opts)))
      end

      def x_search(query, opts = {})
        count = [opts.fetch(:count, MAX_SEARCH_RESULTS).to_i, MAX_SEARCH_RESULTS].min
        params = {
          query: query.to_s,
          max_results: count.to_s,
        }.merge(v2_tweet_params)
        params[:until_id] = opts[:max_id].to_s if opts[:max_id]
        params[:since_id] = opts[:since_id].to_s if opts[:since_id]
        extract_tweets(t_get_v2("tweets/search/recent", params))
      end

      def x_update(status, opts = {})
        body = {text: status.to_s}
        body[:reply] = {in_reply_to_tweet_id: opts[:in_reply_to_status_id].to_s} if opts[:in_reply_to_status_id]
        body[:media] = {media_ids: Array(opts[:media_ids]).map(&:to_s)} if opts[:media_ids]
        response = t_post_v2_json("tweets", body)
        id = value_id(response) || value_id(response["data"])
        {"id" => id.to_i, "id_str" => id.to_s, "text" => status.to_s,
         "full_text" => status.to_s, "user" => current_user}
      end

      def x_update_with_media(status, file, opts = {})
        media_id = upload_media(file)
        x_update(status, opts.merge(media_ids: [media_id]))
      end
    end
  end
end
