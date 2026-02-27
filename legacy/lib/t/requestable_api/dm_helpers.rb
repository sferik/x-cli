module T
  module RequestableAPI
    module DMHelpers
    private

      def direct_messages_for(sent, opts)
        count = opts.fetch(:count, 50).to_i.clamp(1, 50)
        payload = fetch_direct_messages_payload(count)
        me_id = current_user_id
        users_by_id = extract_dm_users_by_id(payload)
        events = filter_dm_events(extract_dm_events(payload), sent, me_id, opts)
        resolve_dm_peer_users(events, users_by_id, me_id, sent)
        events.map { |event| normalize_dm_event(event, users_by_id, me_id, sent) }
      end

      def filter_dm_events(events, sent, me_id, opts)
        filtered = events.select do |event|
          next false unless dm_event_type(event) == "messagecreate"

          sender_id = dm_sender_id(event)
          sent ? sender_id == me_id : sender_id != me_id
        end
        filtered = filter_dm_by_max_id(filtered, opts[:max_id]) if opts[:max_id]
        filtered
      end

      def filter_dm_by_max_id(events, max_id)
        max = max_id.to_i
        events.select { |event| dm_event_id(event).to_i <= max }
      end

      def resolve_dm_peer_users(events, users_by_id, me_id, sent)
        lookup_ids = events.map { |event| dm_peer_id(event, me_id, sent) }.reject(&:empty?).uniq - users_by_id.keys
        lookup_users_by_ids(lookup_ids).each do |user_data|
          id = value_id(user_data)
          users_by_id[id] = user_data if id
        end
      end

      def fetch_direct_messages_payload(count)
        t_get_v2("dm_events", dm_v2_params.merge(max_results: count.to_s))
      rescue X::Forbidden, X::NotFound
        t_get_v1("direct_messages/events/list.json", count: count.to_s)
      end

      def normalize_dm_event(event, users_by_id, my_id, sent)
        sender_id = dm_sender_id(event)
        peer_id = dm_peer_id(event, my_id, sent)
        recipient_id = if event["message_create"] || event[:message_create]
          dm_recipient_id(event)
        else
          peer_id
        end
        recipient_id = peer_id if recipient_id.to_s.empty?
        recipient = users_by_id[recipient_id.to_s] || {}

        {"id" => dm_event_id(event).to_i, "id_str" => dm_event_id(event).to_s,
         "text" => dm_text(event), "full_text" => dm_text(event),
         "created_at" => dm_time(event), "sender_id" => sender_id.to_i,
         "recipient_id" => recipient_id.to_i, "recipient" => recipient,
         "uris" => dm_urls(event)}
      end

      def dm_v2_params
        {
          event_types: "MessageCreate",
          "dm_event.fields": "id,sender_id,text,created_at,dm_conversation_id,urls",
          expansions: "sender_id,participant_ids",
          "user.fields": "id,username",
        }
      end

      def extract_dm_events(payload)
        events = payload["events"] || payload["data"] || []
        events.is_a?(Array) ? events : [events]
      end

      def extract_dm_users_by_id(payload)
        users_by_id = {}
        Array(payload.dig("includes", "users")).each do |user|
          id = value_id(user)
          users_by_id[id] = user if id
        end
        index_v1_users(payload["users"], users_by_id)
        users_by_id
      end

      def index_v1_users(users, target)
        if users.is_a?(Array)
          users.each do |user|
            id = value_id(user)
            target[id] = user if id
          end
        elsif users.is_a?(Hash)
          index_v1_users_hash(users, target)
        end
      end

      def index_v1_users_hash(users, target)
        users.each do |id, user|
          target[id.to_s] = user
          target[user["id_str"].to_s] = user if user.is_a?(Hash) && user["id_str"]
        end
      end
    end
  end
end
