# frozen_string_literal: true

require 'test_helper'

class InteractionRuleCreateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleCreateHtmlPresenter.new(view: view_mock)

    rule = mock('rule')

    view_mock.expects(:interaction_rules_path).returns('/interaction_rules')
    view_mock.expects(:redirect_to).with('/interaction_rules', notice: I18n.t('interaction_rules.flash.created'))

    presenter.on_success(rule)
    assert true
  end

  test 'on_failure renders new template' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleCreateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    view_mock.expects(:render).with(:new, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end