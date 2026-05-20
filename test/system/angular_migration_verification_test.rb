require "application_system_test_case"

class AngularMigrationVerificationTest < ApplicationSystemTestCase
  # TODO: Angular アプリが Rails に統合されたら skip を解除する
  # 現在、/farms や /public-plans/new は Rails ビューをレンダリングしており、
  # Angular コンポーネント (app-navbar, .enhanced-selection-card) は存在しない。

  setup do
    @user = create(:user)
    @user.generate_api_key!
    @farm = create(:farm, :user_owned, user: @user, name: "E2E Test Farm")
    @fertilize = create(:fertilize, :user_owned, user: @user, name: "E2E Test Fertilize")

    # 無料作付フロー用: 参照農場・作物（weather_location はジョブ用に必須）
    @weather_location = create(:weather_location)
    @ref_farm = create(:farm, :reference, region: "jp", name: "Ref Farm JP", weather_location: @weather_location)
    @ref_crop = create(:crop, :reference, region: "jp", name: "Ref Crop JP")
    create(:crop_stage, :germination, crop: @ref_crop, order: 1)
  end

  test "can visit farms list and detail in Angular" do
    skip "Angular migration not yet integrated"
  end

  test "can visit public plan wizard in Angular" do
    skip "Angular migration not yet integrated"
  end

  test "public plan create succeeds and navigates to optimizing" do
    skip "Angular migration not yet integrated"
  end
end
