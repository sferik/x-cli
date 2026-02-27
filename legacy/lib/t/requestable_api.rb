# frozen_string_literal: true

require "base64"
require "json"
require "time"
require "uri"

require_relative "requestable_api/helpers"
require_relative "requestable_api/http"
require_relative "requestable_api/tweet_normalization"
require_relative "requestable_api/user_normalization"
require_relative "requestable_api/list_normalization"
require_relative "requestable_api/resolution"
require_relative "requestable_api/dm_parsing"
require_relative "requestable_api/dm_helpers"
require_relative "requestable_api/user_endpoints"
require_relative "requestable_api/tweet_endpoints"
require_relative "requestable_api/mutations"
require_relative "requestable_api/dm_endpoints"
require_relative "requestable_api/list_endpoints"
require_relative "requestable_api/account_endpoints"

module T
  module RequestableAPI
    include Helpers
    include HTTP
    include TweetNormalization
    include UserNormalization
    include ListNormalization
    include Resolution
    include DMParsing
    include DMHelpers
    include UserEndpoints
    include TweetEndpoints
    include Mutations
    include DMEndpoints
    include ListEndpoints
    include AccountEndpoints

    BASE_URL = "https://api.twitter.com"
    BASE_URL_V1 = "#{BASE_URL}/1.1/".freeze
    BASE_URL_UPLOAD = "https://upload.twitter.com/1.1/"

    DEFAULT_NUM_RESULTS = 20
    MAX_SEARCH_RESULTS = 100
    MAX_PAGE = 51

    V2_TWEET_FIELDS = "author_id,created_at,entities,geo,id,in_reply_to_user_id,public_metrics,source,text"
    V2_USER_FIELDS = "created_at,description,id,location,name,protected,public_metrics,url,username,verified"
    V2_LIST_FIELDS = "created_at,description,follower_count,id,member_count,name,owner_id,private"
    V2_TWEET_EXPANSIONS = "author_id,geo.place_id"
    V2_USER_EXPANSIONS = "pinned_tweet_id"
    V2_PLACE_FIELDS = "contained_within,country,country_code,full_name,geo,id,name,place_type"

    FORM_HEADERS = {"Content-Type" => "application/x-www-form-urlencoded; charset=utf-8"}.freeze
    JSON_HEADERS = {"Content-Type" => "application/json; charset=utf-8"}.freeze

    def setup_requestable_api!(credentials)
      return if defined?(@requestable_api_setup) && @requestable_api_setup

      @requestable_api_setup = true
      @requestable_api_credentials = credentials
      @v1_client = X::Client.new(**credentials, base_url: BASE_URL_V1)
      @upload_client = X::Client.new(**credentials, base_url: BASE_URL_UPLOAD)
      @requestable_api_user_search_tokens = {}
      @requestable_api_before_request = nil
    end
  end
end
