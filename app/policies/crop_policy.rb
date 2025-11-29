# frozen_string_literal: true

class CropPolicy
  # Crop モデルに ReferencableResourcePolicy をミックスインして利用する
  Crop.include(ReferencableResourcePolicy) unless Crop.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Crop 一覧スコープ
  # Usage: CropPolicy.visible_scope(user)
  def self.visible_scope(user)
    Crop.visible_scope_for(user)
  end

  # 指定ユーザーが所有する非参照作物のみのスコープ
  # PlansController などで「ユーザー作物（is_reference: false）」を扱う用途で使用する
  def self.user_owned_non_reference_scope(user)
    Crop.where(user_id: user.id, is_reference: false)
  end

  # create 用ビルダー
  # - 管理者: is_reference=true なら user_id=nil / false なら user_id=admin.id
  # - 一般ユーザー: controller 側で参照作物作成は弾かれる前提で、常に user_id=current_user.id, is_reference=false
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

    Crop.new(attributes)
  end

  # show 用の1件取得
  # - 管理者: すべての作物にアクセス可能
  # - 一般ユーザー: 参照作物 または 自分の作物
  def self.find_visible!(user, id)
    crop = Crop.find(id)
    unless user.admin? || crop.is_reference || crop.user_id == user.id
      raise PolicyPermissionDenied
    end
    crop
  end

  # 編集・更新・削除用の1件取得
  # - 管理者: すべての作物を編集可能
  # - 一般ユーザー: 自分の非参照作物のみ
  def self.find_editable!(user, id)
    crop = Crop.find(id)
    allowed =
      if user.admin?
        true
      else
        !crop.is_reference && crop.user_id == user.id
      end

    raise PolicyPermissionDenied unless allowed

    crop
  end

  # update 用適用メソッド
  # - is_reference の変更可否そのものは controller 側の reference_flag_admin_only ガードで制御
  # - ここでは is_reference が変わる場合のみ user_id を整合させる
  def self.apply_update!(user, crop, attrs)
    attributes = attrs.to_h.symbolize_keys

    if attributes.key?(:is_reference)
      requested_reference = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference])
      requested_reference = false if requested_reference.nil?

      reference_changed = requested_reference != crop.is_reference

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

    crop.update(attributes)
  end

  # 参照作物のスコープ（region でフィルタ可能）
  # Usage: CropPolicy.reference_scope(region: 'jp')
  def self.reference_scope(region: nil)
    scope = Crop.reference
    scope = scope.where(region: region) if region
    scope
  end
end
