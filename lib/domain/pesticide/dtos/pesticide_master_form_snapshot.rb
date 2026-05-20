# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # 農薬マスタ HTML フォーム用の読み取りスナップショット（永続モデルをビューに渡さない）。
      class PesticideMasterFormSnapshot
        attr_reader :id,
                    :new_record,
                    :error_messages,
                    :name,
                    :active_ingredient,
                    :description,
                    :crop_id,
                    :pest_id,
                    :is_reference,
                    :region,
                    :user_id,
                    :pesticide_usage_constraint_attributes,
                    :pesticide_application_detail_attributes

        def initialize(
          id:,
          new_record:,
          error_messages: [],
          name: nil,
          active_ingredient: nil,
          description: nil,
          crop_id: nil,
          pest_id: nil,
          is_reference: false,
          region: nil,
          user_id: nil,
          pesticide_usage_constraint_attributes: nil,
          pesticide_application_detail_attributes: nil
        )
          @id = id
          @new_record = new_record
          @error_messages = Array(error_messages)
          @name = name
          @active_ingredient = active_ingredient
          @description = description
          @crop_id = crop_id
          @pest_id = pest_id
          @is_reference = is_reference
          @region = region
          @user_id = user_id
          @pesticide_usage_constraint_attributes =
            pesticide_usage_constraint_attributes.nil? ? nil : Domain::Shared.symbolize_keys(pesticide_usage_constraint_attributes.to_hash)
          @pesticide_application_detail_attributes =
            pesticide_application_detail_attributes.nil? ? nil : Domain::Shared.symbolize_keys(pesticide_application_detail_attributes.to_hash)
        end

        def new_record?
          @new_record
        end

        def persisted?
          !@new_record && Domain::Shared.present?(@id)
        end
      end
    end
  end
end
