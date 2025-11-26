# frozen_string_literal: true

class PesticidePolicy
  Pesticide.include(ReferencableResourcePolicy) unless Pesticide.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Pesticide 一覧スコープ
  # - 管理者: 参照農薬 + 自分の農薬
  # - 一般ユーザー: 自分の非参照農薬のみ
  def self.visible_scope(user)
    Pesticide.visible_scope_for(user)
  end

  # 選択可能な Pesticide 一覧スコープ（参照データも含む）
  # - 管理者: 参照農薬 + 自分の農薬
  # - 一般ユーザー: 参照農薬 + 自分の農薬（選択候補として参照データも含む）
  def self.selectable_scope(user)
    Pesticide.where("is_reference = ? OR user_id = ?", true, user.id)
  end

  # create 用ビルダー
  # - 管理者: is_reference=true なら user_id=nil / false なら user_id=admin.id
  # - 一般ユーザー: controller 側で参照農薬作成は弾かれる前提で、常に user_id=current_user.id, is_reference=false
  def self.build_for_create(user, attrs)
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

    Pesticide.new(attributes)
  end

  # 一覧スコープに基づいて1件取得（見えるもの＝編集可能なもの）
  # - 存在しないID      : ActiveRecord::RecordNotFound
  # - 存在するが権限なし: PolicyPermissionDenied
  def self.find_visible!(user, id)
    pesticide = Pesticide.find(id)
    unless visible_scope(user).exists?(id: pesticide.id)
      raise PolicyPermissionDenied
    end
    pesticide
  end

  # Pesticide では「見えるもの＝編集可能なもの」とする
  def self.find_editable!(user, id)
    find_visible!(user, id)
  end

  # update 用適用メソッド
  # - is_reference の変更可否そのものは controller 側の reference_flag_admin_only ガードで制御
  # - ここでは is_reference が変わる場合のみ user_id を整合させる
  def self.apply_update!(user, pesticide, attrs)
    attributes = attrs.to_h.symbolize_keys

    if attributes.key?(:is_reference)
      requested_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference])
      requested_reference = false if requested_reference.nil?

      reference_changed = requested_reference != pesticide.is_reference

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

    pesticide.update(attributes)
  end
end
