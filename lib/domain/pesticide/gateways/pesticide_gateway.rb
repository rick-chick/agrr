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

        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        # 農薬の HTML/API 詳細用 DTO（1 回の読み込みで関連名・制約を含む。認可は Interactor 側）
        def find_pesticide_show_detail(id)
          raise NotImplementedError, "Subclasses must implement find_pesticide_show_detail"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_delete_with_undo(user:, pesticide_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end

        # Crop に紐づく、user に閲覧可能な Pesticide エンティティを最近順で返す。
        # @return [Array<Domain::Pesticide::Entities::PesticideEntity>] entities or AR records
        def list_for_crop_with_user(crop_id:, user:)
          raise NotImplementedError, "Subclasses must implement list_for_crop_with_user"
        end

      end
    end
  end
end
