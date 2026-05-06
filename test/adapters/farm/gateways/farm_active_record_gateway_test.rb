# frozen_string_literal: true

require "test_helper"

class Adapters::Farm::Gateways::FarmActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    deletion_undo_gateway = mock("deletion_undo_gateway")
    @gateway = Adapters::Farm::Gateways::FarmActiveRecordGateway.new(
      deletion_undo_gateway: deletion_undo_gateway,
      translator: CompositionRoot.translator
    )
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

  test "should raise domain RecordNotFound when farm not found" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
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
      @gateway.destroy(farm.id, toast_message: "test undo toast")
    end
  end

  test "reference_farms_for_admin_list returns entities for admin only" do
    create(:farm, user: User.anonymous_user, is_reference: true)
    assert_empty @gateway.reference_farms_for_admin_list(is_admin: false)
    ref_entities = @gateway.reference_farms_for_admin_list(is_admin: true)
    assert ref_entities.all? { |e| e.is_reference }
    assert_operator ref_entities.size, :>=, 1
  end

  test "farm_list_rows_bundle returns dto with main and reference rows for admin" do
    user_farm = create(:farm, user: @user, is_reference: false, name: "Mine")
    create(:field, farm: user_farm)
    user_input = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
    dto_user = @gateway.farm_list_rows_bundle(user_input)
    assert_equal 1, dto_user.farm_rows.size
    assert_equal user_farm.id, dto_user.farm_rows.first.id
    assert_equal 1, dto_user.farm_rows.first.field_count
    assert_empty dto_user.reference_farm_rows

    admin_input = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: true)
    ref = create(:farm, user: User.anonymous_user, is_reference: true, name: "Ref")
    dto_admin = @gateway.farm_list_rows_bundle(admin_input)
    ref_ids = dto_admin.reference_farm_rows.map(&:id)
    assert_includes ref_ids, ref.id
    main_ids = dto_admin.farm_rows.map(&:id)
    assert_includes main_ids, user_farm.id
    assert_includes main_ids, ref.id
  end

  test "farm_list_rows_from_entities maps field count and presentation fields" do
    farm = create(:farm, user: @user, is_reference: false, name: "RowTest")
    create(:field, farm: farm)
    entity = Domain::Farm::Entities::FarmEntity.from_hash(
      id: farm.id,
      name: farm.name,
      latitude: farm.latitude,
      longitude: farm.longitude,
      region: farm.region,
      user_id: farm.user_id,
      created_at: farm.created_at,
      updated_at: farm.updated_at,
      is_reference: farm.is_reference
    )

    rows = @gateway.farm_list_rows_from_entities([ entity ])
    assert_equal 1, rows.size
    assert_equal farm.id, rows.first.id
    assert_equal 1, rows.first.field_count
    assert_equal "RowTest", rows.first.display_name
    assert rows.first.weather_data_status.present?
  end

  test "private_plan_new_farm_choices returns empty array when user has no farms" do
    other = create(:user)
    create(:farm, user: other, is_reference: false)

    choices = @gateway.private_plan_new_farm_choices(user: @user)
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanNewAssembler.call(
      farm_choices: choices,
      default_plan_name: I18n.t("plans.default_plan_name")
    )
    assert_empty choices
    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanNewDto, dto
    assert dto.empty?
    assert_equal I18n.t("plans.default_plan_name"), dto.default_plan_name
  end

  test "private_plan_new_farm_choices returns choices ordered by farm id with field aggregates" do
    a = create(:farm, user: @user, is_reference: false, name: "A", latitude: 35.0, longitude: 138.0)
    b = create(:farm, user: @user, is_reference: false, name: "B", latitude: 36.0, longitude: 139.0)
    low, high = [ a, b ].minmax_by(&:id)
    create(:field, farm: low, area: 10.0)
    create(:field, farm: low, area: 5.0)

    choices = @gateway.private_plan_new_farm_choices(user: @user)
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanNewAssembler.call(
      farm_choices: choices,
      default_plan_name: I18n.t("plans.default_plan_name")
    )
    refute dto.empty?
    assert_equal I18n.t("plans.default_plan_name"), dto.default_plan_name
    assert_equal [ low.id, high.id ], dto.farm_choices.map(&:id)

    first = dto.farm_choices.first
    assert_equal low.id, first.id
    assert_equal 2, first.fields_count
    assert_in_delta 15.0, first.fields_total_area, 0.001
    assert first.fields_present?

    second = dto.farm_choices.last
    assert_equal high.id, second.id
    assert_not second.fields_present?
    assert_equal 0, second.fields_count
  end

  test "soft_destroy_with_undo returns failure without scheduling when free_crop_plans exist" do
    farm = create(:farm, user: @user, is_reference: false)
    crop = create(:crop, user: @user)
    FreeCropPlan.create!(farm: farm, crop: crop, area_sqm: 100, session_id: "sess_gateway_block")

    deletion_undo_gateway = mock("deletion_undo_gateway")
    deletion_undo_gateway.expects(:schedule).never

    gateway = Adapters::Farm::Gateways::FarmActiveRecordGateway.new(
      deletion_undo_gateway: deletion_undo_gateway,
      translator: CompositionRoot.translator
    )

    result = gateway.soft_destroy_with_undo(user: @user, farm_id: farm.id, toast_message: "toast")
    assert_equal false, result[:success]
    assert result[:error_dto].message.present?
  end
end
