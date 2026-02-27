module T
  module RequestableAPI
    module DMParsing
    private

      def dm_event_id(event)
        (event["id"] || event[:id] || "").to_s
      end

      def dm_event_type(event)
        value = event["type"] || event[:type] || event["event_type"] || event[:event_type] || "MessageCreate"
        value.to_s.downcase.delete("_")
      end

      def dm_sender_id(event)
        value = event.dig("message_create", "sender_id") ||
                event.dig(:message_create, :sender_id) || event["sender_id"] || event[:sender_id]
        value.to_s
      end

      def dm_recipient_id(event)
        value = event.dig("message_create", "target", "recipient_id") ||
                event.dig(:message_create, :target, :recipient_id)
        value.to_s
      end

      def dm_other_participant_id(event, my_id)
        conversation_id = event["dm_conversation_id"] || event[:dm_conversation_id]
        return nil if conversation_id.nil?

        conversation_id.to_s.split("-").find { |entry| entry != my_id.to_s }
      end

      def dm_peer_id(event, my_id, sent)
        sender = dm_sender_id(event)
        if event["message_create"] || event[:message_create]
          return sent ? dm_recipient_id(event) : sender
        end

        return dm_other_participant_id(event, my_id).to_s if sent
        return sender if sender != my_id.to_s

        dm_other_participant_id(event, my_id).to_s
      end

      def dm_text(event)
        value = event.dig("message_create", "message_data", "text") ||
                event.dig(:message_create, :message_data, :text) ||
                event["text"] || event[:text] || ""
        value.to_s
      end

      def dm_urls(event)
        event.dig("message_create", "message_data", "entities", "urls") ||
          event.dig(:message_create, :message_data, :entities, :urls) ||
          event["urls"] || event[:urls] || []
      end

      def dm_time(event)
        timestamp = event["created_timestamp"] || event[:created_timestamp]
        return Time.at(timestamp.to_i / 1000.0).utc if timestamp&.to_s&.match?(/\A\d+\z/)

        parse_dm_created_at(event)
      end

      def parse_dm_created_at(event)
        value = event["created_at"] || event[:created_at]
        return value if value.is_a?(Time)

        Time.parse(value.to_s).utc
      rescue ArgumentError
        Time.at(0).utc
      end
    end
  end
end
