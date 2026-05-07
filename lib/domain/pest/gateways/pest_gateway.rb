# frozen_string_literal: true

module Domain
  module Pest
    module Gateways
      class PestGateway
        # @param query [Domain::Shared::Dtos::QueryDto, nil] クエリ条件。nil の場合は全件
        def list(query = nil)
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(pest_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(pest_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def list_index_for_user(user)
          raise NotImplementedError, "Subclasses must implement list_index_for_user"
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

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def authorized_pest_detail_output(user, id)
          raise NotImplementedError, "Subclasses must implement authorized_pest_detail_output"
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

        # 認可済み害虫を一度読み、Entity と永続モデルを束ねる（Interactor が port に載せる DTO）。
        def find_authorized_pest_loaded_bundle!(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_pest_loaded_bundle!"
        end

        def find_model(id)
          raise NotImplementedError, "Subclasses must implement find_model"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_destroy_with_undo(user:, pest_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end

        # AR を Domain に持ち込まないためのマスタ系操作。

        # 既存の Pest を crop に紐付ける（id ベース）。
        # @return [Symbol] :linked / :already_linked / :missing
        def link_pest_to_crop_id(crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement link_pest_to_crop_id"
        end

        # 新規作成 + crop への紐付け（HTML/Masters 共用）。
        # @return [Hash] { status: :created|:invalid, pest_record:, unassociated_pest_entities: [...] }
        def create_pest_for_crop(user:, crop_id:, pest_attrs:, admin:)
          raise NotImplementedError, "Subclasses must implement create_pest_for_crop"
        end

        # crop 配下の Pest を更新する。
        # @return [Hash] { status: :updated|:invalid|:reference_flag_denied, pest_record: }
        def update_pest_for_crop(crop_id:, pest_id:, pest_attrs:, admin:)
          raise NotImplementedError, "Subclasses must implement update_pest_for_crop"
        end

        # crop 配下の Pest を取得する（HTML 編集等向け）。
        # @return [Hash] { status: :found|:not_found, pest_record: }
        def find_pest_in_crop(crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement find_pest_in_crop"
        end

        # Mutates the persisted Pest AR for nested-attributes UX (build empty pest_control_methods when none).
        # 同一 AR を破壊的に変更する（防除方法が 0 件のときに空行を build）。
        # @param pest_record [Pest]
        # @return [Pest] pest_record
        def prepare_crop_nested_pest_for_edit_form!(pest_record)
          raise NotImplementedError, "Subclasses must implement prepare_crop_nested_pest_for_edit_form!"
        end

        # 新規 Pest フォーム描画用の空インスタンスをビルド（nested 関連付き）。
        # @return [Pest] 未保存の AR レコード（HTML form_with で使う）
        def build_blank_pest_for_form
          raise NotImplementedError, "Subclasses must implement build_blank_pest_for_form"
        end

        # @param order [Symbol] :recent_first | :id_asc
        # @return [Array<Domain::Pest::Entities::PestEntity>] 作物に紐づく害虫（HTML/API ともにエンティティ）
        def list_pests_for_crop_filtered(crop_id:, pest_ids:, order: :recent_first)
          raise NotImplementedError, "Subclasses must implement list_pests_for_crop_filtered"
        end

        # PestCropAssociationService の置換。Pest 作成後に作物群と関連付け。
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
        # @param logger [Domain::Logger::Gateways::LoggerGateway]
        # @return [Integer] 新規に紐づけた件数（既存リンクは含まない）
        def associate_affected_crops_for_ai_pest(pest_id:, affected_crops:, user:, logger:)
          raise NotImplementedError, "Subclasses must implement associate_affected_crops_for_ai_pest"
        end

        # AI API: ユーザー害虫を名前で検索（なければ nil）。戻りは永続 Pest。
        def find_user_owned_non_reference_pest_record_by_name(user_id:, name:)
          raise NotImplementedError, "Subclasses must implement find_user_owned_non_reference_pest_record_by_name"
        end

        # マスター API: 作物から害虫の関連を外す（ユーザー作物のみ）
        # @return [Symbol] :ok / :crop_not_found / :pest_not_found / :not_associated
        def unlink_pest_from_crop_for_masters(user:, crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement unlink_pest_from_crop_for_masters"
        end
      end
    end
  end
end
