# frozen_string_literal: true

module Domain
  module Shared
    module Gateways
      # Interactor が User モデルを直接参照しないためのゲートウェイ。
      # 実装は Adapters::Shared::Gateways::UserActiveRecordGateway（CompositionRoot で生成）
      module UserLookupGateway
        # @return [Domain::Shared::Dtos::User] Policy / DeletionUndo の actor 用
        def find(user_id)
          raise NotImplementedError, "#{self.class}#find"
        end
      end
    end
  end
end
