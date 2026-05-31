# frozen_string_literal: true

require "test_helper"

class FarmApiPresentersPolicyTest < ActiveSupport::TestCase
  FARM_API_PRESENTERS_POLICY_BRANCH = [
    Adapters::Farm::Presenters::FarmListApiPresenter,
    Adapters::Farm::Presenters::FarmUpdateApiPresenter
  ].freeze

  test "farm API presenters render forbidden with no_permission for policy denial" do
    expected = { error: I18n.t("farms.flash.no_permission") }
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    FARM_API_PRESENTERS_POLICY_BRANCH.each do |klass|
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
