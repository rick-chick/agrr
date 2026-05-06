# frozen_string_literal: true

require "test_helper"

class CropMastersTaskTemplateDestroyPresenterTest < ActiveSupport::TestCase
  test "on_success returns no content" do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropMastersTaskTemplateDestroyPresenter.new(
      view: view_mock,
      translator: translator_stub
    )

    view_mock.expects(:head).with(:no_content)

    presenter.on_success
  end

  test "on_failure renders association not found" do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropMastersTaskTemplateDestroyPresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    failure_dto = Domain::Crop::Dtos::MastersCropTaskTemplateMastersApiFailureDto.new(
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
