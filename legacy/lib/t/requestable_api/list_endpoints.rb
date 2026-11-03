module T
  module RequestableAPI
    module ListEndpoints
      def x_lists(user = nil)
        user_reference(user).owned_lists.collect { |list| list_hash(list) }
      end

      def x_list(owner_or_id, list_name = nil)
        list = if list_name.nil? && owner_or_id.is_a?(Integer)
          client.find_list!(owner_or_id)
        elsif list_name.nil?
          resolve_list(nil, owner_or_id)
        else
          resolve_list(owner_or_id, list_name)
        end
        list_hash(list)
      end

      def x_create_list(name, opts = {})
        list = client.create_list(name.to_s, description: opts[:description].to_s, private: opts[:mode].to_s == "private")
        list_hash(list)
      rescue X::MissingResource
        {}
      end

      def x_destroy_list(list)
        client.delete_list(list.is_a?(Hash) ? list["id"] : list)
      end

      def x_add_list_members(list_name, users)
        list = resolve_list(nil, list_name)
        Array(users).flatten.each { |entry| list.add_member(user_reference(entry)) }
        true
      end

      def x_remove_list_members(list_name, users)
        list = resolve_list(nil, list_name)
        Array(users).flatten.each { |entry| list.remove_member(user_reference(entry)) }
        true
      end

      def x_list_member?(owner, list_name, user)
        resolve_list(owner, list_name).member?(user_reference(user))
      end

      def x_list_members(owner, list_name)
        resolve_list(owner, list_name).members.collect { |member| user_hash(member) }
      end

      def x_list_timeline(owner, list_name, opts = {})
        tweets(resolve_list(owner, list_name).posts(**cursor_params(opts)), opts)
      end
    end
  end
end
