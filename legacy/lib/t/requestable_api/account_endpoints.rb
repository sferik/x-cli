module T
  module RequestableAPI
    module AccountEndpoints
      def x_trends(woe_id, opts = {})
        params = {max_trends: "50"}
        params["trend.fields"] = "trend_name,tweet_count" if opts[:exclude].to_s == "hashtags"
        response = t_get_v2("trends/by/woeid/#{woe_id}", params)
        Array(response["data"]).filter_map do |trend|
          name = trend["trend_name"] || trend["name"]
          next if name.nil?
          next if opts[:exclude].to_s == "hashtags" && name.start_with?("#")

          {"name" => name}
        end
      end

      def x_trend_locations
        Array(t_get_v1("trends/available.json")).map do |place|
          loc = {"woeid" => place["woeid"], "name" => place["name"], "country" => place["country"],
                 "parent_id" => place["parentid"] || place["parent_id"],
                 "place_type" => place.dig("placeType", "name") || place["place_type"]}
          loc
        end
      end

      def x_settings(lang:)
        t_post_v1_form("account/settings.json", {lang: lang})
        true
      end

      def x_update_profile(description: nil, location: nil, name: nil, url: nil)
        params = {}
        params[:description] = description unless description.nil?
        params[:location] = location unless location.nil?
        params[:name] = name unless name.nil?
        params[:url] = url unless url.nil?
        response = t_post_v1_form("account/update_profile.json", params)
        extract_users(response).first || (response || {})
      end

      def x_update_profile_image(file)
        response = t_post_v1_form("account/update_profile_image.json", {image: Base64.strict_encode64(file.read)})
        extract_users(response).first || (response || {})
      end

      def x_update_profile_background_image(file, tile: false, skip_status: true)
        params = {image: Base64.strict_encode64(file.read), skip_status: skip_status}
        params[:tile] = tile if tile
        t_post_v1_form("account/update_profile_background_image.json", params)
        true
      end

      def x_before_request(&block)
        @requestable_api_before_request = block
      end

      def x_sample(language: nil, &)
        @requestable_api_before_request&.call
        query = language ? "lang:#{language} -is:retweet" : "has:mentions OR -is:retweet"
        x_search(query, count: 20).each(&)
      rescue X::BadRequest
        fallback = language ? "news lang:#{language}" : "news"
        x_search(fallback, count: 20).each(&)
      end

      def x_filter(follow: nil, track: nil, &)
        @requestable_api_before_request&.call
        query = build_filter_query(follow: follow, track: track)
        x_search(query, count: 100).each(&)
      rescue X::BadRequest
        x_search("news", count: 20).each(&)
      end

    private

      def build_filter_query(follow: nil, track: nil)
        queries = []
        queries.concat(parse_filter_terms(track)) if track
        queries.concat(parse_filter_follows(follow)) if follow
        query = queries.join(" OR ")
        query.empty? ? "has:mentions OR -is:retweet" : query
      end

      def parse_filter_terms(value)
        value.to_s.split(",").map(&:strip).reject(&:empty?)
      end

      def parse_filter_follows(value)
        parse_filter_terms(value).map { |id| "from:#{id}" }
      end
    end
  end
end
