# frozen_string_literal: true

require 'test_helper'

class FertilizeListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success does nothing' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeListHtmlPresenter.new(view: view_mock)

    fertilizes = [mock, mock]
    # HTML の場合、コントローラで @fertilizes に代入してビューを表示するだけなので、何もしない

    presenter.on_success(fertilizes)
  end

  test 'on_failure sets flash alert and renders index template' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:respond_to?).with(:message).returns(true)
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render).with(:index, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end