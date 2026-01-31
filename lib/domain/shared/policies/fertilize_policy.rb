# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class FertilizePolicy
        # ユーザーにとって閲覧可能な Fertilize 一覧スコープ
        # Usage: FertilizePolicy.visible_scope(Fertilize, user)
        def self.visible_scope(model_class, user)
          ReferencableResourcePolicy.visible_scope_for(model_class, user)
        end

        # create 用ビルダー
        # - 管理者: is_reference=true なら user_id=nil / false なら user_id=admin.id
        # - 一般ユーザー: controller 側で参照肥料作成は弾かれる前提で、常に user_id=current_user.id, is_reference=false
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
        # - 管理者: すべての肥料にアクセス可能
        # - 一般ユーザー: 自分の非参照肥料のみ（参照肥料は閲覧不可）
        def self.find_visible!(model_class, user, id)
          fertilize = model_class.find(id)
          unless user.admin? || (fertilize.user_id == user.id && !fertilize.is_reference)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          fertilize
        end

        # 編集・更新・削除用の1件取得
        # - 管理者: すべての肥料を編集可能
        # - 一般ユーザー: 自分の非参照肥料のみ
        def self.find_editable!(model_class, user, id)
          fertilize = model_class.find(id)
          allowed =
            if user.admin?
              true
            else
              !fertilize.is_reference && fertilize.user_id == user.id
            end

          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          fertilize
        end

        # update 用適用メソッド
        # - is_reference の変更可否そのものは controller 側の reference_flag_admin_only ガードで制御
        # - ここでは is_reference が変わる場合のみ user_id を整合させる
        def self.apply_update!(user, fertilize, attrs)
          attributes = attrs.to_h.symbolize_keys

          if attributes.key?(:is_reference)
            requested_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference])
            requested_reference = false if requested_reference.nil?

            reference_changed = requested_reference != fertilize.is_reference

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

          fertilize.update(attributes)
        end
      end
    end
  end
end