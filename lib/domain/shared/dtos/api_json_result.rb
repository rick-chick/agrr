# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # API 境界向け: { status: Symbol, body: Hash } をドメインからコントローラへ返すための値オブジェクト。
      class ApiJsonResult
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
