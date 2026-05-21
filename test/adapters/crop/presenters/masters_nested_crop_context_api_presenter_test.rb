# frozen_string_literal: true

require "test_helper"

class MastersNestedCropContextApiPresenterTest < ActiveSupport::TestCase
  test "on_not_found renders default api.errors.crop_not_found" do
    view = mock
    presenter = Adapters::Crop::Presenters::MastersNestedCropContextApiPresenter.new(view: view)

    view.expects(:render).with(json: { error: I18n.t("api.errors.crop_not_found") }, status: :not_found)

    presenter.on_not_found
  end

  test "on_not_found renders explicit message when configured" do
    view = mock
    presenter = Adapters::Crop::Presenters::MastersNestedCropContextApiPresenter.new(
      view: view,
      not_found_message: "Crop not found"
    )

    view.expects(:render).with(json: { error: "Crop not found" }, status: :not_found)

    presenter.on_not_found
  end

  test "on_success assigns crop to view" do
    view = Object.new
    crop = Object.new
    presenter = Adapters::Crop::Presenters::MastersNestedCropContextApiPresenter.new(view: view)

    presenter.on_success(crop)

    assert_same crop, view.instance_variable_get(:@crop)
  end
end
