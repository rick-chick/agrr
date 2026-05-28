# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # マスター API 認証: API キーまたは session_id Cookie から主体を解決する入力。
      class MastersApiCredentialsResolveInput
        attr_reader :api_key, :session_id

        # @param api_key [String, nil]
        # @param session_id [String, nil]
        def initialize(api_key:, session_id:)
          @api_key = api_key
          @session_id = session_id
        end

        def api_key_present?
          !@api_key.nil? && !@api_key.to_s.strip.empty?
        end
      end
    end
  end
end
