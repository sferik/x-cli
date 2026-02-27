require "test_helper"

class PrintableProbe
  include T::Printable
  include T::Utils

  attr_accessor :options, :printed_columns, :print_table_args

  def initialize
    @options = {}
  end

  def print_in_columns(values)
    @printed_columns = values
  end

  def print_table(*args)
    @print_table_args = args
  end

  def say(*); end
end

class TestPrintable < TTestCase
  def setup
    super
    @probe = PrintableProbe.new
  end

  # print_attribute

  def test_print_attribute_prints_in_columns_when_stdout_is_tty
    elements = [{"full_name" => "@alice"}, {"full_name" => "@bob"}]
    with_captured_output do
      @probe.send(:print_attribute, elements, "full_name")
    end

    assert_equal(["@alice", "@bob"], @probe.printed_columns)
  end

  def test_print_attribute_says_each_element_when_stdout_is_not_tty
    elements = [{"full_name" => "@alice"}, {"full_name" => "@bob"}]
    said = []
    @probe.define_singleton_method(:say) { |v| said << v }
    with_captured_output do
      def $stdout.tty? = false
      @probe.send(:print_attribute, elements, "full_name")
    end

    assert_equal(["@alice", "@bob"], said)
  end

  # print_table_with_headings

  def test_print_table_with_headings_formats_and_prints_with_headings_when_tty
    expected_tty_args = [[%w[ID Text], [20, "ok"], [40, nil]], {truncate: true}]
    with_captured_output do
      @probe.send(:print_table_with_headings, [[20, "ok"], [40, nil]], %w[ID Text], ["%s", "%s"])
    end

    assert_equal(expected_tty_args, @probe.print_table_args)
  end

  def test_print_table_with_headings_returns_nil_when_array_is_empty
    result = nil
    with_captured_output do
      result = @probe.send(:print_table_with_headings, [], %w[ID Text], ["%s", "%s"])
    end

    assert_nil(result)
  end

  def test_print_table_with_headings_coerces_float_elements
    with_captured_output do
      @probe.send(:print_table_with_headings, [[1.5, "ok"]], %w[Score Text], ["%s", "%s"])
    end

    assert_includes(@probe.print_table_args.first.last, 1.5)
  end

  def test_print_table_with_headings_prints_without_headings_when_not_tty
    with_captured_output do
      def $stdout.tty? = false
      @probe.send(:print_table_with_headings, [[20, "ok"]], %w[ID Text], ["%s", "%s"])
    end

    assert_equal([[[20, "ok"]]], @probe.print_table_args)
  end

  # parse_time

  def test_parse_time_returns_value_if_already_a_time
    time = Time.now

    assert_equal(time, @probe.send(:parse_time, time))
  end

  def test_parse_time_parses_string_into_a_time_object
    result = @probe.send(:parse_time, "2011-11-24T16:20:00Z")

    assert_kind_of(Time, result)
  end

  def test_parse_time_parses_string_into_correct_year
    result = @probe.send(:parse_time, "2011-11-24T16:20:00Z")

    assert_equal(2011, result.utc.year)
  end

  def test_parse_time_returns_epoch_time_for_unparseable_strings
    result = @probe.send(:parse_time, "not-a-date")

    assert_equal(Time.at(0), result)
  end

  # csv_formatted_time

  def test_csv_formatted_time_returns_nil_when_object_is_nil
    assert_nil(@probe.send(:csv_formatted_time, nil))
  end

  # ls_formatted_time

  def test_ls_formatted_time_returns_empty_string_when_object_is_nil
    assert_equal("", @probe.send(:ls_formatted_time, nil))
  end

  # build_long_user

  def test_build_long_user_shows_yes_for_verified_users
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0)) do
      T.utc_offset = -28_800
      row = @probe.send(:build_long_user, base_user.merge("verified" => true))

      assert_equal("Yes", row[10])
    end
  ensure
    T.utc_offset = nil
  end

  def test_build_long_user_shows_yes_for_protected_users
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0)) do
      T.utc_offset = -28_800
      row = @probe.send(:build_long_user, base_user.merge("protected" => true))

      assert_equal("Yes", row[11])
    end
  ensure
    T.utc_offset = nil
  end

  def test_build_long_user_returns_nil_for_status_column_when_user_has_no_status
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0)) do
      T.utc_offset = -28_800
      user = base_user.except("status")
      row = @probe.send(:build_long_user, user)

      assert_nil(row[13])
    end
  ensure
    T.utc_offset = nil
  end

  # print_csv_user

  def test_print_csv_user_outputs_nil_for_status_when_user_has_no_status
    said = []
    @probe.define_singleton_method(:say) { |v| said << v }
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0)) do
      T.utc_offset = -28_800
      @probe.send(:print_csv_user, user_without_status)

      assert_includes(said.first, "test")
    end
  ensure
    T.utc_offset = nil
  end

  # print_lists

  def test_print_lists_skips_sorting_when_unsorted_option_is_set
    zlist = {"full_name" => "@user/zlist", "slug" => "zlist", "created_at" => "2011-01-01T00:00:00Z", "member_count" => 1, "subscriber_count" => 0, "mode" => "public"}
    alist = {"full_name" => "@user/alist", "slug" => "alist", "created_at" => "2011-01-02T00:00:00Z", "member_count" => 2, "subscriber_count" => 1, "mode" => "private"}
    @probe.options = {"unsorted" => true}
    with_captured_output do
      @probe.send(:print_lists, [zlist, alist])
    end

    assert_equal(["@user/zlist", "@user/alist"], @probe.printed_columns)
  end

  def test_print_lists_does_not_print_csv_headers_when_lists_are_empty
    @probe.options = {"csv" => true}
    said = []
    @probe.define_singleton_method(:say) { |v| said << v }
    @probe.send(:print_lists, [])

    assert_empty(said)
  end

  # print_tweets

  def test_print_tweets_does_not_print_csv_headers_when_tweets_are_empty
    @probe.options = {"csv" => true}
    said = []
    @probe.define_singleton_method(:say) { |v| said << v }
    @probe.send(:print_tweets, [])

    assert_empty(said)
  end

  # print_users

  def test_print_users_does_not_print_csv_headers_when_users_are_empty
    @probe.options = {"csv" => true}
    said = []
    @probe.define_singleton_method(:say) { |v| said << v }
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0)) do
      T.utc_offset = -28_800
      @probe.send(:print_users, [])

      assert_empty(said)
    end
  ensure
    T.utc_offset = nil
  end

  def test_print_users_sorts_users_without_status_to_beginning_when_sorting_by_tweeted
    user_with = {"id" => 1, "screen_name" => "alice", "name" => "Alice",
                 "verified" => false, "protected" => false,
                 "description" => "desc", "location" => "here",
                 "url" => "http://example.com", "created_at" => "2011-01-01T00:00:00Z",
                 "statuses_count" => 10, "favorites_count" => 5,
                 "listed_count" => 2, "friends_count" => 3, "followers_count" => 4,
                 "status" => {"id" => 100, "text" => "hello", "full_text" => "hello",
                              "created_at" => "2011-06-01T00:00:00Z", "user" => {"screen_name" => "alice"}}}
    user_without = {"id" => 2, "screen_name" => "bob", "name" => "Bob",
                    "verified" => false, "protected" => false,
                    "description" => "desc", "location" => "there",
                    "url" => "http://example.com", "created_at" => "2011-01-02T00:00:00Z",
                    "statuses_count" => 0, "favorites_count" => 0,
                    "listed_count" => 0, "friends_count" => 0, "followers_count" => 0}
    @probe.options = {"sort" => "tweeted"}
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0)) do
      T.utc_offset = -28_800
      with_captured_output do
        @probe.send(:print_users, [user_with, user_without])
      end

      assert_equal(%w[bob alice], @probe.printed_columns)
    end
  ensure
    T.utc_offset = nil
  end

private

  def base_user
    user_status = {"id" => 100, "text" => "hello", "full_text" => "hello",
                   "created_at" => "2011-06-01T00:00:00Z", "user" => {"screen_name" => "test"}}
    {"id" => 1, "screen_name" => "test", "name" => "Test",
     "verified" => false, "protected" => false,
     "description" => "desc", "location" => "here",
     "url" => "http://example.com", "created_at" => "2011-01-01T00:00:00Z",
     "statuses_count" => 10, "favorites_count" => 5,
     "listed_count" => 2, "friends_count" => 3, "followers_count" => 4,
     "status" => user_status}
  end

  def user_without_status
    {"id" => 1, "screen_name" => "test", "name" => "Test",
     "verified" => false, "protected" => false,
     "description" => "desc", "location" => "here",
     "url" => "http://example.com", "created_at" => "2011-01-01T00:00:00Z",
     "statuses_count" => 10, "favorites_count" => 5,
     "listed_count" => 2, "friends_count" => 3, "followers_count" => 4}
  end
end
