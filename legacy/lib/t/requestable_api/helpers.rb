module T
  module RequestableAPI
    module Helpers
    private

      def normalize_id_list(ids)
        Array(ids).flatten.compact.collect(&:to_s)
      end

      def single_or_array(input, values)
        input.is_a?(Array) ? values : values.first
      end

      def slugify_list_name(value)
        slug = value.to_s.downcase.gsub(/[^a-z0-9_]+/, "-")
        slug.gsub(/\A-+|-+\z/, "")
      end

      # The query parameters among the options the commands pass, which also carry a count
      def cursor_params(opts)
        opts.except(:count)
      end

      def result_count(opts)
        [(opts[:count] || DEFAULT_NUM_RESULTS).to_i, 1].max
      end
    end
  end
end
