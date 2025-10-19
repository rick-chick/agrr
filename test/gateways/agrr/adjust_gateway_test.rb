# frozen_string_literal: true

require 'test_helper'

module Agrr
  class AdjustGatewayTest < ActiveSupport::TestCase
    setup do
      @gateway = Agrr::AdjustGateway.new
    end
    
    test 'adjust gateway is initialized' do
      assert_not_nil @gateway
    end
    
    # Note: 実際のagrr optimize adjustコマンドのテストは統合テストで実施
    # このテストではGatewayクラスのインターフェースのみを確認
  end
end

