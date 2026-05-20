# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # UserLookupGateway / Policy 用。ActiveRecord::User をドメイン境界に渡さない。
      class User
        attr_reader :id

        def initialize(id:, admin:, anonymous: false)
          @id = id
          @admin = admin
          @anonymous = anonymous
        end

        def admin?
          @admin
        end

        def anonymous?
          @anonymous
        end
      end
    end
  end
end
