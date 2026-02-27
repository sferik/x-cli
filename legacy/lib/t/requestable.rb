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
      @client = X::Client.new(**credentials)
      setup_requestable_api!(credentials)
      @client
    end
  end
end
