# frozen_string_literal: true

module Domain
  module Pesticide
    module Mappers
      # Gateway の読み取り結果を output-port DTO（bundle）に組み立てる。I/O は gateway のみ。
      class PesticideMasterFormBundleAssembler
        def initialize(gateway:)
          @gateway = gateway
        end

        # @param user [Object] #admin? を持つユーザー（Policy 用）
        # @param assign_attributes [Hash]
        # @return [Domain::Pesticide::Dtos::PesticideMasterFormBundle]
        def bundle_for_new(user:, assign_attributes: {})
          crop_list_filter, pest_list_filter = pick_list_filters_for(user)
          snapshot = @gateway.build_pesticide_master_form_snapshot_for_new(
            assign_attributes: assign_attributes
          )
          assemble_bundle(snapshot, crop_list_filter: crop_list_filter, pest_list_filter: pest_list_filter)
        end

        # @return [Domain::Pesticide::Dtos::PesticideMasterFormBundle]
        def bundle_after_update_merge(user:, pesticide_id:, assign_attributes:)
          access_filter = Domain::Shared::Policies::PesticidePolicy.record_access_filter(user)
          current = @gateway.find_by_id(pesticide_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)
          crop_list_filter, pest_list_filter = pick_list_filters_for(user)
          snapshot = @gateway.build_pesticide_master_form_snapshot_after_update_merge!(
            user: user,
            pesticide_id: pesticide_id,
            assign_attributes: assign_attributes
          )
          assemble_bundle(snapshot, crop_list_filter: crop_list_filter, pest_list_filter: pest_list_filter)
        end

        # @return [Domain::Pesticide::Dtos::PesticideMasterFormPickListBundle]
        def pick_list_bundle_for(user:)
          crop_list_filter, pest_list_filter = pick_list_filters_for(user)
          crop_rows = @gateway.list_crop_pick_rows_for_pesticide_master_form(crop_list_filter: crop_list_filter)
          pest_rows = @gateway.list_pest_pick_rows_for_pesticide_master_form(pest_list_filter: pest_list_filter)
          Domain::Pesticide::Mappers::PesticideMasterFormPickListBundleMapper.from_pick_rows(
            crop_pick_rows: crop_rows,
            pest_pick_rows: pest_rows
          )
        end

        private

        def pick_list_filters_for(user)
          [
            Domain::Shared::Policies::CropPolicy.index_list_filter(user),
            Domain::Shared::Policies::PestPolicy.index_list_filter(user)
          ]
        end

        def assemble_bundle(snapshot, crop_list_filter:, pest_list_filter:)
          crop_rows = @gateway.list_crop_pick_rows_for_pesticide_master_form(crop_list_filter: crop_list_filter)
          pest_rows = @gateway.list_pest_pick_rows_for_pesticide_master_form(pest_list_filter: pest_list_filter)
          Domain::Pesticide::Mappers::PesticideMasterFormBundleMapper.from_parts(
            pesticide_master_form_snapshot: snapshot,
            crop_pick_rows: crop_rows,
            pest_pick_rows: pest_rows
          )
        end
      end
    end
  end
end
