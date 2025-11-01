# AGRR Architecture Documentation

## 🏗️ System Architecture Overview

AGRR is a Ruby on Rails application for agricultural planning and optimization, built with **Clean Architecture principles** and comprehensive internationalization support.

### Technology Stack
- **Framework**: Ruby on Rails 8
- **Database**: SQLite3 (development/test), with Litestream backup
- **Architecture**: Hybrid (Clean Architecture + Traditional Rails MVC)
- **Language**: Ruby
- **External Services**: Python-based AGRR CLI for advanced predictions

### Current Architecture Status

**Clean Architecture is partially implemented:**

- ✅ **API Controllers** (5/30): Full Clean Architecture adoption
  - `/api/v1/farms`, `/api/v1/crops`, `/api/v1/fields`, `/api/v1/fertilizes`
  - Uses Domain/Interactor/Gateway pattern
- ⚠️ **HTML Controllers** (25/30): Traditional Rails MVC
  - Direct Model usage (ActiveRecord)
  - No Interactor/Gateway layer
- ✅ **Domain Layer**: Complete implementation
  - Entities, Interactors, Gateway interfaces for Farm, Crop, Field, Fertilize
- ✅ **Adapter Layer**: Complete implementation
  - Memory Gateway implementations for all domain entities

**Migration Strategy**: The project is gradually adopting Clean Architecture, starting with API endpoints. HTML controllers remain on traditional Rails MVC for rapid iteration.

## 📊 Core Business Rules

### Resource Limits (CRITICAL)
- **Farm Limit**: Users can create maximum 4 farms (`is_reference: false`)
- **Crop Limit**: Users can create maximum 20 crops (`is_reference: false`)
- **Reference Records**: Always excluded from limits (`is_reference: true`)

### Implementation Architecture

The system follows Clean Architecture with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│         Infrastructure Layer            │
│  (Controllers, Models, Services)        │
│  - Rails MVC                            │
│  - Database Access (ActiveRecord)       │
│  - External Services                    │
└─────────────────────────────────────────┘
            ↓ ↑
┌─────────────────────────────────────────┐
│         Adapter Layer                   │
│  (lib/adapters/)                        │
│  - Gateway Implementations             │
│  - Memory Gateway                       │
│  - External API Gateway                │
└─────────────────────────────────────────┘
            ↓ ↑
┌─────────────────────────────────────────┐
│         UseCase Layer                   │
│  (lib/domain/)                          │
│  - Interactors (Application Logic)      │
│  - Gateways (Interfaces)                │
│  - Entities (Domain Models)             │
└─────────────────────────────────────────┘
            ↓ ↑
┌─────────────────────────────────────────┐
│         Domain Layer                    │
│  (Business Rules & Entities)            │
│  - Core Business Logic                  │
│  - Domain Entities                      │
│  - Value Objects                        │
└─────────────────────────────────────────┘
```

## 🎯 Layer Responsibilities

### 1. Infrastructure Layer (app/)
- **Controllers**: Handle HTTP requests/responses
- **Models**: ActiveRecord ORM, validations, database persistence
- **Jobs**: Background job processing
- **Services**: Application-level orchestration

### 2. Adapter Layer (lib/adapters/)
- **Gateway Implementations**: Concrete implementations of domain gateways
- **Memory Gateway**: Maps ActiveRecord models to domain entities
- **External API Gateway**: Integrates with external services

Example:
```ruby
# lib/adapters/farm/gateways/farm_memory_gateway.rb
module Adapters
  module Farm
    module Gateways
      class FarmMemoryGateway < Domain::Farm::Gateways::FarmGateway
        def create(farm_data)
          farm_record = ::Farm.create!(farm_data)
          entity_from_record(farm_record)
        end
        
        private
        
        def entity_from_record(record)
          Domain::Farm::Entities::FarmEntity.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
```

### 3. UseCase Layer (lib/domain/)
- **Interactors**: Application use cases (one use case per class)
- **Gateways**: Interface definitions for data access
- **Entities**: Rich domain models with business logic

Example:
```ruby
# lib/domain/farm/interactors/farm_create_interactor.rb
module Domain
  module Farm
    module Interactors
      class FarmCreateInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(farm_data)
          validate_input(farm_data)
          farm_entity = Entities::FarmEntity.new(farm_data)
          created_farm = @gateway.create(farm_data)
          Domain::Shared::Result.success(created_farm)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end

        private

        def validate_input(data)
          raise ArgumentError, "Name is required" if data[:name].blank?
          raise ArgumentError, "User ID is required" if data[:user_id].blank?
        end
      end
    end
  end
