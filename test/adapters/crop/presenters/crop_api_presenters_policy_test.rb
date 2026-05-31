# frozen_string_literal: true

require "test_helper"

class CropApiPresentersPolicyTest < ActiveSupport::TestCase
  CROP_API_PRESENTERS_POLICY_BRANCH = [
    Adapters::Crop::Presenters::CropDetailApiPresenter,
    Adapters::Crop::Presenters::CropDeleteApiPresenter,
    Adapters::Crop::Presenters::CropUpdateApiPresenter
  ].freeze

  test "crop API presenters render forbidden with no_permission for policy denial" do
    expected = { error: I18n.t("crops.flash.no_permission") }
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    CROP_API_PRESENTERS_POLICY_BRANCH.each do |klass|
      view = Minitest::Mock.new
      presenter = klass.new(view: view)

      view.expect(:render_response, nil) do |json:, status:|
        assert_equal :forbidden, status
        assert_equal(expected, json)
      end

      presenter.on_failure(error_dto)
      view.verify
    end
  end

  test "update presenter on_failure renders forbidden for reference_flag_admin_only" do
    view = Minitest::Mock.new
    msg = I18n.t("crops.flash.reference_flag_admin_only")
    error_dto = Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure.new(message: msg, resource_id: 1)

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: msg }, json)
    end

    presenter = Adapters::Crop::Presenters::CropUpdateApiPresenter.new(view: view)
    presenter.on_failure(error_dto)
    view.verify
  end
end
