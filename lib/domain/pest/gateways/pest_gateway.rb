# frozen_string_literal: true

module Domain
  module Pest
    module Gateways
      class PestGateway
        def find_by_id(pest_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(pest_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        # 詳細 DTO（関連込み）。認可は Interactor 側（R0）。
        # ネスト害虫用。認可は Interactor（NestedCropPestsAccess）側。
        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        # @return [Domain::Pest::Dtos::PestDeleteUsage]
        def find_delete_usage(pest_id)
          raise NotImplementedError, "Subclasses must implement find_delete_usage"
        end

        def soft_delete_with_undo(user:, pest_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end

        # HTML トップレベル編集（`/pests/:id/edit`）用。防除方法が 0 件なら空行を build。
        # @param pest_record [Pest]
        # @return [Pest] pest_record
        # @param order [Symbol] :recent_first | :id_asc
        # @return [Array<Domain::Pest::Entities::PestEntity>] 作物に紐づく害虫（HTML/API ともにエンティティ）
        def list_pests_for_crop_filtered(crop_id:, pest_ids:, order: :recent_first)
          raise NotImplementedError, "Subclasses must implement list_pests_for_crop_filtered"
        end

        # AI API: ユーザー害虫を名前で検索（なければ nil）。
        # @return [Domain::Pest::Entities::PestEntity, nil]
        def find_by_name(user_id:, name:)
          raise NotImplementedError, "Subclasses must implement find_by_name"
        end

      end
    end
  end
end
