# frozen_string_literal: true

module Domain
  module Pesticide
    module Gateways
      class PesticideGateway
        def find_by_id(pesticide_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(pesticide_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def delete(pesticide_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        def find_authorized_for_view(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        # 認可済み農薬の HTML/API 詳細用 DTO（1 回の読み込みで関連名・制約を含む）
        def authorized_pesticide_detail_output(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement authorized_pesticide_detail_output"
        end

        def find_authorized_for_edit(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_authorized_pesticide_loaded_bundle!(user, id, for_edit:, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_pesticide_loaded_bundle!"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs, access_filter:)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_delete_with_undo(user:, pesticide_id:, auto_hide_after:, translator:, access_filter:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end

        # Crop に紐づく、user に閲覧可能な Pesticide エンティティを最近順で返す。
        # @return [Array<Domain::Pesticide::Entities::PesticideEntity>] entities or AR records
        def list_for_crop_with_user(crop_id:, user:)
          raise NotImplementedError, "Subclasses must implement list_for_crop_with_user"
        end

        # 農薬マスタ HTML フォームの作物プルダウン行（filter は Interactor が Policy で組み立てる）
        # @param crop_list_filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        # @return [Array<Domain::Pesticide::Dtos::PesticideMasterFormCropPickRow>]
        def list_crop_pick_rows_for_pesticide_master_form(crop_list_filter:)
          raise NotImplementedError, "Subclasses must implement list_crop_pick_rows_for_pesticide_master_form"
        end

        # @param pest_list_filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        # @return [Array<Domain::Pesticide::Dtos::PesticideMasterFormPestPickRow>]
        def list_pest_pick_rows_for_pesticide_master_form(pest_list_filter:)
          raise NotImplementedError, "Subclasses must implement list_pest_pick_rows_for_pesticide_master_form"
        end

        # HTML 新規・作成検証失敗の再描画用（スナップショット + プルダウン行）
        def pesticide_html_master_form_bundle(assign_attributes:, crop_list_filter:, pest_list_filter:)
          raise NotImplementedError, "Subclasses must implement pesticide_html_master_form_bundle"
        end

        # HTML 更新検証失敗の再描画用（スナップショット + プルダウン行）
        def pesticide_html_master_form_bundle_after_update_merge!(user:, pesticide_id:, assign_attributes:, access_filter:, crop_list_filter:, pest_list_filter:)
          raise NotImplementedError, "Subclasses must implement pesticide_html_master_form_bundle_after_update_merge!"
        end

        # HTML 編集画面の作物・害虫プルダウン行のみ
        def pesticide_html_pick_list_bundle(crop_list_filter:, pest_list_filter:)
          raise NotImplementedError, "Subclasses must implement pesticide_html_pick_list_bundle"
        end
      end
    end
  end
end