end
```

### 4. Domain Layer (lib/domain/)
- **Entities**: Rich domain models with behavior
- **Business Rules**: Core domain logic
- **Value Objects**: Immutable domain concepts

Example:
```ruby
# lib/domain/farm/entities/farm_entity.rb
module Domain
  module Farm
    module Entities
      class FarmEntity
        attr_reader :id, :user_id, :name, :latitude, :longitude, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @latitude = attributes[:latitude]
          @longitude = attributes[:longitude]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def coordinates
          [latitude, longitude]
        end

        def has_coordinates?
          latitude.present? && longitude.present?
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if name.blank?
          raise ArgumentError, "User ID is required" if user_id.blank?
          
          if latitude
            lat_num = latitude.to_f
            raise ArgumentError, "Latitude must be between -90 and 90" if lat_num < -90 || lat_num > 90
          end
          
          if longitude
            lng_num = longitude.to_f
            raise ArgumentError, "Longitude must be between -180 and 180" if lng_num < -180 || lng_num > 180
          end
        end
      end
    end
  end
end
```

## 🔄 Data Flow Architecture

### Request Flow
```
1. HTTP Request → Controller
2. Controller → Interactor (UseCase)
3. Interactor → Gateway (Interface)
4. Gateway → ActiveRecord Model
5. Model → Database
6. Gateway → Entity (Domain Object)
7. Entity → Interactor
8. Interactor → Result
9. Result → Controller
10. Controller → Response
```

### Controller Pattern
```ruby
# app/controllers/api/v1/farms/farm_api_controller.rb
class Api::V1::Farms::FarmApiController < Api::V1::BaseController
  before_action :set_interactors

  def create
    farm_params_with_user = farm_params.merge(user_id: current_user.id)
    result = @create_interactor.call(farm_params_with_user)
    
    if result.success?
      render json: farm_to_json(result.data), status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  private

  def set_interactors
    gateway = Adapters::Farm::Gateways::FarmMemoryGateway.new
    @create_interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(gateway)
    @find_interactor = Domain::Farm::Interactors::FarmFindInteractor.new(gateway)
    @update_interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(gateway)
    @delete_interactor = Domain::Farm::Interactors::FarmDeleteInteractor.new(gateway)
    @find_all_interactor = Domain::Farm::Interactors::FarmFindAllInteractor.new(gateway)
  end
end
```

## 🎯 Validation Architecture

### Multi-Layer Validation
The system employs validation at multiple layers for security and user experience:

```
1. Domain Layer Validation (lib/domain/)
   ├── Entity validation
   ├── Business rule enforcement
   └── Core domain logic

2. UseCase Layer Validation (lib/domain/)
   ├── Interactor input validation
   ├── Cross-entity validation
   └── Use case orchestration

3. Infrastructure Layer Validation (app/)
   ├── ActiveRecord model validation
   ├── Controller parameter validation
   └── Service object validation
```

### Resource Limit Implementation Pattern

The resource limit validation spans multiple layers:

```ruby
# 1. Domain Entity (lib/domain/farm/entities/farm_entity.rb)
class FarmEntity
  def initialize(attributes)
    # Entity-level validation
    validate!
  end

  private

  def validate!
    raise ArgumentError, "Name is required" if name.blank?
    raise ArgumentError, "User ID is required" if user_id.blank?
  end
end

# 2. Infrastructure Model (app/models/farm.rb)
class Farm < ApplicationRecord
  validates :user, presence: true
  validate :user_farm_count_limit, unless: :is_reference?

  private

  def user_farm_count_limit
    return if user.nil? || is_reference?
    
    existing_farms_count = user.farms.where(is_reference: false).count
    current_count = new_record? ? existing_farms_count : existing_farms_count - 1
    
    if current_count >= 4
      errors.add(:user, :farm_limit_exceeded)
    end
  end
end

# 3. Controller Usage (app/controllers/api/v1/farms/farm_api_controller.rb)
def create
  result = @create_interactor.call(farm_params_with_user)
  
  if result.success?
    render json: farm_to_json(result.data), status: :created
  else
    render json: { error: result.error }, status: :unprocessable_entity
  end
end
```

## 🧪 Testing Architecture

### Test Pyramid Structure
```
1. Unit Tests (70%)
   ├── Domain entities
   ├── Interactors
   ├── Gateway implementations
   └── Business logic

