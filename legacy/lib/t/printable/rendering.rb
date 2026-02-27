module T
  module Printable
    module Rendering
    private

      def build_long_list(list)
        [list["id"], ls_formatted_time(list), "@#{list['user']['screen_name']}", list["slug"], list["member_count"], list["subscriber_count"], list["mode"], list["description"]]
      end

      def build_long_tweet(tweet)
        [tweet["id"], ls_formatted_time(tweet), "@#{tweet['user']['screen_name']}", decode_full_text(tweet, decode_full_uris: options["decode_uris"]).gsub(/\n+/, " ")]
      end

      def build_long_user(user)
        [user["id"], ls_formatted_time(user), ls_formatted_time(user["status"]), user["statuses_count"], user["favorites_count"], user["listed_count"], user["friends_count"], user["followers_count"], "@#{user['screen_name']}", user["name"], user["verified"] ? "Yes" : "No", user["protected"] ? "Yes" : "No", user["description"].to_s.gsub(/\n+/, " "), user["status"] ? decode_full_text(user["status"], decode_full_uris: options["decode_uris"]).gsub(/\n+/, " ") : nil, user["location"], user["url"].to_s]
      end

      def csv_formatted_time(object, key = "created_at")
        return nil if object.nil?

        time = parse_time(object[key.to_s])
        time.utc.strftime("%Y-%m-%d %H:%M:%S %z")
      end

      def ls_formatted_time(object, key = "created_at", allow_relative: true)
        return "" if object.nil?

        time = T.local_time(parse_time(object[key.to_s]))
        if allow_relative && options["relative_dates"]
          "#{distance_of_time_in_words(time)} ago"
        elsif time > Time.now - (MONTH_IN_SECONDS * 6)
          time.strftime("%b %e %H:%M")
        else
          time.strftime("%b %e  %Y")
        end
      end

      def print_csv_list(list)
        require "csv"
        say [list["id"], csv_formatted_time(list), list["user"]["screen_name"], list["slug"], list["member_count"], list["subscriber_count"], list["mode"], list["description"]].to_csv
      end

      def print_csv_tweet(tweet)
        require "csv"
        say [tweet["id"], csv_formatted_time(tweet), tweet["user"]["screen_name"], decode_full_text(tweet, decode_full_uris: options["decode_uris"])].to_csv
      end

      def print_csv_user(user)
        require "csv"
        say [user["id"], csv_formatted_time(user), csv_formatted_time(user["status"]), user["statuses_count"], user["favorites_count"], user["listed_count"], user["friends_count"], user["followers_count"], user["screen_name"], user["name"], user["verified"], user["protected"], user["description"], user["status"] ? user["status"]["full_text"] : nil, user["location"], user["url"]].to_csv
      end

      def print_attribute(array, attribute)
        if $stdout.tty?
          print_in_columns(array.collect { |e| e[attribute.to_s] })
        else
          array.each do |element|
            say element[attribute.to_s]
          end
        end
      end

      def print_table_with_headings(array, headings, format)
        return if array.flatten.empty?

        if $stdout.tty?
          array.unshift(headings)
          array.collect! do |row|
            row.each_with_index.collect do |element, index|
              next if element.nil?

              coerce_formatted(element, format[index] % element)
            end
          end
          print_table(array, truncate: true)
        else
          print_table(array)
        end
        $stdout.flush
      end

      def parse_time(value)
        return value if value.is_a?(Time)

        require "time"
        Time.parse(value.to_s)
      rescue ArgumentError
        Time.at(0)
      end

      def coerce_formatted(element, formatted)
        case element
        when Integer then Integer(formatted)
        when Float then Float(formatted)
        else formatted
        end
      end
    end
  end
end
