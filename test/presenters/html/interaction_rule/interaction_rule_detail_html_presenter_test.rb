# frozen_string_literal: true

require 'test_helper'

class InteractionRuleDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success does nothing' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDetailHtmlPresenter.new(view: view_mock)

    rule = mock('rule')
    presenter.on_success(rule)
    assert true
  end

  test 'on_failure renders error template' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    view_mock.expects(:render).with(:error, status: :internal_server_error, locals: { error: 'Test error' })

    presenter.on_failure(error_dto)
    assert true
  end
end