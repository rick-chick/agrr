# frozen_string_literal: true

require "test_helper"

class PesticideApiPresentersPolicyTest < ActiveSupport::TestCase
  # List / Detail / Create / Update / Delete は on_failure の policy 分岐が同一のため、
  # 契約は 1 本で表明し、Interactor 側の policy 拒否と二重に列を増やさない。
  PESTICIDE_API_PRESENTERS_POLICY_BRANCH = [
    Presenters::Api::Pesticide::PesticideListPresenter,
    Presenters::Api::Pesticide::PesticideDetailPresenter,
    Presenters::Api::Pesticide::PesticideCreatePresenter,
    Presenters::Api::Pesticide::PesticideUpdatePresenter,
    Presenters::Api::Pesticide::PesticideDeletePresenter
  ].freeze

  test "pesticide API presenters render forbidden with no_permission for policy denial" do
    expected = { error: I18n.t("pesticides.flash.no_permission") }
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    PESTICIDE_API_PRESENTERS_POLICY_BRANCH.each do |klass|
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

  test "create presenter on_failure renders forbidden json for reference_only_admin ErrorDto" do
    view = Minitest::Mock.new
    msg = I18n.t("pesticides.flash.reference_only_admin")
    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: msg }, json)
    end

    presenter = Presenters::Api::Pesticide::PesticideCreatePresenter.new(view: view)
    presenter.on_failure(Domain::Shared::Dtos::ErrorDto.new(msg))
    view.verify
  end

  test "update presenter on_failure renders forbidden json for reference_flag_admin_only ErrorDto" do
    view = Minitest::Mock.new
    msg = I18n.t("pesticides.flash.reference_flag_admin_only")
    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: msg }, json)
    end

    presenter = Presenters::Api::Pesticide::PesticideUpdatePresenter.new(view: view)
    presenter.on_failure(Domain::Shared::Dtos::ErrorDto.new(msg))
    view.verify
  end
end
