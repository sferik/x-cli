require "test_helper"

class TestUtils < TTestCase
  def setup
    super
    @test_obj = Object.new
    @test_obj.extend(T::Utils)
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0))
    T.utc_offset = -28_800
  end

  def teardown
    super
    T.utc_offset = nil
    Timecop.return
  end

  # distance_of_time_in_words

  def test_distance_of_time_in_words_returns_a_split_second_if_less_than_a_second
    assert_equal "a split second", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 16, 20, 0))
  end

  def test_distance_of_time_in_words_returns_a_second_if_difference_is_a_second
    assert_equal "a second", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 16, 20, 1))
  end

  def test_distance_of_time_in_words_returns_2_seconds
    assert_equal "2 seconds", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 16, 20, 2))
  end

  def test_distance_of_time_in_words_returns_59_seconds
    assert_equal "59 seconds", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 16, 20, 59.9))
  end

  def test_distance_of_time_in_words_returns_a_minute
    assert_equal "a minute", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 16, 21, 0))
  end

  def test_distance_of_time_in_words_returns_2_minutes
    assert_equal "2 minutes", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 16, 22, 0))
  end

  def test_distance_of_time_in_words_returns_59_minutes
    assert_equal "59 minutes", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 17, 19, 59.9))
  end

  def test_distance_of_time_in_words_returns_an_hour
    assert_equal "an hour", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 17, 20, 0))
  end

  def test_distance_of_time_in_words_returns_2_hours
    assert_equal "2 hours", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 24, 18, 20, 0))
  end

  def test_distance_of_time_in_words_returns_23_hours
    assert_equal "23 hours", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 25, 15, 49, 59.9))
  end

  def test_distance_of_time_in_words_returns_a_day
    assert_equal "a day", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 25, 15, 50, 0))
  end

  def test_distance_of_time_in_words_returns_2_days
    assert_equal "2 days", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 11, 26, 16, 20, 0))
  end

  def test_distance_of_time_in_words_returns_29_days
    assert_equal "29 days", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 12, 24, 4, 19, 59.9))
  end

  def test_distance_of_time_in_words_returns_a_month
    assert_equal "a month", @test_obj.send(:distance_of_time_in_words, Time.utc(2011, 12, 24, 4, 20, 0))
  end

  def test_distance_of_time_in_words_returns_2_months
    assert_equal "2 months", @test_obj.send(:distance_of_time_in_words, Time.utc(2012, 1, 24, 16, 20, 0))
  end

  def test_distance_of_time_in_words_returns_11_months
    assert_equal "11 months", @test_obj.send(:distance_of_time_in_words, Time.utc(2012, 11, 8, 11, 19, 59.9))
  end

  def test_distance_of_time_in_words_returns_a_year
    assert_equal "a year", @test_obj.send(:distance_of_time_in_words, Time.utc(2012, 11, 8, 11, 20, 0))
  end

  def test_distance_of_time_in_words_returns_2_years
    assert_equal "2 years", @test_obj.send(:distance_of_time_in_words, Time.utc(2013, 11, 24, 16, 20, 0))
  end

  # strip_tags

  def test_strip_tags_returns_string_sans_tags
    assert_equal "Twitter for iPhone", @test_obj.send(:strip_tags, '<a href="http://twitter.com/#!/download/iphone" rel="nofollow">Twitter for iPhone</a>')
  end

  # number_with_delimiter

  def test_number_with_delimiter_returns_number_with_delimiter
    assert_equal "1,234,567,890", @test_obj.send(:number_with_delimiter, 1_234_567_890)
  end

  def test_number_with_delimiter_with_custom_delimiter
    assert_equal "1.234.567.890", @test_obj.send(:number_with_delimiter, 1_234_567_890, ".")
  end

  # open_or_print

  def test_open_or_print_prints_uri_when_launchy_yields_to_fallback
    fake_launchy = Class.new { def self.open(_uri, _options) = yield }

    say_calls = []
    @test_obj.define_singleton_method(:say) { |msg| say_calls << msg }

    with_const(Object, :Launchy, fake_launchy) do
      @test_obj.send(:open_or_print, "https://example.com", {})
    end

    assert_equal ["Open: https://example.com"], say_calls
  end

  # message_text

  def test_message_text_expands_links_when_decode_uris_is_set
    message = {"full_text" => "Check http://t.co/abc &amp; more", "expanded_text" => "Check http://example.com/full &amp; more"}
    @test_obj.define_singleton_method(:options) { {"decode_uris" => true} }

    assert_equal "Check http://example.com/full &amp; more", @test_obj.send(:message_text, message)
    assert_equal "Check http://example.com/full & more", @test_obj.send(:decode_full_text, message)
  end

  def test_message_text_keeps_links_short_by_default
    message = {"full_text" => "Check http://t.co/abc", "expanded_text" => "Check http://example.com/full"}
    @test_obj.define_singleton_method(:options) { {} }

    assert_equal "Check http://t.co/abc", @test_obj.send(:message_text, message)
  end

  def test_message_text_of_a_message_without_expanded_text
    @test_obj.define_singleton_method(:options) { {"decode_uris" => true} }

    assert_equal "hi", @test_obj.send(:message_text, {"full_text" => "hi"})
  end

  # distance_of_time_in_words case else branch

  def test_distance_of_time_in_words_case_else_branch_returns_2_years
    assert_equal "2 years", @test_obj.send(:distance_of_time_in_words, Time.utc(2013, 11, 24, 16, 20, 0))
  end
end
