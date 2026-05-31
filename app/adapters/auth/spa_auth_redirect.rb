# frozen_string_literal: true

module Adapters
  module Auth
    # SPA `/login` へのリダイレクト URL と `return_to` 許可判定（agrr-server `auth_return_to` と同等）。
    class SpaAuthRedirect
      class << self
        def login_url(return_to: nil, request_base_url: nil)
          base = "#{default_origin.chomp('/')}/login"
          normalized = return_to.to_s.strip
          if normalized.present? && allowed_return_to?(normalized, request_base_url: request_base_url)
            "#{base}?return_to=#{ERB::Util.url_encode(normalized)}"
          else
            base
          end
        end

        def allowed_return_to?(url, request_base_url: nil)
          return false if url.blank?

          uri = URI.parse(url)
          return false unless %w[http https].include?(uri.scheme)

          origin = build_origin(uri)
          return true if frontend_origins.include?(origin)
          return true if request_base_url.present? && matches_request_origin?(origin, request_base_url)
          return true if matches_allowed_host?(uri.host)

          false
        rescue URI::InvalidURIError
          false
        end

        def default_origin
          frontend_origins.first || "http://localhost:4200"
        end

        def frontend_origins
          ENV.fetch("FRONTEND_URL", "http://127.0.0.1:4200,http://localhost:4200")
            .split(",")
            .map(&:strip)
            .reject(&:empty?)
            .filter_map { |base| build_origin(URI.parse(base)) }
        rescue URI::InvalidURIError
          []
        end

        private

        def build_origin(uri)
          host = uri.host.to_s
          default_port = uri.scheme == "https" ? 443 : 80
          if uri.port && uri.port != default_port
            "#{uri.scheme}://#{host}:#{uri.port}"
          else
            "#{uri.scheme}://#{host}"
          end
        end

        def matches_request_origin?(origin, request_base_url)
          request_base = URI.parse(request_base_url)
          build_origin(request_base) == origin
        rescue URI::InvalidURIError
          false
        end

        def matches_allowed_host?(host)
          return false if host.blank?

          ENV.fetch("ALLOWED_HOSTS", "")
            .split(",")
            .map(&:strip)
            .reject(&:empty?)
            .any? { |pattern| host_matches_pattern?(host, pattern) }
        end

        def host_matches_pattern?(host, pattern)
          normalized = pattern.strip
          return false if normalized.empty?

          if normalized.start_with?(".")
            suffix = normalized.delete_prefix(".")
            host.casecmp?(suffix) || host.downcase.end_with?(".#{suffix.downcase}")
          else
            host.casecmp?(normalized)
          end
        end
      end
    end
  end
end
