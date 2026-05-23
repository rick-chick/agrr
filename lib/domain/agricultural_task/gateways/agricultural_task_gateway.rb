# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskGateway
        def list_user_owned_tasks(user_id:, query: nil)
          raise NotImplementedError, "Subclasses must implement list_user_owned_tasks"
        end

        def list_reference_tasks(query: nil)
          raise NotImplementedError, "Subclasses must implement list_reference_tasks"
        end

        def list_user_and_reference_tasks(user_id:, query: nil)
          raise NotImplementedError, "Subclasses must implement list_user_and_reference_tasks"
        end

        def authorized_agricultural_task_detail_output(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement authorized_agricultural_task_detail_output"
        end

        def find_authorized_for_edit(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_authorized_agricultural_task_loaded_bundle!(user, id, for_edit:, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_agricultural_task_loaded_bundle!"
        end

        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        # @param selected_crop_ids [Array<Integer>, nil] nil のとき作物テンプレート同期を行わない（API 等）
        def update_for_user(user, id, attrs, access_filter:, selected_crop_ids: nil)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_delete_with_undo(user:, task_id:, auto_hide_after:, translator:, access_filter:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end

        # 作物選択 UI: 当該農業作業に紐づく CropTaskTemplate の作物 ID 一覧
        def linked_crop_ids_for_task_templates(agricultural_task_id)
          raise NotImplementedError, "Subclasses must implement linked_crop_ids_for_task_templates"
        end

        # HTML 新規フォーム用の未保存タスク（永続化しない）
        def build_blank_agricultural_task_for_master_form(user)
          raise NotImplementedError, "Subclasses must implement build_blank_agricultural_task_for_master_form"
        end

        # マスタCRUD 作成失敗時: 送信属性で検証エラー状態を再現（永続化しない）
        def build_after_create_failure_agricultural_task_for_master_form!(user:, attributes:)
          raise NotImplementedError, "Subclasses must implement build_after_create_failure_agricultural_task_for_master_form!"
        end

        # マスタCRUD 更新失敗時: DTO とパラメータ束をマージして検証エラー状態を再現（永続化しない）
        def merge_update_form_snapshot_for_master_form!(user:, task_id:, dto:, task_attributes:, access_filter:)
          raise NotImplementedError, "Subclasses must implement merge_update_form_snapshot_for_master_form!"
        end

        # HTML 編集の作物選択データ読込: update 時は送信パラメータを反映したプレビュー用エンティティを返す（永続化しない）
        # @param base_entity [Domain::AgriculturalTask::Entities::AgriculturalTaskEntity]
        # @return [Domain::AgriculturalTask::Entities::AgriculturalTaskEntity]
        def preview_agricultural_task_for_edit_crop_selection(base_entity:, user:, agricultural_task_params:)
          raise NotImplementedError, "Subclasses must implement preview_agricultural_task_for_edit_crop_selection"
        end
      end
    end
  end
end
