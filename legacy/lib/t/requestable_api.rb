# frozen_string_literal: true

require "x"

require_relative "requestable_api/helpers"
require_relative "requestable_api/http"
require_relative "requestable_api/presenters"
require_relative "requestable_api/resolution"
require_relative "requestable_api/user_endpoints"
require_relative "requestable_api/tweet_endpoints"
require_relative "requestable_api/mutations"
require_relative "requestable_api/dm_endpoints"
require_relative "requestable_api/list_endpoints"
require_relative "requestable_api/account_endpoints"

module T
  # Adapts the object layer of the x gem to the hashes the command classes print
  module RequestableAPI
    include Helpers
    include HTTP
    include Presenters
    include Resolution
    include UserEndpoints
    include TweetEndpoints
    include Mutations
    include DMEndpoints
    include ListEndpoints
    include AccountEndpoints

    BASE_URL = "https://api.twitter.com"
    BASE_URL_V1 = "#{BASE_URL}/1.1/".freeze

    DEFAULT_NUM_RESULTS = 20
    MAX_RESULTS = 100
  end
end
