# frozen_string_literal: true

require 'test_helper'

class Domain::Farm::Interactors::FarmFindAllInteractorTest < ActiveSupport::TestCase
  def setup
    @gateway = Minitest::Mock.new
    @interactor = Domain::Farm::Interactors::FarmFindAllInteractor.new(@gateway)
    @user_id = 1
    @farms = [
      Domain::Farm::Entities::FarmEntity.new({
        id: 1,
        user_id: @user_id,
        name: "農場1",
        latitude: 35.6762,
        longitude: 139.6503,
        created_at: Time.current,
        updated_at: Time.current
      }),
      Domain::Farm::Entities::FarmEntity.new({
        id: 2,
        user_id: @user_id,
        name: "農場2",
        latitude: 36.6762,
        longitude: 140.6503,
        created_at: Time.current,
        updated_at: Time.current
      })
    ]
  end

  test "should find all farms for user successfully" do
    @gateway.expect :find_by_user_id, @farms, [@user_id]
    
    result = @interactor.call(@user_id)
    
    assert result.success?
    assert_equal @farms, result.data
    @gateway.verify
  end

  test "should return empty array when no farms found" do
    @gateway.expect :find_by_user_id, [], [@user_id]
    
    result = @interactor.call(@user_id)
    
    assert result.success?
    assert_equal [], result.data
    @gateway.verify
  end

  test "should return error when gateway raises exception" do
    @gateway.expect :find_by_user_id, nil do |user_id|
      raise StandardError, "Database error"
    end
    
    result = @interactor.call(@user_id)
    
    assert_not result.success?
    assert_equal "Database error", result.error
    @gateway.verify
  end
end
