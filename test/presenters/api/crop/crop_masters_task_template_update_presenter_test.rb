# frozen_string_literal: true

require "test_helper"

class CropMastersTaskTemplateUpdatePresenterTest < ActiveSupport::TestCase
  test "on_success renders row" do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropMastersTaskTemplateUpdatePresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    row = { "id" => 1, "name" => "a" }

    view_mock.expects(:render_response).with(json: row, status: :ok)

    presenter.on_success(row)
  end

  test "on_failure renders validation errors" do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropMastersTaskTemplateUpdatePresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    failure_dto = Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailureDto.new(
      reason: :validation_failed,
      errors: [ "Name can't be blank" ]
    )

    view_mock.expects(:render_response).with(
      json: { errors: [ "Name can't be blank" ] },
      status: :unprocessable_entity
    )

    presenter.on_failure(failure_dto)
  end

  test "on_failure renders association not found" do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropMastersTaskTemplateUpdatePresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    failure_dto = Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailureDto.new(
      reason: :association_not_found
    )

    view_mock.expects(:render_response).with(
      json: { error: "AgriculturalTask association not found" },
      status: :not_found
    )

    presenter.on_failure(failure_dto)
  end

  private

  def translator_stub
    @translator_stub ||= Object.new.tap do |o|
      o.define_singleton_method(:t) { |_key, **kwargs| kwargs.fetch(:default) }
    end
  end
end
