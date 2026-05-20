# frozen_string_literal: true

require "test_helper"

class FieldListPresenterTest < ActiveSupport::TestCase
  test "on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Adapters::Field::Presenters::Api::FieldListPresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fields.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end

  test "on_failure uses not_found for farm not found message" do
    view = Minitest::Mock.new
    presenter = Adapters::Field::Presenters::Api::FieldListPresenter.new(view: view)

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :not_found, status
      assert_equal({ error: "Farm not found" }, json)
    end

    presenter.on_failure(Domain::Shared::Dtos::Error.new("Farm not found"))
    view.verify
  end
end
