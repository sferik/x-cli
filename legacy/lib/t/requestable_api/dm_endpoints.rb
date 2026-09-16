module T
  module RequestableAPI
    module DMEndpoints
      def x_direct_messages_received(opts = {})
        fetch_direct_messages(false, opts)
      end

      def x_direct_messages_sent(opts = {})
        fetch_direct_messages(true, opts)
      end

      def x_direct_message(id)
        message = client.find_direct_message(id)
        return if message.nil?

        present_direct_messages([message], current_user).first
      rescue X::NotFound
        nil
      end

      def x_create_direct_message_event(recipient, message)
        recipient = user_hash(resolve_user(recipient)) unless recipient.is_a?(Hash)
        sent = client.create_direct_message(recipient["id"], message.to_s)
        {"id" => sent&.id, "text" => message.to_s, "full_text" => message.to_s,
         "recipient_id" => recipient["id"], "recipient" => recipient}
      end

      def x_destroy_direct_message(*direct_message_ids)
        normalize_id_list(direct_message_ids).each { |id| client.delete_direct_message(id) }
        true
      end

    private

      def fetch_direct_messages(sent, opts)
        me = current_user
        messages = client.direct_messages(event_types: "MessageCreate").lazy
        messages = messages.select { |message| message.from?(me).eql?(sent) }
        messages = messages.select { |message| message.id <= opts[:until_id].to_i } if opts[:until_id]
        present_direct_messages(messages.first(result_count(opts)), me)
      end

      # Present messages with their other participants, looking up the ones the response did not expand in one batch
      def present_direct_messages(messages, user)
        peers = X::User.hydrate_all(messages.filter_map { |message| message.peer(user) }, client:).to_h { |peer| [peer.id, peer] }
        messages.collect do |message|
          peer = message.peer(user)
          dm_hash(message, peer&.id, peers[peer&.id])
        end
      end
    end
  end
end
