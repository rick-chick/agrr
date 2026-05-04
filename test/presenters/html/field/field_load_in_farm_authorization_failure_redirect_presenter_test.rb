# frozen_string_literal: true

require "test_helper"

class FieldLoadInFarmAuthorizationFailureRedirectPresenterTest < ActiveSupport::TestCase
  test "on_permission_denied redirects to farm fields index with alert" do
    view_mock = mock
    farm = mock
    farm.expects(:id).returns(33)

    view_mock.expects(:instance_variable_get).with(:@farm).returns(farm)
    view_mock.expects(:farm_fields_path).with(33).returns("/farms/33/fields")
    view_mock.expects(:redirect_to).with("/farms/33/fields", alert: I18n.t("fields.flash.no_permission"))

    presenter = Presenters::Html::Field::FieldLoadInFarmAuthorizationFailureRedirectPresenter.new(view: view_mock)
    presenter.on_permission_denied
  end

  test "on_not_found redirects with url_for and not_found alert" do
    view_mock = mock
    farm = mock
    farm.expects(:id).returns(44)

    view_mock.expects(:instance_variable_get).with(:@farm).returns(farm)
    view_mock.expects(:url_for).with(controller: "fields", action: "index", farm_id: 44).returns("/fallback")
    view_mock.expects(:redirect_to).with("/fallback", alert: I18n.t("fields.flash.not_found"))

    presenter = Presenters::Html::Field::FieldLoadInFarmAuthorizationFailureRedirectPresenter.new(view: view_mock)
    presenter.on_not_found
  end
end
