# AGRR Architecture Documentation

## 🏗️ System Architecture Overview

AGRR is a Ruby on Rails application for agricultural planning and optimization, built with Clean Architecture principles and comprehensive internationalization support.

## 📊 Core Business Rules

### Resource Limits (CRITICAL)
- **Farm Limit**: Users can create maximum 4 farms (`is_reference: false`)
- **Crop Limit**: Users can create maximum 20 crops (`is_reference: false`)
- **Reference Records**: Always excluded from limits (`is_reference: true`)

### Implementation Architecture
- **Model-Level Validation**: MANDATORY for all business rules
- **Controller-Level Validation**: Supplementary only
- **Service Objects**: Handle complex business logic
- **Direct Database Operations**: Must respect model validations

## 🎯 Validation Architecture

### Model Validation Priority
```
1. Model-Level Validation (MANDATORY)
   ├── Business rule enforcement
   ├── Data integrity
   └── Direct database operation protection

2. Controller-Level Validation (SUPPLEMENTARY)
   ├── User experience enhancement
   ├── Early error detection
   └── UI feedback

3. Service Object Validation (BUSINESS LOGIC)
   ├── Complex workflow validation
   ├── Cross-model validation
   └── Error handling and messaging
```

### Resource Limit Implementation Pattern
```ruby
class Farm < ApplicationRecord
  # MANDATORY: Model-level validation
  validate :user_farm_count_limit, unless: :is_reference?
  
  private
  
  def user_farm_count_limit
    return if user.nil? || is_reference?
    
    existing_count = user.farms.where(is_reference: false).count
    current_count = new_record? ? existing_count : existing_count - 1
    
    if current_count >= 4
      errors.add(:user, "作成できるFarmは4件までです")
    end
  end
end
```

## 🧪 Testing Architecture

### Test Pyramid Structure
```
1. Unit Tests (Model Level)
   ├── Direct model validation
   ├── Business rule enforcement
   └── Edge case handling

2. Integration Tests (Service Level)
   ├── Cross-model interactions
   ├── Service object workflows
   └── Error propagation

3. System Tests (Controller Level)
   ├── User flow validation
   ├── UI interaction testing
   └── End-to-end scenarios
```

### Resource Limit Testing Requirements
```ruby
# MANDATORY: Model-level test
test "should prevent creating 5th farm" do
  4.times { create(:farm, user: @user) }
  
  farm5 = Farm.new(user: @user, name: "Farm 5", ...)
  assert_not farm5.valid?
  assert_includes farm5.errors[:user], "作成できるFarmは4件までです"
end

# MANDATORY: Integration test
test "should prevent farm creation in PlanSaveService when limit reached" do
  4.times { create(:farm, user: @user) }
  
  result = PlanSaveService.new(user: @user, session_data: data).call
  assert_not result.success
  assert_includes result.error_message, "作成できるFarmは4件までです"
end
```

## 🔄 Data Flow Architecture

### User Resource Creation Flow
```
1. User Action (Controller)
   ├── Parameter validation
   ├── Authentication check
   └── Authorization check

2. Business Logic (Service Object)
   ├── Cross-model validation
   ├── Resource limit check
   └── Data transformation

3. Model Validation (ActiveRecord)
   ├── Business rule enforcement
   ├── Data integrity check
   └── Resource limit validation

4. Database Operation
   ├── Transaction management
   ├── Constraint enforcement
   └── Data persistence
```

### Error Handling Architecture
```
1. Model Level
   ├── Validation errors
   ├── Business rule violations
   └── Data integrity issues

2. Service Level
   ├── Workflow errors
   ├── Cross-model validation
   └── External service errors

3. Controller Level
   ├── Parameter errors
   ├── Authentication errors
   └── Authorization errors
```

## 🚫 Anti-Patterns (FORBIDDEN)

### Resource Limit Anti-Patterns
```ruby
# ❌ FORBIDDEN: Controller-only validation
def create
  return if user.farms.count >= 4  # Can be bypassed!
end

# ❌ FORBIDDEN: New user exception
def validate_farm_count
  return true if is_new_user?  # Allows unlimited creation!
end

# ❌ FORBIDDEN: Reference check in controller only
def create
  return if farm.is_reference?  # Can be bypassed!
end
```

### Testing Anti-Patterns
```ruby
# ❌ FORBIDDEN: Testing only controller level
test "controller prevents farm creation" do
  # This doesn't test direct database operations!
end

# ❌ FORBIDDEN: Missing integration tests
# Service objects must be tested for resource limits
```

## 📚 Historical Context

### Past Issues and Solutions
- **2025-10-26 13:06**: Controller-only validation (BROKEN)
  - **Problem**: Direct `Farm.create!` bypassed validation
  - **Solution**: Model-level validation required
  
- **2025-10-26 16:03**: Model-level validation (CORRECT)
  - **Solution**: `UserResourceLimitValidator` implementation
  
- **2025-10-26 19:27**: Simplified model validation (CORRECT)
  - **Solution**: Direct validation methods in models

### Lessons Learned
1. **Model-level validation is non-negotiable**
2. **Controller-only validation is insufficient**
3. **Direct database operations must be tested**
4. **Reference records must be properly excluded**
5. **Service objects must handle resource limits**

## 🎯 Implementation Guidelines

### Before Implementing Resource Limits
- [ ] Identify resource type and limit number
- [ ] Determine reference record exclusion rules
- [ ] Plan model-level validation approach
- [ ] Plan controller-level validation (supplementary)
- [ ] Plan service object integration

### During Implementation
- [ ] Implement model-level validation first
- [ ] Test with direct database operations
- [ ] Implement controller-level validation
- [ ] Test actual user flows
- [ ] Update service objects
- [ ] Add Japanese error messages

### After Implementation
- [ ] Run comprehensive test suite
- [ ] Test edge cases (new users, updates, etc.)
- [ ] Verify error messages are user-friendly
- [ ] Document the implementation
- [ ] Update architecture documentation

## 🔍 Quality Assurance

### Code Review Checklist
- [ ] Model-level validation implemented
- [ ] Controller-level validation implemented
- [ ] Service object integration completed
- [ ] Tests cover both model and integration levels
- [ ] Error messages are clear and in Japanese
- [ ] Reference records are properly excluded
- [ ] Edge cases are handled

### Success Criteria
A resource limit implementation is correct when:
- [ ] Direct `Model.create!` respects the limit
- [ ] Controller actions respect the limit
- [ ] Service objects respect the limit
- [ ] Reference records are excluded
- [ ] Error messages are clear and in Japanese
- [ ] Tests cover both model and integration levels
- [ ] Edge cases are handled (new users, updates, etc.)

## 🚀 Future Considerations

### Scalability
- Resource limits may need to be configurable
- Different user tiers may have different limits
- Reference data management may need optimization

### Monitoring
- Resource usage metrics
- Limit violation attempts
- Performance impact of validations

### Maintenance
- Regular validation testing
- Architecture compliance reviews
- Documentation updates
