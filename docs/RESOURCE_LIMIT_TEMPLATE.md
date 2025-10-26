# Resource Limit Implementation Template

## 🎯 Template for Implementing Resource Limits

This template provides a standardized approach for implementing resource limits in the AGRR application.

### Step 1: Model-Level Validation

```ruby
# app/models/[resource].rb
class [Resource] < ApplicationRecord
  # Add validation
  validate :user_[resource]_count_limit, unless: :is_reference?
  
  private
  
  def user_[resource]_count_limit
    return if user.nil? || is_reference?
    
    existing_count = user.[resources].where(is_reference: false).count
    current_count = new_record? ? existing_count : existing_count - 1
    
    if current_count >= [LIMIT]
      errors.add(:user, "作成できる[Resource]は[LIMIT]件までです")
    end
  end
end
```

### Step 2: Model-Level Tests

```ruby
# test/models/[resource]_test.rb
class [Resource]Test < ActiveSupport::TestCase
  def setup
    @user = create(:user)
  end
  
  def teardown
    @user.destroy if @user&.persisted?
  end
  
  test "should prevent creating [LIMIT+1]th [resource] via direct creation" do
    # Setup: Create [LIMIT] [resources]
    [LIMIT].times { create(:[resource], user: @user, is_reference: false) }
    
    # Test: Attempt [LIMIT+1]th [resource] creation
    [resource][LIMIT+1] = [Resource].new(
      user: @user,
      name: "[Resource] [LIMIT+1]",
      # ... other required attributes
      is_reference: false
    )
    
    # Assert: Validation fails
    assert_not [resource][LIMIT+1].valid?, "[LIMIT+1]th [resource] should not be valid"
    assert_includes [resource][LIMIT+1].errors[:user], "作成できる[Resource]は[LIMIT]件までです"
  end
  
  test "should allow unlimited reference [resources]" do
    anonymous_user = User.anonymous_user
    initial_count = anonymous_user.[resources].where(is_reference: true).count
    
    # Create multiple reference [resources]
    5.times do |i|
      [resource] = [Resource].create!(
        user: anonymous_user,
        name: "Reference [Resource] #{i + 1}",
        # ... other required attributes
        is_reference: true
      )
      assert [resource].persisted?, "Reference [resource] #{i + 1} should be created"
    end
    
    expected_count = initial_count + 5
    assert_equal expected_count, anonymous_user.[resources].where(is_reference: true).count
  end
  
  test "should allow updating existing [resources] when at limit" do
    # Setup: Create [LIMIT] [resources]
    [LIMIT].times { create(:[resource], user: @user, is_reference: false) }
    
    # Test: Update existing [resource]
    existing_[resource] = @user.[resources].first
    existing_[resource].name = "Updated [Resource] Name"
    
    # Assert: Update succeeds
    assert existing_[resource].valid?, "Updating existing [resource] should be valid"
    assert existing_[resource].save, "Should be able to save updated [resource]"
  end
end
```

### Step 3: Integration Tests

```ruby
# test/integration/[resource]_limit_integration_test.rb
class [Resource]LimitIntegrationTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @ref_[resource] = [Resource].reference.first
    @ref_crop = Crop.reference.first
  end
  
  def teardown
    @user.destroy if @user&.persisted?
  end
  
  test "should prevent [resource] creation in PlanSaveService when limit reached" do
    # Setup: User with [LIMIT] [resources]
    [LIMIT].times do |i|
      create(:[resource], user: @user, name: "Existing [Resource] #{i + 1}", is_reference: false)
    end
    
    # Setup: Session data for PlanSaveService
    session_data = {
      farm_id: @ref_[resource].id,
      crop_ids: [@ref_crop.id],
      field_data: [{ name: 'Test Field', area: 100.0, coordinates: [35.0, 139.0] }]
    }
    
    # Create reference plan
    plan = CultivationPlan.create!(
      farm: @ref_[resource],
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
    assert_not result.success, "PlanSaveService should fail when [resource] limit reached"
    assert_includes result.error_message, "作成できる[Resource]は[LIMIT]件までです"
  end
  
  test "should prevent [resource] creation via controller when limit reached" do
    # Setup: User with [LIMIT] [resources]
    [LIMIT].times { create(:[resource], user: @user, is_reference: false) }
    
    # Test: POST request to create [resource]
    post [resources]_path, params: {
      [resource]: {
        name: "[Resource] [LIMIT+1]",
        # ... other required attributes
      }
    }
    
    # Assert: Request fails with appropriate response
    assert_response :unprocessable_entity
    assert_select 'div.errors', text: /[Resource]の数が上限/
  end
end
```

