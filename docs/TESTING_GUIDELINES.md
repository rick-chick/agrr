# AGRR Testing Guidelines

## 🎯 Testing Philosophy

### Test Pyramid Structure
```
1. Unit Tests (70%)
   ├── Model validations
   ├── Business logic
   └── Edge cases

2. Integration Tests (20%)
   ├── Service objects
   ├── Cross-model interactions
   └── Workflow validation

3. System Tests (10%)
   ├── User flows
   ├── UI interactions
   └── End-to-end scenarios
```

## 🚨 Critical Testing Requirements

### Resource Limit Testing (MANDATORY)

#### Model-Level Tests (REQUIRED)
```ruby
# Test direct database operations
test "should prevent creating 5th farm via direct creation" do
  # Setup: Create 4 farms
  4.times { create(:farm, user: @user, is_reference: false) }
  
  # Test: Attempt 5th farm creation
  farm5 = Farm.new(
    user: @user,
    name: "Farm 5",
    latitude: 35.0,
    longitude: 139.0,
    is_reference: false
  )
  
  # Assert: Validation fails
  assert_not farm5.valid?, "5th farm should not be valid"
  assert_includes farm5.errors[:user], "作成できるFarmは4件までです"
end

# Test reference records are excluded
test "should allow unlimited reference farms" do
  anonymous_user = User.anonymous_user
  initial_count = anonymous_user.farms.where(is_reference: true).count
  
  # Create multiple reference farms
  5.times do |i|
    farm = Farm.create!(
      user: anonymous_user,
      name: "Reference Farm #{i + 1}",
      latitude: 36.0 + i * 0.1,
      longitude: 136.0 + i * 0.1,
      is_reference: true
    )
    assert farm.persisted?, "Reference farm #{i + 1} should be created"
  end
  
  expected_count = initial_count + 5
  assert_equal expected_count, anonymous_user.farms.where(is_reference: true).count
end

# Test update scenarios
test "should allow updating existing farms when at limit" do
  # Setup: Create 4 farms
  4.times { create(:farm, user: @user, is_reference: false) }
  
  # Test: Update existing farm
  existing_farm = @user.farms.first
  existing_farm.name = "Updated Farm Name"
  
  # Assert: Update succeeds
  assert existing_farm.valid?, "Updating existing farm should be valid"
  assert existing_farm.save, "Should be able to save updated farm"
end
```

#### Integration Tests (REQUIRED)
```ruby
# Test service object integration
test "should prevent farm creation in PlanSaveService when limit reached" do
  # Setup: User with 4 farms
  4.times do |i|
    create(:farm, user: @user, name: "Existing Farm #{i + 1}", is_reference: false)
  end
  
  # Setup: Session data for PlanSaveService
  ref_farm = Farm.reference.first
  ref_crop = Crop.reference.first
  
  session_data = {
    farm_id: ref_farm.id,
    crop_ids: [ref_crop.id],
    field_data: [{ name: 'Test Field', area: 100.0, coordinates: [35.0, 139.0] }]
  }
  
  # Create reference plan
  plan = CultivationPlan.create!(
    farm: ref_farm,
    user: nil,
    total_area: 100.0,
    status: 'completed',
    plan_type: 'public',
    planning_start_date: Date.current,
    planning_end_date: Date.current.end_of_year
  )
  session_data[:plan_id] = plan.id
  
  # Test: PlanSaveService execution
  result = PlanSaveService.new(user: @user, session_data: session_data).call
  
  # Assert: Service fails with appropriate error
  assert_not result.success, "PlanSaveService should fail when farm limit reached"
  assert_includes result.error_message, "作成できるFarmは4件までです"
end

# Test controller integration
test "should prevent farm creation via controller when limit reached" do
  # Setup: User with 4 farms
  4.times { create(:farm, user: @user, is_reference: false) }
  
  # Test: POST request to create farm
  post farms_path, params: {
    farm: {
      name: "Farm 5",
      latitude: 35.0,
      longitude: 139.0
    }
  }
  
  # Assert: Request fails with appropriate response
  assert_response :unprocessable_entity
  assert_select 'div.errors', text: /農場の数が上限/
end
```

## 📋 Test Implementation Checklist

