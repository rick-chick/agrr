# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      # 作物 AI upsert の永続化（AR 等）はアダプタ側に閉じる。
      # 実装: {Adapters::Crop::CropAiUpsertActiveRecordPersistence}
      #
      # @!method upsert(user_dto:, crop_name:, variety:, crop_info:)
      #   @return [Domain::Shared::Dtos::ApiJsonResult]
      module CropAiUpsertPersistencePort
      end
    end
  end
end
