# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      # 作物マスタ配下 API（農薬・害虫等）: ユーザー所有の非参照作物への edit 可否。
      module CropMastersNestedAccess
        module_function

        def assert_edit_allowed_for_masters!(user, crop_entity)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, crop_entity)
        end
      end
    end
  end
end
