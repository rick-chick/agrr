# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor が User モデルを直接参照しないためのポート。
      # 実装は lib/adapters（例: {Adapters::Shared::Gateways::UserActiveRecordGateway}）。
      # NOTE: Clean Architecture 純化のため、Controller (Composition Root) で
      # Adapter インスタンスを生成し Interactor へ DI する方式に段階移行中。
      # `.default` は移行未完了の Interactor 互換のため残置（移行完了後に削除）。
      module UserLookupPort
        class << self
          def default
            @default ||= Adapters::Shared::Gateways::UserActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        # @return [Domain::Shared::Dtos::UserDto] Policy / DeletionUndo の actor 用
        def find(user_id)
          raise NotImplementedError, "#{self.class}#find"
        end
      end
    end
  end
end
