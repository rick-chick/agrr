# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      # 作物 AI upsert の永続化（AR 等）はアダプタ側に閉じる。
      # 実装: {Adapters::Crop::CropAiUpsertActiveRecordPersistence}
      #
      # @!method upsert(user_dto:, crop_name:, variety:, crop_info:, crop_access_filter:)
      #   @param crop_access_filter [Domain::Shared::ReferenceRecordAccessFilter] CropPolicy.record_access_filter(user)
      #   @return [Domain::Shared::Dtos::HttpJsonEnvelope]
      module CropAiUpsertPersistencePort
      end
    end
  end
end
