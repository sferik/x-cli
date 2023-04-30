require 'thor'
require 'twitter'
require 't/rcfile'
require 't/requestable'
require 't/utils'

module T
  class Delete < Thor
    include T::Requestable
    include T::Utils

    check_unknown_options!

    def initialize(*)
      @rcfile = T::RCFile.instance
      super
    end

    desc 'block USER [USER...]', 'Unblock users.'
    method_option 'id', aliases: '-i', type: :boolean, desc: 'Specify input as Twitter user IDs instead of screen names.'
    method_option 'force', aliases: '-f', type: :boolean
    def block(user, *users)
      unblocked_users, number = fetch_users(users.unshift(user), options) do |users_to_unblock|
        client.unblock(users_to_unblock)
      end
      say "@#{@rcfile.active_profile[0]} unblocked #{pluralize(number, 'user')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} block #{unblocked_users.collect { |unblocked_user| "@#{unblocked_user.screen_name}" }.join(' ')}` to block."
    end

    desc 'dm [DIRECT_MESSAGE_ID] [DIRECT_MESSAGE_ID...]', 'Delete the last Direct Message sent.'
    method_option 'force', aliases: '-f', type: :boolean
    def dm(direct_message_id, *direct_message_ids)
      direct_message_ids.unshift(direct_message_id)
      require 't/core_ext/string'
      direct_message_ids.collect!(&:to_i)
      if options['force']
        client.destroy_direct_message(*direct_message_ids)
        say "@#{@rcfile.active_profile[0]} deleted #{direct_message_ids.size} direct message#{direct_message_ids.size == 1 ? '' : 's'}."
      else
        direct_message_ids.each do |direct_message_id_to_delete|
          direct_message = client.direct_message(direct_message_id_to_delete)
          if direct_message
            recipient = client.user(direct_message.recipient_id)
            next unless yes? "Are you sure you want to permanently delete the direct message to @#{recipient.screen_name}: \"#{direct_message.text}\"? [y/N]"

            client.destroy_direct_message(direct_message_id_to_delete)
            say "@#{@rcfile.active_profile[0]} deleted the direct message sent to @#{recipient.screen_name}: \"#{direct_message.text}\""
          end
        end
      end
    end
    map %w[d m] => :dm

    desc 'favorite TWEET_ID [TWEET_ID...]', 'Delete favorites.'
    method_option 'force', aliases: '-f', type: :boolean
    def favorite(status_id, *status_ids)
      status_ids.unshift(status_id)
      require 't/core_ext/string'
      status_ids.collect!(&:to_i)
      if options['force']
        tweets = client.unfavorite(status_ids)
        tweets.each do |status|
          say "@#{@rcfile.active_profile[0]} unfavorited @#{status.user.screen_name}'s status: \"#{status.full_text}\""
        end
      else
        status_ids.each do |status_id_to_unfavorite|
          status = client.status(status_id_to_unfavorite, include_my_retweet: false)
          next unless yes? "Are you sure you want to remove @#{status.user.screen_name}'s status: \"#{status.full_text}\" from your favorites? [y/N]"

          client.unfavorite(status_id_to_unfavorite)
          say "@#{@rcfile.active_profile[0]} unfavorited @#{status.user.screen_name}'s status: \"#{status.full_text}\""
        end
      end
    end
    map %w[fave favourite] => :favorite

    desc 'list LIST', 'Delete a list.'
    method_option 'force', aliases: '-f', type: :boolean
    method_option 'id', aliases: '-i', type: :boolean, desc: 'Specify list via ID instead of slug.'
    def list(list)
      if options['id']
        require 't/core_ext/string'
        list = list.to_i
      end
      list = client.list(list)
      return if !options['force'] && !(yes? "Are you sure you want to permanently delete the list \"#{list.name}\"? [y/N]")
      client.destroy_list(list)
      say "@#{@rcfile.active_profile[0]} deleted the list \"#{list.name}\"."
    end

    desc 'mute USER [USER...]', 'Unmute users.'
    method_option 'id', aliases: '-i', type: :boolean, desc: 'Specify input as Twitter user IDs instead of screen names.'
    method_option 'force', aliases: '-f', type: :boolean
    def mute(user, *users)
      unmuted_users, number = fetch_users(users.unshift(user), options) do |users_to_unmute|
        client.unmute(users_to_unmute)
      end
      say "@#{@rcfile.active_profile[0]} unmuted #{pluralize(number, 'user')}."
      say
      say "Run `#{File.basename($PROGRAM_NAME)} mute #{unmuted_users.collect { |unmuted_user| "@#{unmuted_user.screen_name}" }.join(' ')}` to mute."
    end

    desc 'account SCREEN_NAME [CONSUMER_KEY]', 'delete account or consumer key from t'
    def account(account, key = nil)
      if key && @rcfile.profiles[account].keys.size > 1
        @rcfile.delete_key(account, key)
      else
        @rcfile.delete_profile(account)
      end
    end

    desc 'status TWEET_ID [TWEET_ID...]', 'Delete Tweets.'
    method_option 'force', aliases: '-f', type: :boolean
    def status(status_id, *status_ids)
      status_ids.unshift(status_id)
      require 't/core_ext/string'
      status_ids.collect!(&:to_i)
      if options['force']
        tweets = client.destroy_status(status_ids, trim_user: true)
        tweets.each do |status|
          say "@#{@rcfile.active_profile[0]} deleted the Tweet: \"#{status.full_text}\""
        end
      else
        status_ids.each do |status_id_to_delete|
          status = client.status(status_id_to_delete, include_my_retweet: false)
          next unless yes? "Are you sure you want to permanently delete @#{status.user.screen_name}'s status: \"#{status.full_text}\"? [y/N]"

          client.destroy_status(status_id_to_delete, trim_user: true)
          say "@#{@rcfile.active_profile[0]} deleted the Tweet: \"#{status.full_text}\""
        end
      end
    end
    map %w[post tweet update] => :status
  end
end
