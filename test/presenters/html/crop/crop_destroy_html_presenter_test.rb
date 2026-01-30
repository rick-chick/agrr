# frozen_string_literal: true

require 'test_helper'

class CropDestroyHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test 'on_success with undo event redirects with notice' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropDestroyHtmlPresenter.new(view: view_mock)

    event = mock
    event.expects(:undo_token).returns('test_token')
    event.expects(:metadata).returns({ 'resource_label' => 'Test Crop' })

    destroy_output_dto = mock
    destroy_output_dto.expects(:undo).returns(event)

    view_mock.expects(:crops_path).returns('/crops')
    view_mock.expects(:redirect_back).with(fallback_location: '/crops', notice: I18n.t('deletion_undo.redirect_notice', resource: 'Test Crop'))

    presenter.on_success(destroy_output_dto)
  end

  test 'on_success without undo token redirects with default notice' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropDestroyHtmlPresenter.new(view: view_mock)

    event = mock
    event.expects(:undo_token).returns(nil)

    destroy_output_dto = mock
    destroy_output_dto.expects(:undo).returns(event)

    view_mock.expects(:crops_path).returns('/crops')
    view_mock.expects(:redirect_to).with('/crops', notice: I18n.t('crops.flash.destroyed'))

    presenter.on_success(destroy_output_dto)
  end

  test 'on_failure redirects with alert' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropDestroyHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    view_mock.expects(:crops_path).returns('/crops')
    view_mock.expects(:redirect_back).with(fallback_location: '/crops', alert: 'Test error')

    presenter.on_failure(error_dto)
  end
end