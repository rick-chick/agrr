# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class InteractionRulePolicy
        # ユーザーにとって閲覧可能な InteractionRule 一覧スコープ
        # Usage: InteractionRulePolicy.visible_scope(InteractionRule, user)
        def self.visible_scope(model_class, user)
          ReferencableResourcePolicy.visible_scope_for(model_class, user)
        end

        # create 用のビルダー
        # - 管理者: is_reference = true の場合は user_id=nil / それ以外は user_id=admin.id（明示）
        # - 一般ユーザー: is_reference=true を禁止（controller側でreference_only_adminを返す）
        def self.build_for_create(model_class, user, params)
          attributes = params.to_h.symbolize_keys

          # 一般ユーザーの場合はregionパラメータを除外
          attributes.delete(:region) unless user.admin?

          is_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference]) || false

          rule = model_class.new(attributes)

          if is_reference
            # 参照ルールはシステム所有（user_id=nil）
            rule.user_id = nil
            rule.is_reference = true
          else
            # 非参照ルールは作成ユーザー所有
            rule.user_id ||= user.id
            rule.is_reference = false if rule.is_reference.nil?
          end

          [rule, is_reference]
        end

        # show 用の1件取得
        # - 管理者: すべてのルールにアクセス可能
        # - 一般ユーザー: 自分のルールのみ
        def self.find_visible!(model_class, user, id)
          rule = model_class.find(id)
          unless user.admin? || rule.user_id == user.id
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          rule
        end

        # 編集・更新・削除用の1件取得
        # - 管理者: すべてのルールを編集可能
        # - 一般ユーザー: user_owned（非参照）かつ自分のルールのみ
        def self.find_editable!(model_class, user, id)
          rule = model_class.find(id)
          unless user.admin? || (!rule.is_reference && rule.user_id == user.id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          rule
        end

        # update 用の適用メソッド
        # - is_reference パラメータが含まれている場合のみ参照フラグ変更を検討
        # - 一般ユーザーの参照フラグ変更は controller 側で事前に弾く前提
        def self.apply_update!(user, rule, params)
          update_params = params.dup

          # 一般ユーザーの場合はregionパラメータを除外
          update_params.delete(:region) unless user.admin?

          if update_params.key?(:is_reference)
            requested_reference = ActiveModel::Type::Boolean.new.cast(update_params[:is_reference]) || false
            reference_changed = requested_reference != rule.is_reference

            if reference_changed
              # 参照フラグが変わる場合のみ user_id を調整
              if requested_reference
                # 参照化: システム所有
                update_params[:user_id] = nil
              else
                # 非参照化: 編集ユーザー所有（管理者のみ到達）
                update_params[:user_id] = user.id
              end
            end
          end

          rule.update(update_params)
        end
      end
    end
  end
end