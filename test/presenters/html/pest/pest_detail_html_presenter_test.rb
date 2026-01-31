# frozen_string_literal: true

require 'test_helper'

class PestDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @pest and @crops' do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: view_mock)

    pest_entity = mock
    pest_entity.expects(:id).returns(1)
    pest_model = mock
    crops = mock
    crop1 = mock
    crop2 = mock
    pest_model.expects(:crops).returns(crops)
    crops.expects(:recent).returns([crop1, crop2])

    pest_detail_dto = mock
    pest_detail_dto.stubs(:pest_model).returns(nil)
    pest_detail_dto.stubs(:pest).returns(pest_entity)

    ::Pest.stubs(:find).with(1).returns(pest_model)

    view_mock.expects(:instance_variable_set).with(:@pest, pest_model)
    view_mock.expects(:instance_variable_set).with(:@crops, [crop1, crop2])

    presenter.on_success(pest_detail_dto)
  end

  test 'on_failure redirects with alert' do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    view_mock.expects(:pests_path).returns('/pests')
    view_mock.expects(:redirect_to).with('/pests', alert: 'Test error')

    presenter.on_failure(error_dto)
  end
end