# frozen_string_literal: true

require "test_helper"

class CropLoadForMastersApiPresenterTest < ActiveSupport::TestCase
  test "on_not_found renders english crop not found" do
    view = mock
    presenter = Adapters::Crop::Presenters::CropLoadForMastersApiPresenter.new(view: view)

    view.expects(:render).with(json: { error: "Crop not found" }, status: :not_found)

    presenter.on_not_found
  end
end
