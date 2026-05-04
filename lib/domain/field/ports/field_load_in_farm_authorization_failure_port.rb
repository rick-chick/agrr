# frozen_string_literal: true

module Domain
  module Field
    module Ports
      # FieldLoadAuthorizedInFarmInteractor の失敗時に呼ぶ契約。
      module FieldLoadInFarmAuthorizationFailurePort
        def on_permission_denied
          raise NotImplementedError, "#{self.class} must implement #on_permission_denied"
        end

        def on_not_found
          raise NotImplementedError, "#{self.class} must implement #on_not_found"
        end
      end
    end
  end
end
