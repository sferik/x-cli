module T
  module RequestableAPI
    module UserEndpoints
      def x_verify_credentials
        user_hash(current_user)
      end

      def x_user(user, _opts = {})
        user_hash(resolve_user(user))
      end

      # Look up users by identifier (Integer) or username (String), in parallel batches
      def x_users(users)
        client.find_users(Array(users).flatten.compact).collect { |user| user_hash(user) }
      end

      # Search users one page at a time, as the users command collects pages
      def x_user_search(query, page:)
        searches = (@requestable_api_user_searches ||= {})
        search = (searches[query] ||= client.search_users(query.to_s))
        Array(search.page(page.to_i - 1)&.items).collect { |user| user_hash(user) }
      end

      def x_friendship?(user1, user2)
        user_reference(user1).follows?(user_reference(user2))
      end

      def x_friend_ids(user = nil)
        user_reference(user).following.ids
      end

      def x_follower_ids(user = nil)
        user_reference(user).followers.ids
      end
    end
  end
end
