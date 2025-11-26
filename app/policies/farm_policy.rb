 # frozen_string_literal: true

class FarmPolicy
  # HTML/JSON 双方から利用する、Farm の所有権ポリシー
  #
  # - ユーザー所有農場（is_reference: false, user_id = user.id）のみを「所有」とみなす
  # - 参照農場（is_reference: true）は PublicPlans 等で個別に利用

  # ユーザー所有の農場スコープ
  # Usage: FarmPolicy.user_owned_scope(user)
  def self.user_owned_scope(user)
    Farm.user_owned.by_user(user)
  end

  # 所有する農場1件を取得（存在しない or 権限なし → PolicyPermissionDenied）
  #
  # - 一般ユーザー: 自分の user_owned 農場のみ
  # - 管理者: 既存の実装どおり、自分の農場 + 任意の農場にアクセス可能
  def self.find_owned!(user, id)
    farm = Farm.find(id)

    allowed =
      if user.admin?
        true
      else
        !farm.is_reference && farm.user_id == user.id
      end

    raise PolicyPermissionDenied unless allowed

    farm
  end

  # create 用ビルダー
  # - HTML / Masters API ともに「ユーザー所有・非参照農場」を作成する前提
  def self.build_for_create(user, attrs)
    attributes = attrs.to_h.symbolize_keys

    attributes[:user_id] = user.id
    attributes[:is_reference] = false

    Farm.new(attributes)
  end

  # 参照農場のスコープ（region でフィルタ可能）
  # Usage: FarmPolicy.reference_scope(region: 'jp')
  def self.reference_scope(region: nil)
    scope = Farm.reference
    scope = scope.where(region: region) if region
    scope
  end
end

