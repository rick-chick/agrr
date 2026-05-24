# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      # マスタ Crop 系: 編集認可を Interactor 側で評価（R0）。crop は Interactor が find_by_id で読み込む。
      module CropMastersCropEditAccess
        module_function

        def assert_edit!(access_filter:, crop_entity:)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, crop_entity)
        end

        # @return [Boolean] false のとき output_port に既に on_failure 済み
        def assert_edit_or_on_failure(access_filter:, crop_entity:, output_port:, failure:)
          assert_edit!(access_filter: access_filter, crop_entity: crop_entity)
          true
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          output_port.on_failure(failure)
          false
        end
      end
    end
  end
end
