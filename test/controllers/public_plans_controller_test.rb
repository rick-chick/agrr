# frozen_string_literal: true

require "test_helper"

# レガシー HTML PublicPlansController（new / create のみ残置）。SPA 正経路は wizard API テストを参照。
class PublicPlansControllerSessionTest < ActionController::TestCase
  tests PublicPlansController

  test "create does not store crop_ids in session" do
    farm = Farm.reference.first || Farm.create!(user: User.anonymous_user, name: "Ref Farm", is_reference: true, region: "jp", latitude: 35.0, longitude: 139.0)

    @request.session[:public_plan] = {
      farm_id: farm.id,
      farm_size_id: "home_garden",
      total_area: 30
    }

    crop = Crop.reference.first || Crop.create!(name: "Ref Crop", is_reference: true, region: "jp")
    post :create, params: { crop_ids: [ crop.id ] }

    public_plan = @request.session[:public_plan]
    assert public_plan.is_a?(Hash)
    assert_nil public_plan[:crop_ids]
  end

  test "create with no crops redirects to public_plans with alert" do
    farm = Farm.reference.where(region: "jp").first ||
           Farm.create!(user: User.anonymous_user, name: "最適化テスト農場", is_reference: true, region: "jp", latitude: 35.6762, longitude: 139.6503)

    @request.session[:public_plan] = { farm_id: farm.id, farm_size_id: "home_garden", total_area: 30 }

    Domain::PublicPlan::Interactors::PublicPlanCreateInteractor.stub(:new, ->(**kw) {
      output_port = kw[:output_port]
      Object.new.tap do |obj|
        obj.define_singleton_method(:call) { |_input|
          output_port.on_no_crops_failure(
            Domain::PublicPlan::Dtos::PublicPlanCreateNoCropsViewContext.new(
              farm: farm,
              farm_size: { id: "home_garden", area_sqm: 30 },
              crops: []
            )
          )
        }
      end
    }) do
      post :create, params: { crop_ids: [] }
      assert_redirected_to public_plans_path
      assert_equal I18n.t("public_plans.errors.select_crop"), flash[:alert]
    end
  end
end
