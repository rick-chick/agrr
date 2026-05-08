# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # HTTP JSON 応答向け: { status: Symbol, body: Hash } をドメインからアプリケーションエッジへ返す値オブジェクト。
      class HttpJsonEnvelope
        attr_reader :status, :body

        def initialize(status:, body:)
          @status = status
          @body = body
        end

        def success?
          status == :ok || status == :created
        end
      end
    end
  end
end
