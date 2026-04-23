# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor が User モデルを直接参照しないためのポート。
      # 実装は lib/adapters（例: {Adapters::Shared::Gateways::UserActiveRecordGateway}）。
      module UserLookupPort
        class << self
          # @return [UserLookupPort] アプリ既定のユーザー解決（テストでは {#default=} で差し替え可能）
          def default
            @default ||= Adapters::Shared::Gateways::UserActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        # @return [Object] id, admin? に応答すること（Policy / DeletionUndo の actor 用）
        def find(user_id)
          raise NotImplementedError, "#{self.class}#find"
        end
      end
    end
  end
end
