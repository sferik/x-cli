module T
  module RequestableAPI
    module AccountEndpoints
      def x_trends(woe_id, opts = {})
        params = {max_trends: "50"}
        params["trend.fields"] = "trend_name,tweet_count" if opts[:exclude].to_s == "hashtags"
        response = client.get("trends/by/woeid/#{woe_id}", params:)
        Array(response["data"]).filter_map do |trend|
          name = trend["trend_name"] || trend["name"]
          next if name.nil?
          next if opts[:exclude].to_s == "hashtags" && name.start_with?("#")

          {"name" => name}
        end
      end

      def x_trend_locations
        Array(v1_client.get("trends/available.json")).map do |place|
          loc = {"woeid" => place["woeid"], "name" => place["name"], "country" => place["country"],
                 "parent_id" => place["parentid"] || place["parent_id"],
                 "place_type" => place.dig("placeType", "name") || place["place_type"]}
          loc
        end
      end

      def x_update_profile(**params)
        v1_client.post("account/update_profile.json", form: params.compact) || {}
      end

      def x_update_profile_image(file)
        X::Uploader::Account.update_profile_image(file.path, client:) || {}
      end
    end
  end
end
