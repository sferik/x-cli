require "x"
require "t/requestable_api"

module T
  module Requestable
    include T::RequestableAPI

  private

    def client
      return @client if @client

      @rcfile.path = options["profile"] if options["profile"]
      credentials = {
        api_key: @rcfile.active_consumer_key,
        api_key_secret: @rcfile.active_consumer_secret,
        access_token: @rcfile.active_token,
        access_token_secret: @rcfile.active_secret,
      }
      # The commands retry failed requests themselves
      @client = X::Client.new(**credentials, max_retries: 0)
    end
  end
end
