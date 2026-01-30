# frozen_string_literal: true

require 'test_helper'

class PesticideDestroyHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success with undo event redirects with notice' do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideDestroyHtmlPresenter.new(view: view_mock)

    event = mock
    event.expects(:undo_token).returns('test_token')
    event.expects(:metadata).returns({ 'resource_label' => 'Test Pesticide' })

    destroy_output_dto = mock
    destroy_output_dto.expects(:undo).returns(event)

    view_mock.expects(:pesticides_path).returns('/pesticides')
    view_mock.expects(:redirect_back).with(fallback_location: '/pesticides', notice: I18n.t('deletion_undo.redirect_notice', resource: 'Test Pesticide'))

    presenter.on_success(destroy_output_dto)
  end

  test 'on_success without undo token redirects with default notice' do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideDestroyHtmlPresenter.new(view: view_mock)

    event = mock
    event.expects(:undo_token).returns(nil)

    destroy_output_dto = mock
    destroy_output_dto.expects(:undo).returns(event)

    view_mock.expects(:pesticides_path).returns('/pesticides')
    view_mock.expects(:redirect_to).with('/pesticides', notice: I18n.t('pesticides.flash.destroyed'))

    presenter.on_success(destroy_output_dto)
  end

  test 'on_failure redirects with alert' do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideDestroyHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    view_mock.expects(:pesticides_path).returns('/pesticides')
    view_mock.expects(:redirect_back).with(fallback_location: '/pesticides', alert: 'Test error')

    presenter.on_failure(error_dto)
  end
end