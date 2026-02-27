module T
  module RequestableAPI
    module DMEndpoints
      def x_direct_messages_received(opts = {})
        direct_messages_for(false, opts)
      end

      def x_direct_messages_sent(opts = {})
        direct_messages_for(true, opts)
      end

      def x_direct_message(id)
        response = t_get_v2("dm_events/#{id}", dm_v2_params)
        events = extract_dm_events(response)
        events = [response["data"]] if events.empty? && response["data"].is_a?(Hash)
        return nil if events.empty?

        users_by_id = extract_dm_users_by_id(response)
        me_id = current_user_id
        normalize_dm_event(events.first, users_by_id, me_id, dm_sender_id(events.first) == me_id)
      rescue X::NotFound
        nil
      end

      def x_create_direct_message_event(recipient, message)
        target = entity_like?(recipient) ? recipient["id"].to_s : resolve_user_id(recipient)
        response = t_post_v2_json("dm_conversations/with/#{target}/messages", text: message.to_s)
        id = value_id(response) || value_id(response["data"])
        {"id" => id.to_i, "id_str" => id.to_s, "text" => message.to_s,
         "full_text" => message.to_s, "recipient_id" => target, "recipient" => x_user(target)}
      end

      def x_destroy_direct_message(*direct_message_ids)
        normalize_id_list(direct_message_ids.flatten).each do |id|
          t_delete_v2("dm_events/#{id}")
        end
        true
      end
    end
  end
end
