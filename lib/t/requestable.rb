require 'twitter'

module T
  module Requestable
  private

    def client
      return @client if @client

      @rcfile.path = options['profile'] if options['profile']
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key        = @rcfile.active_consumer_key
        config.consumer_secret     = @rcfile.active_consumer_secret
        config.access_token        = @rcfile.active_token
        config.access_token_secret = @rcfile.active_secret
      end
    end
  end
end
