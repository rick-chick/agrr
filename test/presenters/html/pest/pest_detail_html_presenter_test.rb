# frozen_string_literal: true

require 'test_helper'

class PestDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @pest and @crops' do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: view_mock)

    pest_entity = mock
    pest_model = mock
    crops = mock('crops')
    crop1 = mock('crop1')
    crop2 = mock('crop2')
    pest_entity.expects(:to_model).returns(pest_model).twice
    pest_model.expects(:crops).returns(crops)
    crops.expects(:recent).returns([crop1, crop2])

    pest_detail_dto = mock
    pest_detail_dto.expects(:pest).returns(pest_entity).twice

    view_mock.expects(:instance_variable_set).with(:@pest, pest_model)
    view_mock.expects(:instance_variable_set).with(:@crops, [crop1, crop2])

    presenter.on_success(pest_detail_dto)
  end

  test 'on_failure sets flash alert and redirects' do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:pests_path).returns('/pests')
    view_mock.expects(:redirect_to).with('/pests')

    presenter.on_failure(error_dto)
  end
end