module T
  module RequestableAPI
    module Mutations
      def x_block(users)
        mutate_users(users) { |user| client.block(user) }
      end

      def x_unblock(users)
        mutate_users(users) { |user| client.unblock(user) }
      end

      def x_mute(users)
        mutate_users(users) { |user| client.mute(user) }
      end

      def x_unmute(users)
        mutate_users(users) { |user| client.unmute(user) }
      end

      def x_follow(users)
        mutate_users(users) { |user| client.follow(user) }
      end

      def x_unfollow(users)
        mutate_users(users) { |user| client.unfollow(user) }
      end

      def x_report_spam(users)
        Array(users).flatten.collect do |entry|
          user = resolve_user(entry)
          form = entry.is_a?(Integer) ? {user_id: user.id} : {screen_name: user.username}
          v1_client.post("users/report_spam.json", form:)
          user_hash(user)
        end
      end

      def x_blocked_ids
        current_user.blocking.ids
      end

      def x_muted_ids
        current_user.muting.ids
      end

      def x_favorite(status_ids)
        act_on_posts(status_ids) { |id| client.like(id) }
      end

      def x_unfavorite(status_ids)
        act_on_posts(status_ids) { |id| client.unlike(id) }
      end

      def x_retweet(status_ids)
        act_on_posts(status_ids) { |id| client.repost(id) }
      end

      def x_destroy_status(status_ids)
        act_on_posts(status_ids) { |id| client.delete_post(id) }
      end

    private

      def act_on_posts(status_ids)
        results = normalize_id_list(status_ids).collect do |id|
          yield id
          {"id" => id.to_i, "id_str" => id}
        end
        single_or_array(status_ids, results)
      end
    end
  end
end
