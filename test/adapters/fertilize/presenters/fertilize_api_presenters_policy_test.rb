# frozen_string_literal: true

require "test_helper"

class FertilizeApiPresentersPolicyTest < ActiveSupport::TestCase
  FERTILIZE_API_PRESENTERS_POLICY_BRANCH = [
    Adapters::Fertilize::Presenters::FertilizeDetailApiPresenter,
    Adapters::Fertilize::Presenters::FertilizeDeleteApiPresenter,
    Adapters::Fertilize::Presenters::FertilizeListApiPresenter,
    Adapters::Fertilize::Presenters::FertilizeCreateApiPresenter,
    Adapters::Fertilize::Presenters::FertilizeUpdateApiPresenter
  ].freeze

  test "fertilize API presenters render forbidden with no_permission for policy denial" do
    expected = { error: I18n.t("fertilizes.flash.no_permission") }
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    FERTILIZE_API_PRESENTERS_POLICY_BRANCH.each do |klass|
      view = Minitest::Mock.new
      presenter = klass.new(view: view)

      view.expect(:render_response, nil) do |json:, status:|
        assert_equal :forbidden, status
        assert_equal(expected, json)
      end

      presenter.on_failure(error_dto)
      view.verify
    end
  end
end
