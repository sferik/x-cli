module T
  module RequestableAPI
    module ListNormalization
    private

      def extract_lists(value)
        return value if value.is_a?(Array)
        return value.fetch("lists", []) if value["lists"].is_a?(Array)

        users_by_id = index_items_by_id(value.dig("includes", "users"))
        data = value["data"]
        return [] unless data.is_a?(Array)

        data.map { |list| normalize_v2_list(list, users_by_id) }
      end

      def normalize_v2_list(list, users_by_id)
        return list if list.key?("slug") || list.key?("full_name")

        object = build_v2_list_core(list)
        apply_v2_list_mode(object, list)
        apply_v2_list_owner(object, list, users_by_id)
        object
      end

      def build_v2_list_core(list)
        object = {}
        apply_v2_id(object, list)
        apply_v2_list_slug(object, list)
        %w[created_at description].each { |f| object[f] = list[f] if list[f] }
        object["member_count"] = list["member_count"] if list.key?("member_count")
        object["subscriber_count"] = list["subscriber_count"] || list["follower_count"]
        object
      end

      def apply_v2_id(object, source)
        id = value_id(source)
        return unless id

        object["id"] = id.to_i
        object["id_str"] = id.to_s
      end

      def apply_v2_list_slug(object, list)
        slug = list["slug"] || list["name"]
        return unless slug

        object["slug"] = slug
        object["name"] = slug
      end

      def apply_v2_list_mode(object, list)
        if list.key?("mode")
          object["mode"] = list["mode"]
        elsif list.key?("private")
          object["mode"] = list["private"] ? "private" : "public"
        end
      end

      def apply_v2_list_owner(object, list, users_by_id)
        id = value_id(list)
        slug = object["slug"]
        owner_id = list["owner_id"]
        if owner_id && users_by_id[owner_id]
          owner = normalize_v2_user(users_by_id[owner_id])
          object["user"] = owner
          owner_name = owner["screen_name"]
          object["full_name"] = "@#{owner_name}/#{slug}" if owner_name && slug
        end
        object["uri"] = "https://x.com/i/lists/#{id}" if id
      end
    end
  end
end
