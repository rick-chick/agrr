# frozen_string_literal: true

module Domain
  module Field
    module Policies
      # 圃場新規用の属性マージ（ORM なし）。永続化は Adapter / FieldPolicy のエッジ。
      module FieldCreateAttributes
        module_function

        def merge_for_build(user_id:, farm_id:, attrs:)
          h = Domain::Shared.symbolize_keys(attrs.to_h)
          h[:user_id] ||= user_id
          h[:farm_id] = farm_id
          h
        end
      end
    end
  end
end
