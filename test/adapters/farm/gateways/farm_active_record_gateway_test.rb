# frozen_string_literal: true

require "test_helper"

class Adapters::Farm::Gateways::FarmActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    deletion_undo_gateway = mock("deletion_undo_gateway")
    @gateway = Adapters::Farm::Gateways::FarmActiveRecordGateway.new(
      deletion_undo_gateway: deletion_undo_gateway
    )
    @user = create(:user)
  end

  test "list_user_and_reference_farms includes user farm and reference farm" do
    user_farm = create(:farm, user: @user, is_reference: false)
    reference_farm = create(:farm, user: User.anonymous_user, is_reference: true)

    entities = @gateway.list_user_and_reference_farms(user_id: @user.id)

    farm_ids = entities.map(&:id)
    assert_includes farm_ids, user_farm.id
    assert_includes farm_ids, reference_farm.id
  end

  test "list_user_owned_farms excludes reference farms" do
    user_farm = create(:farm, user: @user, is_reference: false)
    reference_farm = create(:farm, user: User.anonymous_user, is_reference: true)

    entities = @gateway.list_user_owned_farms(user_id: @user.id)

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

  test "should raise domain RecordNotFound when farm not found" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.find_by_id(9999)
    end
  end

  test "should create farm" do
    user = create(:user)
    create_input_dto = Domain::Farm::Dtos::FarmCreateInput.new(
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

    update_input_dto = Domain::Farm::Dtos::FarmUpdateInput.new(
      farm_id: farm.id,
      name: "更新農場",
      latitude: 36.6895
    )

    entity = @gateway.update(farm.id, update_input_dto)

    assert_equal "更新農場", entity.name
    assert_equal 36.6895, entity.latitude
    assert_equal farm.longitude, entity.longitude  # unchanged
  end

  test "list_reference_farms returns all reference farm entities" do
    create(:farm, user: User.anonymous_user, is_reference: true)
    ref_entities = @gateway.list_reference_farms
    assert ref_entities.all? { |e| e.is_reference }
    assert_operator ref_entities.size, :>=, 1
  end

  test "list_user_owned_farms returns only user non-reference farms" do
    user_farm = create(:farm, user: @user, is_reference: false)
    create(:farm, user: User.anonymous_user, is_reference: true)
    farms = @gateway.list_user_owned_farms(user_id: @user.id)
    assert farms.all? { |e| !e.is_reference && e.user_id == @user.id }
    assert_includes farms.map(&:id), user_farm.id
  end

  test "list_user_owned_farm_rows returns rows without reference farms" do
    user_farm = create(:farm, user: @user, is_reference: false, name: "Mine")
    create(:field, farm: user_farm)
    rows = @gateway.list_user_owned_farm_rows(user_id: @user.id)
    assert_equal 1, rows.size
    assert_equal user_farm.id, rows.first.id
    assert_equal 1, rows.first.field_count
  end

  test "list_user_and_reference_farm_rows includes user farms and reference farms" do
    user_farm = create(:farm, user: @user, is_reference: false, name: "Mine")
    ref = create(:farm, user: User.anonymous_user, is_reference: true, name: "Ref")
    rows = @gateway.list_user_and_reference_farm_rows(user_id: @user.id)
    ids = rows.map(&:id)
    assert_includes ids, user_farm.id
    assert_includes ids, ref.id
  end

  test "list_reference_farm_rows returns only reference farm rows" do
    create(:farm, user: @user, is_reference: false)
    ref = create(:farm, user: User.anonymous_user, is_reference: true, name: "Ref")
    rows = @gateway.list_reference_farm_rows
    assert rows.all? { |r| r.is_reference }
    assert_includes rows.map(&:id), ref.id
  end

  test "farm_weather_data_access_context_for_owned_farm returns dto for owner" do
    farm = create(:farm, user: @user)
    wl = create(:weather_location)
    farm.update!(weather_location: wl)

    ctx = @gateway.farm_weather_data_access_context_for_owned_farm(
      user_id: @user.id,
      farm_id: farm.id
    )

    assert_equal farm.id, ctx.farm_id
    assert_equal wl.id, ctx.weather_location_id
  end

  test "farm_weather_data_access_context_for_owned_farm returns nil for other users farm" do
    other = create(:user)
    farm = create(:farm, user: other)

    ctx = @gateway.farm_weather_data_access_context_for_owned_farm(
      user_id: @user.id,
      farm_id: farm.id
    )

    assert_nil ctx
  end

  test "farm_weather_data_access_context_for_admin_lookup returns any farm by id" do
    other = create(:user)
    farm = create(:farm, user: other)

    ctx = @gateway.farm_weather_data_access_context_for_admin_lookup(
      farm_id: farm.id
    )

    assert_equal farm.id, ctx.farm_id
  end

  test "build_blank_farm_for_master_form! returns new unsaved farm for user" do
    farm = @gateway.build_blank_farm_for_master_form!(user_id: @user.id)

    assert_instance_of ::Farm, farm
    assert farm.new_record?
    assert_equal @user.id, farm.user_id
  end

  test "build_blank_farm_for_master_form! raises domain RecordNotFound when user missing" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.build_blank_farm_for_master_form!(user_id: 999_999_999)
    end
  end
end
