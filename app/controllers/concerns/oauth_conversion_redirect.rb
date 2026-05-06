# frozen_string_literal: true

# Google 広告のコンバージョン計測用（OAuth 取得成功後のみフロントが検知するクエリ）。
module OauthConversionRedirect
  private

  # @param url_string [String] FRONTEND_URL 許可リストに通過した後のオリジン付きフル URL
  def append_oauth_conversion_query(url_string)
    append_query_param(url_string.to_s.strip, "_agrr_oauth", "1")
  end

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
