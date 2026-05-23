# frozen_string_literal: true

module Domain
  module Fertilize
    module Gateways
      class FertilizeGateway
        def find_by_id(fertilize_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(fertilize_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        def find_fertilize_loaded_bundle!(id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_fertilize_loaded_bundle!"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_delete_with_undo(user:, fertilize_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end

        # 新規マスタフォーム用スナップショット（永続化しない）
        # @return [Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot]
        def blank_fertilize_master_form_snapshot
          raise NotImplementedError, "Subclasses must implement blank_fertilize_master_form_snapshot"
        end

        # 作成検証失敗時のスナップショット（永続化しない）
        # @return [Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot]
        def fertilize_master_form_snapshot_after_create_failure!(user:, attributes:)
          raise NotImplementedError, "Subclasses must implement fertilize_master_form_snapshot_after_create_failure!"
        end

        # AI API: ユーザー肥料を agrr 応答の商品名で検索（なければ nil）。戻りは永続 Fertilize。
        def find_by_name(user_id:, name:)
          raise NotImplementedError, "Subclasses must implement find_by_name"
        end

      end
    end
  end
end
