# frozen_string_literal: true

require "test_helper"

class PredictionDaemonGatewayTest < ActiveSupport::TestCase
  setup do
    @gateway = Adapters::Agrr::Gateways::PredictionDaemonGateway.new
  end

  test "development uses requested model when AGRR_USE_MOCK is unset" do
    with_development_env do
      with_env("AGRR_USE_MOCK" => nil, "AGRR_PREDICT_MODEL" => nil) do
        assert_equal "lightgbm", @gateway.send(:resolve_effective_model, "lightgbm")
      end
    end
  end

  test "development uses mock only when AGRR_USE_MOCK is true" do
    with_development_env do
      with_env("AGRR_USE_MOCK" => "true", "AGRR_PREDICT_MODEL" => nil) do
        assert_equal "mock", @gateway.send(:resolve_effective_model, "lightgbm")
      end
    end
  end

  test "AGRR_PREDICT_MODEL overrides development default" do
    with_development_env do
      with_env("AGRR_USE_MOCK" => nil, "AGRR_PREDICT_MODEL" => "mock") do
        assert_equal "mock", @gateway.send(:resolve_effective_model, "lightgbm")
      end
    end
  end

  private

  def with_development_env
    env = ActiveSupport::StringInquirer.new("development")
    Rails.stub(:env, env) { yield }
  end

  def with_env(env_vars)
    previous = {}
    env_vars.each do |key, value|
      previous[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
