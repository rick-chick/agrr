# frozen_string_literal: true

require 'test_helper'

class InteractionRuleListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @interaction_rules and @reference_rules' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: view_mock)

    rule = mock
    rule.expects(:id).returns(1)
    rule_model = mock
    ::InteractionRule.expects(:find).with(1).returns(rule_model)

    view_mock.expects(:instance_variable_set).with(:@interaction_rules, [rule_model])
    view_mock.expects(:instance_variable_set).with(:@reference_rules, [])

    presenter.on_success({ interaction_rules: [rule], reference_rules: [] })
  end

  test 'on_failure sets flash and empty arrays' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:respond_to?).with(:message).returns(true)
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@interaction_rules, [])
    view_mock.expects(:instance_variable_set).with(:@reference_rules, [])

    presenter.on_failure(error_dto)
  end
end