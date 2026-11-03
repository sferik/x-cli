module T
  module RequestableAPI
    module TweetEndpoints
      def x_retweets_of_me(opts = {})
        tweets(client.reposts_of_me(**cursor_params(opts)), opts)
      end

      def x_retweeted_by_me(opts = {})
        x_retweets_of_me(opts)
      end

      def x_retweeted_by_user(user, opts = {})
        posts = user_reference(user).posts(**cursor_params(opts))
        tweets(posts.lazy.select(&:repost?), opts)
      end

      def x_retweeters_ids(tweet_id)
        X::Post.from_id(tweet_id, client:).reposted_by.ids
      end

      def x_status(status_id, _opts = {})
        tweet_hash(client.find_post(status_id)) || {}
      end

      def x_home_timeline(opts = {})
        tweets(current_user.home_timeline(**cursor_params(opts)), opts)
      end

      def x_user_timeline(user, opts = {})
        tweets(user_reference(user).posts(**cursor_params(opts)), opts)
      end

      def x_mentions(opts = {})
        tweets(current_user.mentions(**cursor_params(opts)), opts)
      end

      def x_favorites(user = nil, opts = {})
        if user.is_a?(Hash) && opts.empty?
          opts = user
          user = nil
        end
        tweets(user_reference(user).liked_posts(**cursor_params(opts)), opts)
      end

      def x_search(query, opts = {})
        count = [opts.fetch(:count, MAX_RESULTS).to_i, MAX_RESULTS].min
        tweets(client.search_posts(query.to_s, **cursor_params(opts)), count:)
      end

      def x_update(status, opts = {})
        tweet_hash(client.create_post(status.to_s, **opts.slice(:reply_to, :media_ids)))
      rescue X::MissingResource
        {}
      end

      def x_update_with_media(status, file, opts = {})
        x_update(status, opts.merge(media_ids: [upload_media(file)]))
      end

    private

      def tweets(posts, opts)
        posts.first(result_count(opts)).collect { |post| tweet_hash(post) }
      end
    end
  end
end
