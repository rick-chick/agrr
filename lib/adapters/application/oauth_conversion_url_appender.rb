# frozen_string_literal: true

module Adapters
  module Application
    # Google 広告コンバージョン計測用クエリ ?_agrr_oauth=1 を付与する（OAuth 成功後のリダイレクトのみ）。
    class OauthConversionUrlAppender
      CONVERSION_QUERY_KEY = "_agrr_oauth"
      CONVERSION_QUERY_VALUE = "1"

      # @param url_string [String] 許可リスト通過後の絶対 URL
      # @return [String]
      def append(url_string)
        append_query_param(url_string.to_s.strip, CONVERSION_QUERY_KEY, CONVERSION_QUERY_VALUE)
      end

      private

      def append_query_param(url_string, key, value)
        uri = URI.parse(url_string)
        return url_string unless %w[http https].include?(uri.scheme&.downcase)

        q = Rack::Utils.parse_nested_query(uri.query.to_s)
        q[key.to_s] = value.to_s
        uri.query = Rack::Utils.build_query(q).presence
        uri.to_s
      rescue URI::InvalidURIError
        url_string
      end
    end
  end
end
