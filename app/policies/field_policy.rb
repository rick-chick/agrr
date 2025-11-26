 # frozen_string_literal: true

class FieldPolicy
  # Field の所有権ポリシー
  #
  # - 基本的には「紐づく Farm がユーザーのもの」であることを前提とする
  # - Field 自体の user_id も存在するが、既存実装同様 farm.user_id を主とする

  # 指定ユーザー・指定農場に属する圃場スコープ
  # Usage: FieldPolicy.scope_for_farm(user, farm)
  def self.scope_for_farm(user, farm)
    raise PolicyPermissionDenied unless farm.user_id == user.id || user.admin?

    farm.fields
  end

  # 所有する圃場1件を取得（存在しない or 権限なし → PolicyPermissionDenied）
  #
  # - 一般ユーザー: 自分の農場に属する圃場のみ
  # - 管理者: 既存の実装どおり、任意の圃場にアクセス可能
  def self.find_owned!(user, id)
    field = Field.find(id)

    allowed =
      if user.admin?
        true
      else
        field.farm.user_id == user.id
      end

    raise PolicyPermissionDenied unless allowed

    field
  end

  # create 用ビルダー
  # - 呼び出し側で FarmPolicy により所有農場であることを確認済みである前提
  def self.build_for_create(user, farm, attrs)
    attributes = attrs.to_h.symbolize_keys

    attributes[:user_id] ||= user.id
    attributes[:farm_id] = farm.id

    Field.new(attributes)
  end
end

