# frozen_string_literal: true

module Domain
  module InteractionRule
    module Dtos
      # 相互作用ルールマスタ HTML フォーム用スナップショット（ActiveRecord をビューに渡さない）。
      class InteractionRuleMasterFormSnapshot
        attr_reader :attributes, :new_record, :id, :error_messages

        def initialize(attributes:, new_record:, id: nil, error_messages: [])
          @attributes = Domain::Shared.symbolize_keys(attributes.to_hash)
          @new_record = new_record
          @id = id
          @error_messages = Array(error_messages)
        end

        def new_record?
          @new_record
        end

        def persisted?
          !@new_record && Domain::Shared.present?(@id)
        end

        # @param entity [Domain::InteractionRule::Entities::InteractionRuleEntity]
        def self.from_entity(entity)
          return blank_new if entity.nil?

          h = Domain::Shared.symbolize_keys(entity.to_hash).slice(*Domain::InteractionRule::MasterFormAttributes::KEYS)
          new(
            attributes: h,
            new_record: Domain::Shared.blank?(entity.id),
            id: entity.id,
            error_messages: []
          )
        end

        def self.blank_new
          new(attributes: {}, new_record: true, id: nil, error_messages: [])
        end
      end
    end
  end
end