### Before Writing Tests
- [ ] Identify the resource type and limit
- [ ] Determine reference record exclusion rules
- [ ] Plan model-level test scenarios
- [ ] Plan integration test scenarios
- [ ] Plan edge case scenarios

### Model-Level Test Scenarios
- [ ] Direct creation at limit boundary
- [ ] Direct creation exceeding limit
- [ ] Reference record exclusion
- [ ] Update scenarios (existing records)
- [ ] New record vs. update distinction
- [ ] User association validation

### Integration Test Scenarios
- [ ] Service object integration
- [ ] Controller action integration
- [ ] Cross-model validation
- [ ] Error message propagation
- [ ] User flow scenarios

### Edge Case Scenarios
- [ ] New users (no existing records)
- [ ] Users with mixed reference/user records
- [ ] Concurrent creation attempts
- [ ] Database constraint violations
- [ ] Transaction rollback scenarios

## 🧪 Test Data Management

### Factory Usage
```ruby
# Use factories for consistent test data
FactoryBot.define do
  factory :farm do
    association :user
    name { "Test Farm" }
    latitude { 35.0 }
    longitude { 139.0 }
    is_reference { false }
    
    trait :reference do
      user { User.anonymous_user }
      is_reference { true }
    end
  end
end
```

### Test Setup Patterns
```ruby
class FarmLimitTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @ref_farm = Farm.reference.first || create(:farm, :reference)
    @ref_crop = Crop.reference.first || create(:crop, :reference)
  end
  
  def teardown
    @user.destroy if @user&.persisted?
  end
end
```

## 🔍 Test Quality Standards

### Assertion Quality
```ruby
# ✅ GOOD: Specific assertions
assert_not farm.valid?, "Farm should not be valid when limit exceeded"
assert_includes farm.errors[:user], "作成できるFarmは4件までです"

# ❌ BAD: Vague assertions
assert farm.errors.any?
assert farm.errors.present?
```

### Test Naming
```ruby
# ✅ GOOD: Descriptive test names
test "should prevent creating 5th farm when user has 4 farms"
test "should allow unlimited reference farms"
test "should prevent farm creation in PlanSaveService when limit reached"

# ❌ BAD: Vague test names
test "farm limit test"
test "validation test"
test "service test"
```

### Test Organization
```ruby
# ✅ GOOD: Grouped by functionality
class FarmLimitTest < ActiveSupport::TestCase
  # Model-level tests
  test "should prevent creating 5th farm via direct creation"
  test "should allow unlimited reference farms"
  test "should allow updating existing farms when at limit"
  
  # Integration tests
  test "should prevent farm creation in PlanSaveService when limit reached"
  test "should prevent farm creation via controller when limit reached"
end
```

## 🚀 Test Execution Guidelines

### Running Tests
```bash
# Run specific test file
docker compose run --rm test bundle exec rails test test/models/farm_test.rb

# Run specific test method
docker compose run --rm test bundle exec rails test test/models/farm_test.rb -n test_should_prevent_creating_5th_farm

# Run integration tests
docker compose run --rm test bundle exec rails test test/integration/

# Run all tests
docker compose run --rm test bundle exec rails test
```

### Test Coverage Requirements
- [ ] Model-level validation: 100% coverage
- [ ] Integration scenarios: All critical paths
- [ ] Edge cases: All identified scenarios
- [ ] Error messages: All error conditions

## 📚 Historical Test Issues

### Past Test Failures
- **Controller-only validation**: Tests passed but direct DB operations failed
- **Missing integration tests**: Service objects not tested
- **Incomplete edge case coverage**: New user scenarios not tested

### Test Improvement History
- **2025-10-26 13:06**: Controller-level tests only (INSUFFICIENT)
- **2025-10-26 16:03**: Model-level tests added (IMPROVED)
- **2025-10-26 19:27**: Comprehensive integration tests (COMPLETE)

## 🎯 Success Metrics

### Test Quality Indicators
- [ ] All model validations have direct creation tests
- [ ] All service objects have integration tests
- [ ] All controllers have request tests
- [ ] All error messages are tested
- [ ] All edge cases are covered
- [ ] Tests run consistently without flakiness

### Test Maintenance
- [ ] Regular test execution
- [ ] Test failure investigation
- [ ] Test coverage monitoring
- [ ] Test performance optimization
- [ ] Test documentation updates