2. Integration Tests (20%)
   ├── Controller-interactor integration
   ├── Gateway-model integration
   ├── Cross-layer workflows
   └── Service objects

3. System Tests (10%)
   ├── User flows
   ├── UI interactions
   └── End-to-end scenarios
```

### Test Location Structure
```
test/
├── domain/                    # Domain layer tests
│   ├── farm/
│   │   ├── entities/         # Entity tests
│   │   ├── interactors/      # Interactor tests
│   │   └── gateways/         # Gateway interface tests
│   └── shared/
├── adapters/                  # Adapter layer tests
│   ├── farm/
│   │   └── gateways/         # Gateway implementation tests
│   └── ...
├── models/                    # Model tests
├── controllers/               # Controller tests
├── services/                  # Service tests
├── integration/               # Integration tests
└── system/                    # System tests
```

### Test Patterns

#### Domain Entity Test
```ruby
# test/domain/farm/entities/farm_entity_test.rb
class Domain::Farm::Entities::FarmEntityTest < ActiveSupport::TestCase
  test "should raise error when name is blank" do
    assert_raises(ArgumentError, "Name is required") do
      Domain::Farm::Entities::FarmEntity.new(
        user_id: 1,
        latitude: 35.0,
        longitude: 139.0
      )
    end
  end

  test "should create valid entity with all attributes" do
    entity = Domain::Farm::Entities::FarmEntity.new(
      id: 1,
      user_id: 1,
      name: "Test Farm",
      latitude: 35.0,
      longitude: 139.0,
      created_at: Time.current,
      updated_at: Time.current
    )

    assert_equal "Test Farm", entity.name
    assert_equal [35.0, 139.0], entity.coordinates
    assert entity.has_coordinates?
  end
end
```

#### Interactor Test
```ruby
# test/domain/farm/interactors/farm_create_interactor_test.rb
class Domain::Farm::Interactors::FarmCreateInteractorTest < ActiveSupport::TestCase
  setup do
    @mock_gateway = Minitest::Mock.new
    @interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(@mock_gateway)
  end

  test "should create farm successfully" do
    farm_data = {
      user_id: 1,
      name: "Test Farm",
      latitude: 35.0,
      longitude: 139.0
    }

    @mock_gateway.expect :create, 
      Domain::Farm::Entities::FarmEntity.new({id: 1, **farm_data, created_at: Time.current, updated_at: Time.current})

    result = @interactor.call(farm_data)

    assert result.success?
    assert_equal "Test Farm", result.data.name
    @mock_gateway.verify
  end

  test "should return failure when name is blank" do
    result = @interactor.call({user_id: 1, name: ""})

    assert result.failure?
    assert_includes result.error, "Name is required"
  end
end
```

#### Integration Test
```ruby
# test/integration/farm_limit_integration_test.rb
class FarmLimitIntegrationTest < ActiveSupport::TestCase
  test "should prevent creating 5th farm" do
    user = create(:user)
    
    # Create 4 farms
    4.times do |i|
      Farm.create!(
        user: user,
        name: "Farm #{i + 1}",
        latitude: 35.0 + i * 0.1,
        longitude: 135.0 + i * 0.1,
        is_reference: false
      )
    end
    
    # Attempt 5th farm creation
    farm5 = Farm.new(
      user: user,
      name: "Farm 5",
      latitude: 35.5,
      longitude: 135.5,
      is_reference: false
    )
    
    assert_not farm5.valid?
    assert_includes farm5.errors[:user], "作成できるFarmは4件までです"
  end
end
```

## 🚫 Anti-Patterns (FORBIDDEN)

### Architecture Anti-Patterns
```ruby
# ❌ FORBIDDEN: Controller depending on domain interfaces
class FarmsController < ApplicationController
  def create
    # Controller should not depend on Domain interfaces directly
    interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(gateway)
  end
end

# ✅ CORRECT: Controller instantiates adapters and interactors
class FarmsController < ApplicationController
  before_action :set_interactors

  private

  def set_interactors
    gateway = Adapters::Farm::Gateways::FarmMemoryGateway.new
    @create_interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(gateway)
  end
end

# ❌ FORBIDDEN: Patches in tests
test "should create farm" do
  Farm.expect(:create, some_farm)
  # ...
end

# ✅ CORRECT: Use dependency injection
test "should create farm" do
  gateway = Adapters::Farm::Gateways::FarmMemoryGateway.new
  interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(gateway)
  # ...
