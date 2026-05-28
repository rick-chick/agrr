# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      # 公開プラン・エントリスケジュール等で参照作物のみを許可するユースケース判断（ORM 非依存）。
      module CropReferenceRecordPolicy
        module_function

        def reference_crop?(record)
          Domain::Shared::ReferenceRecordAuthorization.referencable_is_reference(record)
        end

        def region_matches?(record, region)
          return true if region.blank?

          rec_region = record.respond_to?(:region) ? record.region : nil
          rec_region.to_s == region.to_s
        end

        def visible_for_public_plan_add_crop?(record)
          reference_crop?(record)
        end

        def visible_for_entry_schedule?(record, region:)
          reference_crop?(record) && region_matches?(record, region)
        end
      end
    end
  end
end
