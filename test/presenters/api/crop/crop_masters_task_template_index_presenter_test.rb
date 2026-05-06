# frozen_string_literal: true

require "test_helper"

class CropMastersTaskTemplateIndexPresenterTest < ActiveSupport::TestCase
  test "on_success renders rows" do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropMastersTaskTemplateIndexPresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    rows = [ { "id" => 1 } ]

    view_mock.expects(:render_response).with(json: rows, status: :ok)

    presenter.on_success(rows)
  end

  test "on_failure renders crop not found via api.errors key" do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropMastersTaskTemplateIndexPresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    failure_dto = Domain::Crop::Dtos::MastersCropTaskTemplateMastersApiFailureDto.new(reason: :crop_not_found)

    view_mock.expects(:render_response).with(
      json: { error: I18n.t("api.errors.crop_not_found") },
      status: :not_found
    )

    presenter.on_failure(failure_dto)
  end

  private

  def translator_stub
    @translator_stub ||= Adapters::Translators::RailsTranslator.new
  end
end