### Step 4: Service Object Integration

```ruby
# app/services/plan_save_service.rb
class PlanSaveService
  def call
    # ... existing code ...
    
    # Create new [resource] if needed
    unless new_[resource].save
      error_message = new_[resource].errors.full_messages.join(', ')
      Rails.logger.error "❌ [PlanSaveService] [Resource] creation failed: #{error_message}"
      
      # Handle [resource] limit error specifically
      if new_[resource].errors[:user].any? { |msg| msg.include?("作成できる[Resource]は[LIMIT]件までです") }
        raise StandardError, "作成できる[Resource]は[LIMIT]件までです"
      end
      
      raise StandardError, error_message
    end
    
    # ... rest of the code ...
  end
end
```

### Step 5: Internationalization

```yaml
# config/locales/models/activerecord.ja.yml
ja:
  activerecord:
    errors:
      models:
        [resource]:
          attributes:
            user:
              taken: "この[Resource]の計画は既に存在します"
```

### Step 6: Factory Updates

```ruby
# test/factories/[resources].rb
FactoryBot.define do
  factory :[resource] do
    association :user
    name { "Test [Resource]" }
    # ... other attributes
    is_reference { false }
    
    trait :reference do
      user { User.anonymous_user }
      is_reference { true }
    end
  end
end
```

## 📋 Implementation Checklist

### Before Implementation
- [ ] Identify resource type: [Resource]
- [ ] Determine limit number: [LIMIT]
- [ ] Check reference record exclusion: is_reference?
- [ ] Plan model-level validation approach
- [ ] Plan controller-level validation (supplementary)
- [ ] Plan service object integration

### During Implementation
- [ ] Implement model-level validation
- [ ] Test with direct database operations
- [ ] Implement controller-level validation
- [ ] Test actual user flows
- [ ] Update service objects
- [ ] Add Japanese error messages
- [ ] Create factories

### After Implementation
- [ ] Run comprehensive test suite
- [ ] Test edge cases (new users, updates, etc.)
- [ ] Verify error messages are user-friendly
- [ ] Document the implementation
- [ ] Update architecture documentation

## 🎯 Template Usage Examples

### Example 1: Farm Limit (4 farms)
- [Resource] = Farm
- [resource] = farm
- [resources] = farms
- [LIMIT] = 4

### Example 2: Crop Limit (20 crops)
- [Resource] = Crop
- [resource] = crop
- [resources] = crops
- [LIMIT] = 20

### Example 3: Field Limit (10 fields per farm)
- [Resource] = Field
- [resource] = field
- [resources] = fields
- [LIMIT] = 10
- Additional: Scope to specific farm

## 🚨 Critical Reminders

1. **ALWAYS implement model-level validation first**
2. **NEVER implement only controller-level validation**
3. **ALWAYS test direct database operations**
4. **ALWAYS test both model and integration levels**
5. **ALWAYS exclude reference records from limits**
6. **ALWAYS provide clear Japanese error messages**
7. **ALWAYS update service objects for new limits**
8. **ALWAYS create comprehensive tests**

## 📚 Historical Context

This template was created based on lessons learned from the farm limit implementation issues:
- **2025-10-26 13:06**: Controller-only validation (BROKEN)
- **2025-10-26 16:03**: Model-level validation (CORRECT)
- **2025-10-26 19:27**: Simplified model validation (CORRECT)

The template ensures consistent, reliable implementation of resource limits across the application.
