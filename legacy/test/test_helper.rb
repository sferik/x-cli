ENV["THOR_COLUMNS"] = "80"
ENV.delete("NO_COLOR")

require "simplecov"

SimpleCov.start do
  enable_coverage :branch
  primary_coverage :line
  add_filter "/test"
  minimum_coverage line: 100, branch: 100
end

require "t"
require "json"
require "readline"
require "minitest/autorun"
require "minitest/mock"
require "minitest/strict"
require "timecop"
require "webmock/minitest"

V2_JSON_HEADERS = {content_type: "application/json; charset=utf-8"}.freeze

class TTestCase < Minitest::Test
  def setup
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

# V2 API helpers - use regex matching to avoid specifying query params
def stub_v2_get(path)
  stub_request(:get, v2_pattern(path))
end

def stub_v2_post(path)
  stub_request(:post, v2_pattern(path))
end

def stub_v2_delete(path)
  stub_request(:delete, v2_pattern(path))
end

def a_v2_get(path)
  a_request(:get, v2_pattern(path))
end

def a_v2_post(path)
  a_request(:post, v2_pattern(path))
end

def a_v2_delete(path)
  a_request(:delete, v2_pattern(path))
end

def v2_pattern(path)
  %r{api\.twitter\.com/2/#{Regexp.escape(path)}}
end

# A more specific pattern for multi-user lookup: matches /2/users? but NOT /2/users/me or /2/users/by/...
def stub_v2_users_lookup
  stub_request(:get, %r{api\.twitter\.com/2/users\?})
end

def a_v2_users_lookup
  a_request(:get, %r{api\.twitter\.com/2/users\?})
end

def v2_return(file)
  {body: fixture(file), headers: V2_JSON_HEADERS}
end

# Stub the current authenticated user (x_verify_credentials -> GET /2/users/me)
def stub_v2_current_user(fixture_file = "v2/sferik.json")
  stub_v2_get("users/me").to_return(v2_return(fixture_file))
end

# Stub a user lookup by username
def stub_v2_user_by_name(username, fixture_file = "v2/sferik.json")
  stub_v2_get("users/by/username/#{username}").to_return(v2_return(fixture_file))
end

# Stub a user lookup by ID
def stub_v2_user_by_id(id, fixture_file = "v2/sferik.json")
  stub_v2_get("users/#{id}").to_return(v2_return(fixture_file))
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
  JSON.parse(fixture(file).read)
end

def with_captured_output
  original_stderr = $stderr
  original_stdout = $stdout
  $stderr = StringIO.new
  $stdout = StringIO.new
  def $stdout.tty? = true
  yield
ensure
  $stderr = original_stderr
  $stdout = original_stdout
end

def with_const(mod, name, value)
  name = name.to_sym
  was_defined = mod.const_defined?(name)
  old = mod.const_get(name) if was_defined
  mod.send(:remove_const, name) if was_defined
  mod.const_set(name, value)
  yield
ensure
  mod.send(:remove_const, name) if mod.const_defined?(name)
  mod.const_set(name, old) if was_defined
end
