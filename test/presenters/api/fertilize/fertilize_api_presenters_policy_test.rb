# frozen_string_literal: true

require "test_helper"

class FertilizeApiPresentersPolicyTest < ActiveSupport::TestCase
  test "detail presenter on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Presenters::Api::Fertilize::FertilizeDetailPresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fertilizes.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end

  test "delete presenter on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Presenters::Api::Fertilize::FertilizeDeletePresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fertilizes.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end
end
