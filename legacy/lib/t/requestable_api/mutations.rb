module T
  module RequestableAPI
    module Mutations
      def x_block(users)
        mutate_users(users) { |target_id, me_id| t_post_v2_json("users/#{me_id}/blocking", target_user_id: target_id) }
      end

      def x_unblock(users)
        mutate_users(users) { |target_id, me_id| t_delete_v2("users/#{me_id}/blocking/#{target_id}") }
      end

      def x_mute(users)
        mutate_users(users) { |target_id, me_id| t_post_v2_json("users/#{me_id}/muting", target_user_id: target_id) }
      end

      def x_unmute(users)
        mutate_users(users) { |target_id, me_id| t_delete_v2("users/#{me_id}/muting/#{target_id}") }
      end

      def x_follow(users)
        mutate_users(users) { |target_id, me_id| t_post_v2_json("users/#{me_id}/following", target_user_id: target_id) }
      end

      def x_unfollow(users)
        mutate_users(users) { |target_id, me_id| t_delete_v2("users/#{me_id}/following/#{target_id}") }
      end

      def x_report_spam(users)
        Array(users).flatten.map do |entry|
          resolved_user = resolve_user(entry)
          key = numeric_identifier?(entry) ? :user_id : :screen_name
          t_post_v1_form("users/report_spam.json", {key => (key == :user_id ? resolved_user["id"] : resolved_user["screen_name"])})
          resolved_user
        end
      end

      def x_muted_ids
        ids = []
        params = {max_results: "1000", "user.fields": "id,username"}
        me_id = current_user_id
        MAX_PAGE.times do
          response = t_get_v2("users/#{me_id}/muting", params)
          ids.concat(extract_ids(response))
          token = response.dig("meta", "next_token")
          break if token.nil?

          params = params.merge(pagination_token: token)
        end
        ids
      end

      def x_favorite(status_ids)
        me_id = current_user_id
        tweets = normalize_id_list(status_ids).map do |id|
          t_post_v2_json("users/#{me_id}/likes", tweet_id: id)
          {"id" => id.to_i, "id_str" => id.to_s}
        end
        single_or_array(status_ids, tweets)
      end

      def x_unfavorite(status_ids)
        me_id = current_user_id
        tweets = normalize_id_list(status_ids).map do |id|
          t_delete_v2("users/#{me_id}/likes/#{id}")
          {"id" => id.to_i, "id_str" => id.to_s}
        end
        single_or_array(status_ids, tweets)
      end

      def x_retweet(status_ids)
        me_id = current_user_id
        tweets = normalize_id_list(status_ids).map do |id|
          t_post_v2_json("users/#{me_id}/retweets", tweet_id: id)
          {"id" => id.to_i, "id_str" => id.to_s}
        end
        single_or_array(status_ids, tweets)
      end

      def x_destroy_status(status_ids)
        statuses = normalize_id_list(status_ids).map do |id|
          t_delete_v2("tweets/#{id}")
          {"id" => id.to_i, "id_str" => id.to_s}
        end
        single_or_array(status_ids, statuses)
      end
    end
  end
end
