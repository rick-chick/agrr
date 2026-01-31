# frozen_string_literal: true

require 'test_helper'

class InteractionRuleCreateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleCreateHtmlPresenter.new(view: view_mock)

    rule = mock('rule')
    rule.expects(:id).returns(1)

    view_mock.expects(:interaction_rule_path).with(1).returns('/interaction_rules/1')
    view_mock.expects(:redirect_to).with('/interaction_rules/1', notice: I18n.t('interaction_rules.flash.created'))

    presenter.on_success(rule)
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