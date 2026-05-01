# frozen_string_literal: true

module Adapters
  module Shared
    # DeletionUndo 等、ActiveRecord 側が User を要求する箇所向け
    module UserActorResolver
      module_function

      def user_for_deleted_by(user)
        return nil if user.nil?
        return user if user.is_a?(::User)

        ::User.find(user.id)
      end
    end
  end
end
