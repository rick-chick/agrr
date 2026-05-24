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

        def selectable_pest_ids(user)
          raise NotImplementedError, "Subclasses must implement selectable_pest_ids"
        end

        def pest_selectable_by_user?(user, pest_id)
          raise NotImplementedError, "Subclasses must implement pest_selectable_by_user?"
        end

        def list_selectable_pest_entities_recent_first(user)
          raise NotImplementedError, "Subclasses must implement list_selectable_pest_entities_recent_first"
        end

        # 詳細 DTO（関連込み）。認可は Interactor 側（R0）。
        def find_pest_show_detail(id)
          raise NotImplementedError, "Subclasses must implement find_pest_show_detail"
        end

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

        # AR を Domain に持ち込まないためのマスタ系操作。

        def crop_pest_association_exists?(crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement crop_pest_association_exists?"
        end

        # 既存の Pest を crop に紐付ける（id ベース）。認可・重複判定は Interactor。
        # @return [Symbol] :linked / :missing
        def link_pest_to_crop(crop_id:, pest_id:, user:)
          raise NotImplementedError, "Subclasses must implement link_pest_to_crop"
        end

        # 新規作成 + crop への紐付け（HTML/Masters 共用）。pest_attrs は Interactor で PestPolicy 正規化済み。
        # @return [Hash] { status: :created|:invalid, pest_snapshot: PestCropNestSnapshot, unassociated_pest_entities: [...] }
        def create_pest_for_crop(user:, crop_id:, pest_attrs:, crop_access_filter:)
          raise NotImplementedError, "Subclasses must implement create_pest_for_crop"
        end

        # crop 配下の Pest を更新する。pest_attrs は Interactor で正規化済み。
        # @return [Hash] { status: :updated|:invalid|:crop_missing|:pest_missing, pest_snapshot: PestCropNestSnapshot|nil }
        def update_pest_for_crop(user:, crop_id:, pest_id:, pest_attrs:, crop_access_filter:)
          raise NotImplementedError, "Subclasses must implement update_pest_for_crop"
        end

        # crop 配下の Pest を取得する（HTML 編集等向け）。
        # @param for_edit_form [Boolean] true のとき防除方法が 0 件なら空行を補完する
        # @return [Hash] { status: :found|:not_found, pest_snapshot: PestCropNestSnapshot|nil }
        def find_pest_in_crop(crop_id:, pest_id:, crop_access_filter:, for_edit_form: false)
          raise NotImplementedError, "Subclasses must implement find_pest_in_crop"
        end

        # HTML トップレベル編集（`/pests/:id/edit`）用。防除方法が 0 件なら空行を build。
        # @param pest_record [Pest]
        # @return [Pest] pest_record
        # @param order [Symbol] :recent_first | :id_asc
        # @return [Array<Domain::Pest::Entities::PestEntity>] 作物に紐づく害虫（HTML/API ともにエンティティ）
        def list_pests_for_crop_filtered(crop_id:, pest_ids:, order: :recent_first)
          raise NotImplementedError, "Subclasses must implement list_pests_for_crop_filtered"
        end

        # Pest 作成後に作物群と関連付け。
        def associate_crops_with_pest_id(pest_id:, crop_ids:, user:)
          raise NotImplementedError, "Subclasses must implement associate_crops_with_pest_id"
        end

        # Pest 更新後の作物関連付け差分更新。
        def update_pest_crop_associations(pest_id:, crop_ids:, user:)
          raise NotImplementedError, "Subclasses must implement update_pest_crop_associations"
        end

        # AI Pest API: affected_crops ペイロードを解決して害虫に作物を関連付ける。
        # ActiveRecord::ActiveRecordError は永続化境界で捕捉しログに留める（コントローラで rescue しない）。
        #
        # @param logger [Domain::Shared::Ports::LoggerPort]
        # @return [Integer] 新規に紐づけた件数（既存リンクは含まない）
        def associate_affected_crops_for_ai_pest(pest_id:, affected_crops:, user:, logger:)
          raise NotImplementedError, "Subclasses must implement associate_affected_crops_for_ai_pest"
        end

        # AI API: ユーザー害虫を名前で検索（なければ nil）。
        # @return [Domain::Pest::Entities::PestEntity, nil]
        def find_by_name(user_id:, name:)
          raise NotImplementedError, "Subclasses must implement find_by_name"
        end

        # 作物に紐づく害虫 ID の一覧（新規フォームの除外判定用）。
        # @return [Array<Integer>]
        def pest_ids_linked_to_crop(crop_id:)
          raise NotImplementedError, "Subclasses must implement pest_ids_linked_to_crop"
        end

        # 作物から害虫の関連を外す（永続化のみ）。関連の有無は Interactor が crop_pest_association_exists? で判定。
        # @return [Symbol] :ok / :crop_not_found / :pest_not_found
        def unlink_pest_from_crop(crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement unlink_pest_from_crop"
        end

      end
    end
  end
end
