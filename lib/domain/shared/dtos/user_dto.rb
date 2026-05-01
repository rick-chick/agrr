# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # UserLookupPort / Policy 用。ActiveRecord::User をドメイン境界に渡さない。
      class UserDto
        attr_reader :id

        def initialize(id:, admin:)
          @id = id
          @admin = admin
        end

        def admin?
          @admin
        end
      end
    end
  end
end
