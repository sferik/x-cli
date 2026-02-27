require "net/http"

module T
  module RequestableAPI
    module HTTP
    private

      def v1_client
        @v1_client ||= X::Client.new(**@requestable_api_credentials, base_url: BASE_URL_V1)
      end

      def upload_client
        @upload_client ||= X::Client.new(**@requestable_api_credentials, base_url: BASE_URL_UPLOAD)
      end

      def bearer_client
        @bearer_client ||= begin
          client # ensure credentials are initialized
          key = @requestable_api_credentials[:api_key]
          secret = @requestable_api_credentials[:api_key_secret]
          basic = Base64.strict_encode64("#{key}:#{secret}")
          uri = URI("https://api.twitter.com/oauth2/token")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          request = Net::HTTP::Post.new(uri)
          request["Authorization"] = "Basic #{basic}"
          request["Content-Type"] = "application/x-www-form-urlencoded;charset=UTF-8"
          request.body = "grant_type=client_credentials"
          response = http.request(request)
          token = JSON.parse(response.body)["access_token"]
          X::Client.new(bearer_token: token)
        end
      end

      def upload_media(file)
        binary = if file.respond_to?(:read)
          file.rewind if file.respond_to?(:rewind)
          file.read
        else
          File.binread(file.to_s)
        end
        response = t_post_v1_form("media/upload.json", {media_data: Base64.strict_encode64(binary)}, request_client: upload_client)
        media_id = response["media_id_string"] || response["media_id"] || value_id(response)
        raise X::Error.new("Media upload did not return a media_id") if media_id.to_s.empty?

        media_id.to_s
      end

      def t_get_v2(path, params = {})
        client.get(t_endpoint(path, params))
      end

      def t_get_v1(path, params = {})
        v1_client.get(t_endpoint(path, params))
      end

      def t_post_v2_json(path, body = {})
        client.post(t_normalize_path(path), JSON.generate(t_compact_hash(body)), headers: JSON_HEADERS)
      end

      def t_post_bearer_json(path, body = {})
        bearer_client.post(t_normalize_path(path), JSON.generate(t_compact_hash(body)), headers: JSON_HEADERS)
      end

      def t_post_v1_form(path, params = {}, request_client: v1_client)
        request_client.post(t_normalize_path(path), URI.encode_www_form(t_form_pairs(params)), headers: FORM_HEADERS)
      end

      def t_delete_v2(path, params = {})
        client.delete(t_endpoint(path, params))
      end

      def t_endpoint(path, params)
        query = URI.encode_www_form(t_form_pairs(params))
        query.empty? ? t_normalize_path(path) : "#{t_normalize_path(path)}?#{query}"
      end

      def t_form_pairs(hash)
        hash.each_with_object([]) do |(key, value), pairs|
          next if value.nil?

          pairs << [key.to_s, t_scalar_value(value)]
        end
      end

      def t_scalar_value(value)
        case value
        when TrueClass then "true"
        when FalseClass then "false"
        else value.to_s
        end
      end

      def t_compact_hash(hash)
        hash.each_with_object({}) do |(key, value), memo|
          next if value.nil?

          memo[key] = value
        end
      end

      def t_normalize_path(path)
        path.to_s.sub(%r{\A/+}, "")
      end
    end
  end
end
