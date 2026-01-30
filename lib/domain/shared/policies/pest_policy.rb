# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class PestPolicy
        # ユーザーにとって閲覧可能な Pest 一覧スコープ
        # Usage: PestPolicy.visible_scope(Pest, user)
        def self.visible_scope(model_class, user)
          ReferencableResourcePolicy.visible_scope_for(model_class, user)
        end

        # 選択可能な Pest 一覧スコープ（参照データも含む）
        # Usage: PestPolicy.selectable_scope(Pest, user)
        # - 管理者: 参照害虫 + 自分の害虫
        # - 一般ユーザー: 参照害虫 + 自分の害虫（選択候補として参照データも含む）
        def self.selectable_scope(model_class, user)
          model_class.where("is_reference = ? OR user_id = ?", true, user.id)
        end

        # create 用ビルダー
        # Usage: PestPolicy.build_for_create(Pest, user, params, admin_forced: false)
        # - 管理者: is_reference=true なら user_id=nil / false なら user_id=admin.id
        # - 一般ユーザー: is_reference は controller 側で false に強制・user_id=current_user.id に強制
        def self.build_for_create(model_class, user, attrs, admin_forced: false)
          attributes = attrs.to_h.symbolize_keys
          is_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference]) || false

          if user.admin? || admin_forced
            # 管理者作成時のルール
            if is_reference
              attributes[:user_id] = nil
              attributes[:is_reference] = true
            else
              attributes[:user_id] ||= user.id
              attributes[:is_reference] = false
            end
          else
            # 一般ユーザーは常にユーザー害虫
            attributes[:user_id] = user.id
            attributes[:is_reference] = false
          end

          model_class.new(attributes)
        end

        # show 用の1件取得
        # Usage: PestPolicy.find_visible!(Pest, user, id)
        # - 参照害虫 または 自分の害虫（管理者も他人のユーザー害虫にはアクセス不可）
        def self.find_visible!(model_class, user, id)
          pest = model_class.find(id)
          unless pest.is_reference || pest.user_id == user.id
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pest
        end

        # 編集・更新・削除用の1件取得
        # Usage: PestPolicy.find_editable!(Pest, user, id)
        # - 管理者: 参照害虫 + 自分の害虫
        # - 一般ユーザー: 自分の非参照害虫のみ
        def self.find_editable!(model_class, user, id)
          pest = model_class.find(id)

          allowed =
            if user.admin?
              # 参照害虫または自分の害虫のみ編集可能
              pest.is_reference || pest.user_id == user.id
            else
              # 一般ユーザーは自分の非参照害虫のみ編集可能
              !pest.is_reference && pest.user_id == user.id
            end

          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          pest
        end

        # update 用適用メソッド
        # Usage: PestPolicy.apply_update!(user, pest, params)
        # - is_reference の変更可否そのものは controller 側でガード
        # - ここでは is_reference が変わる場合のみ user_id を整合させる
        def self.apply_update!(user, pest, attrs)
          attributes = attrs.to_h.symbolize_keys

          if attributes.key?(:is_reference)
            requested_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference]) || false
            reference_changed = requested_reference != pest.is_reference

            if reference_changed
              if requested_reference
                # 参照化: システム所有
                attributes[:user_id] = nil
              else
                # 非参照化: 編集ユーザー所有（到達するのは管理者のみ）
                attributes[:user_id] = user.id
              end
            end
          end

          success = pest.update(attributes)
          # 関連モデルのバリデーションもチェック
          if success
            success = pest.pest_temperature_profile&.valid? != false &&
                     pest.pest_thermal_requirement&.valid? != false &&
                     pest.pest_control_methods.all? { |method| method.valid? }
          end
          success
        end
      end
    end
  end
end