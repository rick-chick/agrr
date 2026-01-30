# frozen_string_literal: true

require 'test_helper'

class FieldDestroyHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success with undo event redirects with notice' do
    view_mock = mock
    presenter = Presenters::Html::Field::FieldDestroyHtmlPresenter.new(view: view_mock)

    event = mock
    event.expects(:undo_token).returns('test_token')
    event.expects(:metadata).returns({ 'resource_label' => 'Test Field' })

    destroy_output_dto = mock
    destroy_output_dto.expects(:undo).returns(event)

    farm = mock
    view_mock.expects(:instance_variable_get).with(:@farm).returns(farm)

    view_mock.expects(:farm_fields_path).with(farm).returns('/farms/1/fields')
    view_mock.expects(:redirect_back).with(fallback_location: '/farms/1/fields', notice: I18n.t('deletion_undo.redirect_notice', resource: 'Test Field'))

    presenter.on_success(destroy_output_dto)
  end

  test 'on_success without undo token redirects with default notice' do
    view_mock = mock
    presenter = Presenters::Html::Field::FieldDestroyHtmlPresenter.new(view: view_mock)

    event = mock
    event.expects(:undo_token).returns(nil)

    destroy_output_dto = mock
    destroy_output_dto.expects(:undo).returns(event)

    farm = mock
    view_mock.expects(:instance_variable_get).with(:@farm).returns(farm)

    view_mock.expects(:farm_fields_path).with(farm).returns('/farms/1/fields')
    view_mock.expects(:redirect_to).with('/farms/1/fields', notice: I18n.t('fields.flash.destroyed'))

    presenter.on_success(destroy_output_dto)
  end

  test 'on_failure redirects with alert' do
    view_mock = mock
    presenter = Presenters::Html::Field::FieldDestroyHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    farm = mock
    view_mock.expects(:instance_variable_get).with(:@farm).returns(farm)

    view_mock.expects(:farm_fields_path).with(farm).returns('/farms/1/fields')
    view_mock.expects(:redirect_back).with(fallback_location: '/farms/1/fields', alert: 'Test error')

    presenter.on_failure(error_dto)
  end
end