end
```

### Testing Anti-Patterns
```ruby
# ❌ FORBIDDEN: Testing only controller level
test "controller prevents farm creation" do
  post farms_path, params: { farm: {} }
  assert_response :unprocessable_entity
end

# ✅ CORRECT: Test multiple layers
test "model prevents farm creation when limit reached" do
  # Model-level test
  farm = Farm.new(user: user_with_4_farms, ...)
  assert_not farm.valid?
end

test "controller prevents farm creation when limit reached" do
  # Controller-level test
  post farms_path, params: { farm: {} }
  assert_response :unprocessable_entity
end

test "integration test ensures end-to-end validation" do
  # Integration test
  result = interactor.call(farm_data)
  assert result.failure?
end
```

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

# ✅ CORRECT: Multi-layer validation
# 1. Model-level validation (mandatory)
# 2. Controller-level validation (supplementary)
# 3. Service/Interactor validation (business logic)
```

## 📚 Implementation Guidelines

### Before Implementing New Feature

#### 1. Analyze Requirements
- Identify domain concepts
- Determine use cases
- Map relationships

#### 2. Design Domain Layer
- Create entities
- Define business rules
- Identify value objects

#### 3. Design UseCase Layer
- Create gateway interfaces
- Implement interactors
- Define result types

#### 4. Implement Adapter Layer
- Create gateway implementations
- Map to infrastructure models
- Handle external integrations

#### 5. Implement Infrastructure Layer
- Create ActiveRecord models
- Implement controllers
- Add services if needed

#### 6. Write Tests
- Domain entity tests
- Interactor tests
- Gateway tests
- Integration tests
- System tests

### Implementation Checklist

#### Domain Layer
- [ ] Entity classes created
- [ ] Business rules implemented
- [ ] Validation logic added
- [ ] Unit tests written

#### UseCase Layer
- [ ] Gateway interfaces defined
- [ ] Interactors implemented
- [ ] Result types used
- [ ] Unit tests written

#### Adapter Layer
- [ ] Gateway implementations created
- [ ] Mapping logic implemented
- [ ] External integrations handled
- [ ] Unit tests written

#### Infrastructure Layer
- [ ] Models created with validations
- [ ] Controllers implemented
- [ ] Jobs/services added as needed
- [ ] Integration tests written

#### Testing
- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] System tests passing
- [ ] Coverage acceptable

## 🔍 Quality Assurance

### Code Review Checklist

#### Domain Layer
- [ ] Entities contain business logic
- [ ] No infrastructure dependencies
- [ ] Clear naming conventions
- [ ] Comprehensive tests

#### UseCase Layer
- [ ] Interactors are single-purpose
- [ ] Gateways properly abstracted
- [ ] Results used consistently
- [ ] Comprehensive tests

#### Adapter Layer
- [ ] Gateway implementations complete
- [ ] Proper error handling
- [ ] No domain logic leakage
- [ ] Comprehensive tests

#### Infrastructure Layer
- [ ] Models validated properly
- [ ] Controllers are thin
- [ ] Services orchestrate properly
- [ ] Integration tests cover critical paths

### Success Criteria

A feature implementation is correct when:
- [ ] Domain logic is in domain layer
- [ ] Use cases are in interactors
- [ ] Infrastructure concerns are isolated
- [ ] Tests cover all layers
- [ ] No patches used in tests
- [ ] Clear separation of concerns
- [ ] Easy to test and maintain

## 🚀 Future Considerations

### Scalability
- Resource limits may need to be configurable
- Different user tiers may have different limits
- Reference data management may need optimization

### Architecture Improvements
- Add repository pattern for complex queries
- Implement CQRS for read/write separation
- Consider event sourcing for audit trails

### Monitoring
- Resource usage metrics
- Performance monitoring
- Architecture compliance checking

### Maintenance
- Regular architecture reviews
- Dependency analysis
- Documentation updates

## 📖 Additional Resources

### Related Documentation
- [DEVELOPMENT_RULES.md](docs/DEVELOPMENT_RULES.md): Development conventions
- [TESTING_GUIDELINES.md](docs/TESTING_GUIDELINES.md): Testing standards
- [RESOURCE_LIMIT_TEMPLATE.md](docs/RESOURCE_LIMIT_TEMPLATE.md): Resource limit pattern

### Key Principles
1. **Dependency Rule**: Inner layers must not depend on outer layers
2. **Single Responsibility**: Each class has one reason to change
3. **Dependency Injection**: Dependencies are injected, not created
4. **Testability**: All code should be easily testable without patches
5. **Domain-Driven Design**: Business logic drives the architecture