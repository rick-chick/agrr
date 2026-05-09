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

        def destroy(pesticide_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        # 認可済み農薬の HTML/API 詳細用 DTO（1 回の読み込みで関連名・制約を含む）
        def authorized_pesticide_detail_output(user, id)
          raise NotImplementedError, "Subclasses must implement authorized_pesticide_detail_output"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_authorized_model_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_view"
        end

        def find_authorized_model_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_edit"
        end

        def find_authorized_pesticide_loaded_bundle!(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_pesticide_loaded_bundle!"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_destroy_with_undo(user:, pesticide_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end

        # Crop に紐づく、user に閲覧可能な Pesticide エンティティを最近順で返す。
        # @return [Array<Domain::Pesticide::Entities::PesticideEntity>] entities or AR records
        def list_for_crop_with_user(crop_id:, user:)
          raise NotImplementedError, "Subclasses must implement list_for_crop_with_user"
        end

        # マスタCRUD 新規フォーム用の空レコード（ネストした constraint / application_detail を build）
        def build_blank_pesticide_for_master_form
          raise NotImplementedError, "Subclasses must implement build_blank_pesticide_for_master_form"
        end

        # マスタCRUD create 失敗時のフォーム再表示用（未保存）
        def build_pesticide_for_create_failure_master_form(attributes_hash)
          raise NotImplementedError, "Subclasses must implement build_pesticide_for_create_failure_master_form"
        end

        # マスタCRUD edit / update 失敗時にネストが欠けていれば build
        def ensure_nested_associations_for_pesticide_master_form!(pesticide)
          raise NotImplementedError, "Subclasses must implement ensure_nested_associations_for_pesticide_master_form!"
        end

        # マスタCRUD update 失敗時の再表示用
        def assign_pesticide_attributes_for_master_form!(pesticide, attributes_hash)
          raise NotImplementedError, "Subclasses must implement assign_pesticide_attributes_for_master_form!"
        end

        # 農薬フォームで選択可能な作物スコープ（永続層・ポリシーはアダプター側）
        def accessible_crops_scope_for_pesticide_master_form(user:)
          raise NotImplementedError, "Subclasses must implement accessible_crops_scope_for_pesticide_master_form"
        end

        def accessible_pests_scope_for_pesticide_master_form(user:)
          raise NotImplementedError, "Subclasses must implement accessible_pests_scope_for_pesticide_master_form"
        end
      end
    end
  end
end
