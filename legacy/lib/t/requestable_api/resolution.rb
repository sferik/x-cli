module T
  module RequestableAPI
    # Turn the identifiers and usernames the commands receive into resources of the x gem
    module Resolution
    private

      def current_user
        client.current_user
      end

      # Look up a user, so the result holds every field
      def resolve_user(entry)
        entry.is_a?(X::User) ? entry : client.find_user!(entry)
      end

      # Refer to a user without a request when only the identifier is needed, looking a username up
      def user_reference(entry)
        return current_user if entry.nil?

        entry.is_a?(String) ? client.find_user!(entry) : X::User.from_id(entry, client:)
      end

      # Find a list by name or slug among the lists a user owns
      def resolve_list(owner, list_name)
        desired = slugify_list_name(list_name)
        list = user_reference(owner).owned_lists.detect do |candidate|
          candidate.name.to_s.casecmp?(list_name.to_s) || slugify_list_name(candidate.name) == desired
        end
        list || raise(X::ResourceNotFound.new("Could not find list #{list_name}"))
      end

      def mutate_users(users)
        Array(users).flatten.filter_map do |entry|
          user = resolve_user(entry)
          yield user
          user_hash(user)
        rescue X::NotFound, X::Forbidden, X::ResourceNotFound => e
          warn "@#{entry}: #{e.message}"
          nil
        end
      end
    end
  end
end
