# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should generate api key" do
    user = create(:user)
    assert_nil user.api_key
    
    api_key = user.generate_api_key!
    
    assert_not_nil api_key
    assert_equal 64, api_key.length # SecureRandom.hex(32) produces 64 character hex string
    assert_equal api_key, user.reload.api_key
  end

  test "should regenerate api key" do
    user = create(:user)
    old_key = user.generate_api_key!
    
    new_key = user.regenerate_api_key!
    
    assert_not_equal old_key, new_key
    assert_equal new_key, user.reload.api_key
  end

  test "should check if user has api key" do
    user = create(:user)
    assert_not user.has_api_key?
    
    user.generate_api_key!
    assert user.has_api_key?
  end

  test "should find user by api key" do
    user = create(:user)
    api_key = user.generate_api_key!
    
    found_user = User.find_by_api_key(api_key)
    assert_equal user.id, found_user.id
  end

  test "should return nil when api key is blank" do
    assert_nil User.find_by_api_key(nil)
    assert_nil User.find_by_api_key("")
  end

  test "should return nil when api key does not exist" do
    assert_nil User.find_by_api_key("nonexistent_key")
  end

  test "should generate unique api keys" do
    user1 = create(:user)
    user2 = create(:user)
    
    key1 = user1.generate_api_key!
    key2 = user2.generate_api_key!
    
    assert_not_equal key1, key2
  end
end
