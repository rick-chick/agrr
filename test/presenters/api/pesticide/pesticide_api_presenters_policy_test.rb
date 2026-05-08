# frozen_string_literal: true

require "test_helper"

class PesticideApiPresentersPolicyTest < ActiveSupport::TestCase
  %w[List Detail Create Update Delete].each do |action|
    define_method("test_#{action.downcase}_presenter_on_failure_renders_forbidden_for_policy") do
      view = Minitest::Mock.new
      klass = case action
              when "List" then Presenters::Api::Pesticide::PesticideListPresenter
              when "Detail" then Presenters::Api::Pesticide::PesticideDetailPresenter
              when "Create" then Presenters::Api::Pesticide::PesticideCreatePresenter
              when "Update" then Presenters::Api::Pesticide::PesticideUpdatePresenter
              when "Delete" then Presenters::Api::Pesticide::PesticideDeletePresenter
              end
      presenter = klass.new(view: view)
      error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

      view.expect(:render_response, nil) do |json:, status:|
        assert_equal :forbidden, status
        assert_equal({ error: I18n.t("pesticides.flash.no_permission") }, json)
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
