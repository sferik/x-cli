ENV["THOR_COLUMNS"] = "80"

require "simplecov"
require "coveralls"

SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter, Coveralls::SimpleCov::Formatter]

SimpleCov.start do
  add_filter "/spec"
  minimum_coverage(99.18)
end

require "t"
require "json"
require "readline"
require "rspec"
require "timecop"
require "webmock/rspec"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    stub_post("/oauth2/token").with(body: "grant_type=client_credentials").to_return(body: fixture("bearer_token.json"), headers: {content_type: "application/json; charset=utf-8"})
  end
end

def a_delete(path, endpoint = "https://api.twitter.com")
  a_request(:delete, endpoint + path)
end

def a_get(path, endpoint = "https://api.twitter.com")
  a_request(:get, endpoint + path)
end

def a_post(path, endpoint = "https://api.twitter.com")
  a_request(:post, endpoint + path)
end

def a_put(path, endpoint = "https://api.twitter.com")
  a_request(:put, endpoint + path)
end

def stub_delete(path, endpoint = "https://api.twitter.com")
  stub_request(:delete, endpoint + path)
end

def stub_get(path, endpoint = "https://api.twitter.com")
  stub_request(:get, endpoint + path)
end

def stub_post(path, endpoint = "https://api.twitter.com")
  stub_request(:post, endpoint + path)
end

def stub_put(path, endpoint = "https://api.twitter.com")
  stub_request(:put, endpoint + path)
end

def project_path
  File.expand_path("..", __dir__)
end

def fixture_path
  File.expand_path("fixtures", __dir__)
end

def fixture(file)
  File.new("#{fixture_path}/#{file}")
end

def tweet_from_fixture(file)
  Twitter::Tweet.new(JSON.parse(fixture(file).read, symbolize_names: true))
end
