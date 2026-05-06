# frozen_string_literal: true

module Domain
  module Backdoor
    module Gateways
      # バックドア用途: 匿名ユーザー以外のアプリデータを一括削除（永続化は Adapter）。
      module ApplicationDatabaseClearGateway
        ApplicationDataStats = Struct.new(:users, :farms, :fields, :crops, :cultivation_plans, keyword_init: true)

        ClearResult = Struct.new(:kind, :before_stats, :after_stats, :error_message, keyword_init: true) do
          def self.success(before:, after:)
            new(kind: :success, before_stats: before, after_stats: after)
          end

          def self.failure(message)
            new(kind: :failure, error_message: message.to_s)
          end
        end

        def clear_application_data_preserving_anonymous_users
          raise NotImplementedError, "#{self.class} must implement clear_application_data_preserving_anonymous_users"
        end
      end
    end
  end
end
