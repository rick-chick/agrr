# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class AgriculturalTaskPolicy
        # ユーザーにとって閲覧可能な AgriculturalTask 一覧スコープ
        # Usage: AgriculturalTaskPolicy.visible_scope(AgriculturalTask, user)
        def self.visible_scope(model_class, user)
          ReferencableResourcePolicy.visible_scope_for(model_class, user)
        end

        # 指定ユーザーが所有する非参照タスクのみのスコープ
        # PlansController などで「ユーザー作物（is_reference: false）」を扱う用途で使用する
        def self.user_owned_non_reference_scope(model_class, user)
          model_class.where(user_id: user.id, is_reference: false)
        end

        # create 用ビルダー
        # - 管理者: is_reference=true なら user_id=nil / false なら user_id=admin.id
        # - 一般ユーザー: controller 側で参照タスク作成は弾かれる前提で、常に user_id=current_user.id, is_reference=false
        def self.build_for_create(model_class, user, attrs)
          attributes = attrs.to_h.symbolize_keys
          is_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference]) || false

          if user.admin?
            if is_reference
              attributes[:user_id] = nil
              attributes[:is_reference] = true
            else
              attributes[:user_id] ||= user.id
              attributes[:is_reference] = false
            end
          else
            attributes[:user_id] = user.id
            attributes[:is_reference] = false
          end

          model_class.new(attributes)
        end

        # show 用の1件取得
        # - 管理者: すべてのタスクにアクセス可能
        # - 一般ユーザー: 参照タスク または 自分のタスク
        def self.find_visible!(model_class, user, id)
          task = model_class.find(id)
          unless user.admin? || task.is_reference || task.user_id == user.id
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          task
        end

        # 編集・更新・削除用の1件取得
        # - 管理者: すべてのタスクを編集可能
        # - 一般ユーザー: 自分の非参照タスクのみ
        def self.find_editable!(model_class, user, id)
          task = model_class.find(id)
          allowed =
            if user.admin?
              true
            else
              !task.is_reference && task.user_id == user.id
            end

          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          task
        end

        # update 用適用メソッド
        # - is_reference の変更可否そのものは controller 側の reference_flag_admin_only ガードで制御
        # - ここでは is_reference が変わる場合のみ user_id を整合させる
        def self.apply_update!(user, task, attrs)
          attributes = attrs.to_h.symbolize_keys

          if attributes.key?(:is_reference)
            requested_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference])
            requested_reference = false if requested_reference.nil?

            reference_changed = requested_reference != task.is_reference

            if reference_changed
              if requested_reference
                # 参照化: システム所有
                attributes[:user_id] = nil
              else
                # 非参照化: 編集ユーザー所有（到達するのは管理者のみ）
                attributes[:user_id] = user.id
              end

              attributes[:is_reference] = requested_reference
            else
              # 変更がない場合はフラグ更新を行わない
              attributes.delete(:is_reference)
            end
          end

          task.update(attributes)
        end

        # 参照タスクのスコープ（region でフィルタ可能）
        # Usage: AgriculturalTaskPolicy.reference_scope(AgriculturalTask, region: 'jp')
        def self.reference_scope(model_class, region: nil)
          scope = model_class.reference
          scope = scope.where(region: region) if region
          scope
        end
      end
    end
  end
end