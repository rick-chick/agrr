# frozen_string_literal: true

require 'test_helper'

class FieldCreateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::Field::FieldCreateHtmlPresenter.new(view: view_mock)

    field_entity = mock
    field_entity.expects(:id).returns(2)

    farm = mock
    farm.expects(:id).returns(1)
    view_mock.expects(:instance_variable_get).with(:@farm).returns(farm)

    view_mock.expects(:farm_field_path).with(1, 2).returns('/farms/1/fields/2')
    view_mock.expects(:redirect_to).with('/farms/1/fields/2', notice: I18n.t('fields.flash.created'))

    presenter.on_success(field_entity)
  end

  test 'on_failure sets flash alert and renders new template' do
    view_mock = mock
    presenter = Presenters::Html::Field::FieldCreateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render_form).with(:new, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end