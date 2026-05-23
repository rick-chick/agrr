# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      # 参照可能リソース（is_reference / user_id）の可視性ルール。
      # ActiveRecord には触れない。Gateway が scope 構築に利用する。
      module ReferencableResourcePolicy
        module_function

        # 管理者: 参照データ OR 自分のデータ
        # 非管理者: 自分の非参照データのみ
        def visible_for_user?(user, is_reference:, user_id:)
          uid = user_id
          if user.admin?
            is_reference == true || uid == user.id
          else
            !is_reference && uid == user.id
          end
        end

        # 一覧用: 管理者は (is_reference OR user_id) / 一般は (user_id かつ非参照)
        def list_allowed_sql_params(user)
          if user.admin?
            { mode: :admin, user_id: user.id }
          else
            { mode: :non_admin, user_id: user.id }
          end
        end

        # ---- 参照可能マスタの認可ルール（crop / fertilize / pesticide / pest /
        #      agricultural_task で共通。各 *Policy はここへ委譲する）----

        # 参照フラグ（is_reference）を新規付与してよいか。admin のみ true を許される。
        def reference_assignment_allowed?(user, is_reference:)
          !is_reference || user.admin?
        end

        # 既存レコードの参照フラグを requested へ変更してよいか。
        # 変更しない（requested == current）か、admin のみ許される。
        def reference_flag_change_allowed?(user, requested:, current:)
          requested == current || user.admin?
        end

        # 作成属性の正規化。region は admin（または admin_forced）のみ保持。
        # 参照レコードは user_id=nil、非参照は呼び出しユーザー所有に正規化する。
        # @param admin_forced [Boolean] admin 権限を強制（バルク取込等の特権経路用）
        def normalize_referencable_attrs_for_create(user, attrs, admin_forced: false)
          h = Domain::Shared.symbolize_keys(attrs.to_h)
          privileged = user.admin? || admin_forced
          h.delete(:region) unless privileged

          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(h[:is_reference]) || false

          if privileged
            if is_reference
              h[:user_id] = nil
              h[:is_reference] = true
            else
              h[:user_id] ||= user.id
              h[:is_reference] = false
            end
          else
            h[:user_id] = user.id
            h[:is_reference] = false
          end

          h
        end

        # 更新属性の正規化。region は admin のみ保持。is_reference の変更があれば
        # user_id を連動させる（参照化→nil / 参照解除→操作ユーザー）。
        # @param current_attrs [Hash] 現在値スナップショット（:is_reference を含む）
        # ---- HTML 表示フラグ（ERB の admin_user? / user_id 比較を置き換える）----

        def show_reference_badge?(user, is_reference:)
          user.admin? && is_reference
        end

        # 参照レコードは admin のみ、非参照は所有者または admin。
        def show_edit_actions?(user, is_reference:, user_id:)
          if is_reference
            user.admin?
          else
            user.admin? || user_id == user.id
          end
        end

        def show_reference_form_fields?(user)
          user.admin?
        end

        def show_crop_stage_remove_button?(user, crop_is_reference:, crop_user_id:)
          !crop_is_reference || user.admin?
        end

        def show_add_crop_stage_button?(user, crop_is_reference:, crop_user_id:)
          show_crop_stage_remove_button?(user, crop_is_reference: crop_is_reference, crop_user_id: crop_user_id)
        end

        def show_generate_task_schedule_blueprints_button?(user, crop_is_reference:, crop_user_id:)
          user.admin?
        end

        def show_delete_task_schedule_blueprint_button?(user, crop_is_reference:, crop_user_id:)
          user.admin? || (!crop_is_reference && crop_user_id == user.id)
        end

        def show_admin_list_filters?(user)
          user.admin?
        end

        def show_reference_rules_section?(user, reference_rules_any:)
          user.admin? && reference_rules_any
        end

        def show_my_rules_section_header?(user, reference_rules_any:)
          user.admin? && reference_rules_any
        end

        def normalize_referencable_attrs_for_update(user, current_attrs, requested_attrs)
          current = Domain::Shared.symbolize_keys(current_attrs.to_h)
          attributes = Domain::Shared.symbolize_keys(requested_attrs.to_h)
          attributes.delete(:region) unless user.admin?

          if attributes.key?(:is_reference)
            requested_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attributes[:is_reference])
            requested_reference = false if requested_reference.nil?

            if requested_reference != current[:is_reference]
              attributes[:user_id] = requested_reference ? nil : user.id
              attributes[:is_reference] = requested_reference
            else
              attributes.delete(:is_reference)
            end
          end

          attributes
        end
      end
    end
  end
end
