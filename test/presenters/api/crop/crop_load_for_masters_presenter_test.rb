# frozen_string_literal: true

require "test_helper"

class CropLoadForMastersPresenterTest < ActiveSupport::TestCase
  test "on_not_found renders english crop not found" do
    view = mock
    presenter = Presenters::Api::Crop::CropLoadForMastersPresenter.new(view: view)

    view.expects(:render).with(json: { error: "Crop not found" }, status: :not_found)

    presenter.on_not_found
  end
end
