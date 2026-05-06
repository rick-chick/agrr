# frozen_string_literal: true

module Adapters
  module Shared
    module Mappers
      module UserMapper
        module_function

        def user_dto_from_record(user)
          Domain::Shared::Dtos::UserDto.new(
            id: user.id,
            admin: user.admin?,
            anonymous: user.respond_to?(:anonymous?) ? user.anonymous? : user.is_anonymous?
          )
        end
      end
    end
  end
end
