# frozen_string_literal: true

require "test_helper"

class FertilizeApiPresentersPolicyTest < ActiveSupport::TestCase
  test "detail presenter on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Adapters::Fertilize::Presenters::FertilizeDetailApiPresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fertilizes.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end

  test "delete presenter on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Adapters::Fertilize::Presenters::FertilizeDeleteApiPresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fertilizes.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end

  test "list presenter on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Adapters::Fertilize::Presenters::FertilizeListApiPresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fertilizes.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end

  test "create presenter on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Adapters::Fertilize::Presenters::FertilizeCreateApiPresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fertilizes.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end

  test "update presenter on_failure renders forbidden for policy" do
    view = Minitest::Mock.new
    presenter = Adapters::Fertilize::Presenters::FertilizeUpdateApiPresenter.new(view: view)
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("fertilizes.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)
    view.verify
  end
end
