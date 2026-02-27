module T
  module RequestableAPI
    module Resolution
    private

      def mutate_users(users)
        me_id = current_user_id
        Array(users).flatten.map do |entry|
          resolved_user = resolve_user(entry)
          yield resolved_user["id"].to_s, me_id
          resolved_user
        end
      end

      def current_user
        @current_user ||= x_verify_credentials
      end

      def current_user_id
        value_id(current_user).to_s
      end

      def resolve_user(entry)
        return current_user if entry.nil?
        return entry if entity_like?(entry)
        return x_user(entry.to_s) if numeric_identifier?(entry)

        x_user(strip_at(entry.to_s))
      end

      def resolve_user_id(entry)
        return current_user_id if entry.nil?
        return value_id(entry).to_s if entity_like?(entry)

        numeric_identifier?(entry) ? entry.to_s : value_id(x_user(strip_at(entry.to_s))).to_s
      end

      def resolve_list_id(owner_id, list_name)
        desired = slugify_list_name(list_name)
        lists = collect_owned_lists(owner_id)
        matched = lists.find do |list|
          slug = (list["slug"] || list["name"]).to_s
          slug.casecmp?(list_name.to_s) || slugify_list_name(slug) == desired
        end
        (value_id(matched) || list_name).to_s
      end

      def fetch_relationship_ids(user_id, relationship)
        endpoint = relationship == "followers" ? "users/#{user_id}/followers" : "users/#{user_id}/following"
        params = {max_results: "1000", "user.fields": "id,username"}
        ids = []
        MAX_PAGE.times do
          response = t_get_v2(endpoint, params)
          ids.concat(extract_ids(response))
          token = response.dig("meta", "next_token")
          break if token.nil?

          params = params.merge(pagination_token: token)
        end
        ids
      end

      def fetch_list_member_ids(list_id)
        params = {max_results: "100", "user.fields": "id,username"}
        ids = []
        MAX_PAGE.times do
          response = t_get_v2("lists/#{list_id}/members", params)
          ids.concat(extract_ids(response))
          token = response.dig("meta", "next_token")
          break if token.nil?

          params = params.merge(pagination_token: token)
        end
        ids
      end

      def collect_owned_lists(user_id)
        params = {
          max_results: "100",
          "list.fields": V2_LIST_FIELDS,
          expansions: "owner_id",
          "user.fields": V2_USER_FIELDS,
        }
        lists = []
        MAX_PAGE.times do
          response = t_get_v2("users/#{user_id}/owned_lists", params)
          lists.concat(extract_lists(response))
          token = response.dig("meta", "next_token")
          break if token.nil?

          params = params.merge(pagination_token: token)
        end
        lists
      end

      def lookup_users_by_ids(ids)
        ids = Array(ids).compact
        return [] if ids.empty?

        users = []
        ids.each_slice(100) do |chunk|
          users.concat(extract_users(t_get_v2("users", user_lookup_params.merge(ids: chunk.join(",")))))
        end
        users
      end
    end
  end
end
