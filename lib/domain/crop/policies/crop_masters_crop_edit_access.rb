# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      # マスタ Crop 系: 編集認可を Interactor 側で評価（R0）。Gateway は find_by_id のみ。
      module CropMastersCropEditAccess
        module_function

        def assert_edit!(access_filter:, crop_id:, gateway:)
          crop_entity = gateway.find_by_id(crop_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, crop_entity)
        end

        # @return [Boolean] false のとき output_port に既に on_failure 済み
        def assert_edit_or_on_failure(access_filter:, crop_id:, gateway:, output_port:, failure:)
          assert_edit!(access_filter: access_filter, crop_id: crop_id, gateway: gateway)
          true
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          output_port.on_failure(failure)
          false
        rescue Domain::Shared::Exceptions::RecordNotFound
          output_port.on_failure(failure)
          false
        end
      end
    end
  end
end
