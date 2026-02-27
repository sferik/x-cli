module T
  module RequestableAPI
    module ListEndpoints
      def x_lists(user = nil)
        user_id = user.nil? ? current_user_id : resolve_user_id(user)
        collect_owned_lists(user_id)
      end

      def x_list(owner_or_id, list_name = nil)
        list_id = if list_name.nil?
          numeric_identifier?(owner_or_id) ? owner_or_id.to_s : resolve_list_id(current_user_id, owner_or_id.to_s)
        else
          owner_id = numeric_identifier?(owner_or_id) ? owner_or_id.to_s : resolve_user_id(owner_or_id)
          resolve_list_id(owner_id, list_name.to_s)
        end
        extract_lists(t_get_v2("lists/#{list_id}", list_lookup_params)).first || {}
      end

      def x_create_list(name, opts = {})
        body = {
          name: name.to_s,
          description: opts[:description].to_s,
          private: opts[:mode].to_s == "private",
        }
        extract_lists(t_post_v2_json("lists", body)).first || {}
      end

      def x_destroy_list(list)
        list_id = entity_like?(list) ? value_id(list) : list.to_s
        t_delete_v2("lists/#{list_id}")
        true
      end

      def x_add_list_members(list_name, users)
        list_id = resolve_list_id(current_user_id, list_name.to_s)
        Array(users).flatten.each do |entry|
          t_post_v2_json("lists/#{list_id}/members", user_id: resolve_user_id(entry))
        end
        true
      end

      def x_remove_list_members(list_name, users)
        list_id = resolve_list_id(current_user_id, list_name.to_s)
        Array(users).flatten.each do |entry|
          t_delete_v2("lists/#{list_id}/members/#{resolve_user_id(entry)}")
        end
        true
      end

      def x_list_member?(owner, list_name, user)
        owner_id = numeric_identifier?(owner) ? owner.to_s : resolve_user_id(owner)
        list_id = resolve_list_id(owner_id, list_name.to_s)
        user_id = resolve_user_id(user)
        fetch_list_member_ids(list_id).include?(user_id.to_s)
      end

      def x_list_members(owner, list_name)
        owner_id = numeric_identifier?(owner) ? owner.to_s : resolve_user_id(owner)
        list_id = resolve_list_id(owner_id, list_name)
        lookup_users_by_ids(fetch_list_member_ids(list_id))
      end

      def x_list_timeline(owner, list_name, opts = {})
        owner_id = numeric_identifier?(owner) ? owner.to_s : resolve_user_id(owner)
        list_id = resolve_list_id(owner_id, list_name)
        extract_tweets(t_get_v2("lists/#{list_id}/tweets", timeline_v2_params(opts)))
      end
    end
  end
end
