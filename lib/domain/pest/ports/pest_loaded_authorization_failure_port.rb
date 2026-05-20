# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      # PestLoadAuthorizedModelForEditInteractor の失敗時に呼ぶ契約。
      # 具象 Presenter でメソッドを上書きする（include に付属する基底実装は未実装）。
      module PestLoadedAuthorizationFailurePort
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
