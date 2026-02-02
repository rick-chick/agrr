# frozen_string_literal: true

require "test_helper"

class Adapters::Farm::Gateways::FarmActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::Farm::Gateways::FarmActiveRecordGateway.new
    @user = create(:user)
    @gateway.user_id = @user.id
  end

  test "should list all farms for admin user" do
    # ユーザー農場を作成（テストユーザーに紐づく）
    user_farm = create(:farm, user: @user, is_reference: false)
    # 参照農場を作成（アノニマスユーザーに属する）
    reference_farm = create(:farm, user: User.anonymous_user, is_reference: true)

    # 管理者用の input_dto を作成
    admin_input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: true)
    entities = @gateway.list(admin_input_dto)

    # 管理者ユーザーの場合は自分の農場と参照農場の両方が含まれる
    farm_ids = entities.map(&:id)
    assert_includes farm_ids, user_farm.id
    assert_includes farm_ids, reference_farm.id
  end

  test "should list only non-reference farms for regular user" do
    # ユーザー農場を作成（テストユーザーに紐づく）
    user_farm = create(:farm, user: @user, is_reference: false)
    # 参照農場を作成（アノニマスユーザーに属する）
    reference_farm = create(:farm, user: User.anonymous_user, is_reference: true)

    # 一般ユーザー用の input_dto を作成
    regular_input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
    entities = @gateway.list(regular_input_dto)

    # 一般ユーザーの場合は参照農場が含まれず、自分の農場のみが含まれる
    farm_ids = entities.map(&:id)
    assert_includes farm_ids, user_farm.id
    assert_not_includes farm_ids, reference_farm.id
  end

  test "should find farm by id" do
    farm = create(:farm, name: "テスト農場", user: @user)

    entity = @gateway.find_by_id(farm.id)

    assert_not_nil entity
    assert_equal farm.id, entity.id
    assert_equal "テスト農場", entity.name
  end

  test "should raise when farm not found" do
    assert_raises(ActiveRecord::RecordNotFound) do
      @gateway.find_by_id(9999)
    end
  end

  test "should create farm" do
    user = create(:user)
    create_input_dto = Domain::Farm::Dtos::FarmCreateInputDto.new(
      name: "新規農場",
      region: "jp",
      latitude: 35.6895,
      longitude: 139.6917,
      user_id: user.id
    )

    entity = @gateway.create(create_input_dto)

    assert_not_nil entity
    assert_equal "新規農場", entity.name
    assert_equal "jp", entity.region
    assert_equal 35.6895, entity.latitude
    assert_equal 139.6917, entity.longitude
    assert_equal user.id, entity.user_id
    assert_not entity.is_reference
  end

  test "should update farm" do
    farm = create(:farm, name: "元の農場", latitude: 35.6895, user: @user)

    update_input_dto = Domain::Farm::Dtos::FarmUpdateInputDto.new(
      farm_id: farm.id,
      name: "更新農場",
      latitude: 36.6895
    )

    entity = @gateway.update(farm.id, update_input_dto)

    assert_equal "更新農場", entity.name
    assert_equal 36.6895, entity.latitude
    assert_equal farm.longitude, entity.longitude  # unchanged
  end

  test "should destroy farm" do
    farm = create(:farm, name: "削除農場", user: @user)

    assert_difference("::Farm.count", -1) do
      @gateway.destroy(farm.id)
    end
  end
end