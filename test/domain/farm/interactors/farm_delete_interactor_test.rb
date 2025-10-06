# frozen_string_literal: true

require 'test_helper'

class Domain::Farm::Interactors::FarmDeleteInteractorTest < ActiveSupport::TestCase
  def setup
    @gateway = Minitest::Mock.new
    @interactor = Domain::Farm::Interactors::FarmDeleteInteractor.new(@gateway)
    @farm_id = 1
  end

  test "should delete farm successfully" do
    @gateway.expect :exists?, true, [@farm_id]
    @gateway.expect :delete, true, [@farm_id]
    
    result = @interactor.call(@farm_id)
    
    assert result.success?
    assert result.data
    @gateway.verify
  end

  test "should return error when farm does not exist" do
    @gateway.expect :exists?, false, [@farm_id]
    
    result = @interactor.call(@farm_id)
    
    assert_not result.success?
    assert_equal "Farm not found", result.error
    @gateway.verify
  end

  test "should return error when gateway raises exception" do
    @gateway.expect :exists?, true, [@farm_id]
    @gateway.expect :delete, false do |id|
      raise StandardError, "Database error"
    end
    
    result = @interactor.call(@farm_id)
    
    assert_not result.success?
    assert_equal "Database error", result.error
    @gateway.verify
  end
end
