# frozen_string_literal: true

module Adapters
  module Shared
    module Mappers
      module UserMapper
        module_function

        def user_dto_from_record(user)
          Domain::Shared::Dtos::UserDto.new(
            id: user.id,
            admin: user.admin?
          )
        end
      end
    end
  end
end
