module T
  module RequestableAPI
    # The clients for the endpoints the object layer of the x gem does not cover
    module HTTP
    private

      def v1_client
        @v1_client ||= client.copy(base_url: BASE_URL_V1)
      end

      # The client for the streaming endpoints, which reads and reconnects as a stream needs
      def streaming_client
        @streaming_client ||= client.streaming
      end

      def upload_media(file)
        X::Uploader::Media.upload(file.respond_to?(:path) ? file.path : file.to_s, client:)
      end
    end
  end
end
