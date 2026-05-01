# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor が User モデルを直接参照しないためのポート。
      # 実装は Adapters::Shared::Gateways::UserActiveRecordGateway（CompositionRoot で生成）
      module UserLookupPort
        # @return [Domain::Shared::Dtos::UserDto] Policy / DeletionUndo の actor 用
        def find(user_id)
          raise NotImplementedError, "#{self.class}#find"
        end
      end
    end
  end
end
