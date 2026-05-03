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
end
