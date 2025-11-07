## Required (8 items)
1. `Plowing` - Plowing
2. `Base Fertilization` - Base Fertilization
3. `Seeding` - Seeding
4. `Transplanting` - Transplanting
5. `Watering` - Watering
6. `Weeding` - Weeding
7. `Harvesting` - Harvesting
8. `Shipping Preparation` - Shipping Preparation

### Conditional Required (Required when used, every season)
9. `Mulching` - Mulching
10. `Tunnel Setup` - Tunnel Setup
11. `Support Structure Setup` - Support Structure Setup
12. `Net Installation` - Net Installation
13. `Thinning` - Thinning (direct seeding crops)
14. `Pruning` - Pruning (fruit vegetables)
15. `Training` - Training (fruit vegetables)
16. `Grading` - Grading
17. `Packaging` - Packaging

## Reference Crops (United States)

The US reference crops from migration `20251018075149_seed_united_states_reference_data.rb` are the following 30 types:

1. Almonds (Nonpareil)
2. Apples (Red Delicious)
3. Barley
4. Bell Peppers
5. Blueberries
6. Broccoli
7. Cabbage
8. Carrots (Standard)
9. Corn
10. Cotton (Upland Cotton)
11. Cucumbers
12. Grapes
13. Lettuce
14. Oats
15. Onions
16. Oranges
17. Peanuts
18. Pistachios
19. Potatoes
20. Rice (Long Grain)
21. Rye
22. Sorghum
23. Soybeans (Standard)
24. Strawberries
25. Sugar Beets
26. Sugarcane
27. Tomatoes
28. Walnuts
29. Watermelon
30. Wheat (Winter Wheat)

Each crop is loaded from `db/fixtures/us_reference_crops.json` and registered with `region='us'`, `is_reference=true`.

## Migration Creation Checklist

For each task, the following attributes need to be confirmed:

### AgriculturalTask Model Attributes

- `name` (string, required): Task name. Uniqueness required (reference tasks are unique by name, user-owned tasks are unique within user)
- `description` (text, nullable): Task description
- `time_per_sqm` (float, nullable): Time required per unit area (sqm) in hours/sqm
- `weather_dependency` (string, nullable): Weather dependency. Values: 'low', 'medium', 'high'
- `required_tools` (text, nullable): Required tools. Stored as JSON array (e.g., `["Shovel", "Trowel"]`)
- `skill_level` (string, nullable): Skill level. Values: 'beginner', 'intermediate', 'advanced'
- `is_reference` (boolean, default: true): Reference task flag. Master data is true
- `user_id` (integer, nullable): User ID. Null for reference tasks
- `region` (string, nullable): Region code. 'jp', 'us', 'in', etc.

### Task Checklist

#### 1. `Plowing` - Plowing
- **name**: `Plowing`
- **description**: "Tilling soil to make it soft"
- **time_per_sqm**: 0.05 hours/sqm (manual work)
- **weather_dependency**: 'medium' or 'high' (soil needs to be dry)
- **required_tools**: `["Shovel", "Hoe", "Tiller"]` etc. (no heavy machinery)
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 2. `Base Fertilization` - Base Fertilization
- **name**: `Base Fertilization`
- **description**: "Fertilizer mixed into soil before planting"
- **time_per_sqm**: 0.01 hours/sqm
- **weather_dependency**: 'low' (weather independent)
- **required_tools**: `["Shovel", "Fertilizer"]` etc.
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 3. `Seeding` - Seeding
- **name**: `Seeding`
- **description**: "Sowing seeds"
- **time_per_sqm**: 0.005 hours/sqm (seeding is fast)
- **weather_dependency**: 'medium' (moderate weather needed)
- **required_tools**: `["Seeds", "Seeder"]` etc. (no heavy machinery)
- **skill_level**: 'beginner' or 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (direct seeding crops)
  - [ ] Almonds
  - [ ] Apples
  - [x] Barley
  - [ ] Bell Peppers
  - [ ] Blueberries
  - [ ] Broccoli
  - [ ] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [ ] Grapes
  - [x] Lettuce
  - [x] Oats
  - [ ] Onions
  - [ ] Oranges
  - [x] Peanuts
  - [ ] Pistachios
  - [ ] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [ ] Strawberries
  - [x] Sugar Beets
  - [ ] Sugarcane
  - [ ] Tomatoes
  - [ ] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 4. `Transplanting` - Transplanting
- **name**: `Transplanting`
- **description**: "Planting seedlings"
- **time_per_sqm**: 0.02 hours/sqm (planting takes time)
- **weather_dependency**: 'medium' (moderate weather needed)
- **required_tools**: `["Seedlings", "Trowel"]` etc.
- **skill_level**: 'beginner' or 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (seedling crops)
  - [x] Almonds
  - [x] Apples
  - [ ] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [ ] Carrots
  - [ ] Corn
  - [ ] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [ ] Oats
  - [x] Onions
  - [x] Oranges
  - [ ] Peanuts
  - [x] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [x] Strawberries
  - [ ] Sugar Beets
  - [ ] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [ ] Watermelon
  - [ ] Wheat

#### 5. `Watering` - Watering
- **name**: `Watering`
- **description**: "Watering crops"
- **time_per_sqm**: 0.01 hours/sqm (varies by area)
- **weather_dependency**: 'high' (not needed if raining)
- **required_tools**: `["Hose", "Sprinkler"]` etc.
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 6. `Weeding` - Weeding
- **name**: `Weeding`
- **description**: "Removing weeds"
- **time_per_sqm**: 0.03 hours/sqm (manual work)
- **weather_dependency**: 'medium' (easier when soil is moist)
- **required_tools**: `["Sickle", "Weed Fork"]` etc. (no heavy machinery)
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 7. `Harvesting` - Harvesting
- **name**: `Harvesting`
- **description**: "Harvesting crops"
- **time_per_sqm**: 0.05 hours/sqm (varies by crop, manual work)
- **weather_dependency**: 'medium' (often avoided on rainy days)
- **required_tools**: `["Shears", "Harvest Basket"]` etc.
- **skill_level**: 'beginner' or 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 8. `Shipping Preparation` - Shipping Preparation
- **name**: `Shipping Preparation`
- **description**: "Preparation work before shipping (washing, sorting, etc.)"
- **time_per_sqm**: 0.05 hours/sqm (manual work)
- **weather_dependency**: 'low'
- **required_tools**: `["Bucket", "Sorting Basket", "Brush"]` etc. (no heavy machinery)
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 9. `Mulching` - Mulching
- **name**: `Mulching`
- **description**: "Laying mulch sheets"
- **time_per_sqm**: 0.01 hours/sqm
- **weather_dependency**: 'medium' (difficult on windy days)
- **required_tools**: `["Mulch Sheet", "Mulch Anchor"]` etc.
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (crops requiring mulching)
  - [x] Bell Peppers
  - [ ] Blueberries
  - [ ] Broccoli
  - [ ] Cabbage
  - [ ] Carrots
  - [ ] Corn
  - [ ] Cotton
  - [x] Cucumbers
  - [ ] Grapes
  - [ ] Lettuce
  - [ ] Oats
  - [ ] Onions
  - [ ] Oranges
  - [ ] Peanuts
  - [ ] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [x] Strawberries
  - [ ] Sugar Beets
  - [ ] Sugarcane
  - [x] Tomatoes
  - [ ] Walnuts
  - [x] Watermelon
  - [ ] Wheat

#### 10. `Tunnel Setup` - Tunnel Setup
- **name**: `Tunnel Setup`
- **description**: "Installing tunnel supports"
- **time_per_sqm**: 0.02 hours/sqm
- **weather_dependency**: 'medium' (difficult on windy days)
- **required_tools**: `["Tunnel Supports", "Plastic Sheet"]` etc.
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (crops requiring tunnel cultivation)
  - [ ] Almonds
  - [ ] Apples
  - [ ] Barley
  - [x] Bell Peppers
  - [ ] Blueberries
  - [ ] Broccoli
  - [ ] Cabbage
  - [ ] Carrots
  - [ ] Corn
  - [ ] Cotton
  - [x] Cucumbers
  - [ ] Grapes
  - [x] Lettuce
  - [ ] Oats
  - [ ] Onions
  - [ ] Oranges
  - [ ] Peanuts
  - [ ] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [x] Strawberries
  - [ ] Sugar Beets
  - [ ] Sugarcane
  - [x] Tomatoes
  - [ ] Walnuts
  - [ ] Watermelon
  - [ ] Wheat

#### 11. `Support Structure Setup` - Support Structure Setup
- **name**: `Support Structure Setup`
- **description**: "Setting up supports for crops"
- **time_per_sqm**: 0.015 hours/sqm
- **weather_dependency**: 'low'
- **required_tools**: `["Stakes", "Ties"]` etc.
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (crops requiring supports: vining or tall crops)
  - [ ] Almonds
  - [ ] Apples
  - [ ] Barley
  - [x] Bell Peppers
  - [ ] Blueberries
  - [ ] Broccoli
  - [ ] Cabbage
  - [ ] Carrots
  - [ ] Corn
  - [ ] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [ ] Lettuce
  - [ ] Oats
  - [ ] Onions
  - [ ] Oranges
  - [ ] Peanuts
  - [ ] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [ ] Strawberries
  - [ ] Sugar Beets
  - [ ] Sugarcane
  - [x] Tomatoes
  - [ ] Walnuts
  - [ ] Watermelon
  - [ ] Wheat

#### 12. `Net Installation` - Net Installation
- **name**: `Net Installation`
- **description**: "Installing pest control nets"
- **time_per_sqm**: 0.015 hours/sqm
- **weather_dependency**: 'medium' (difficult on windy days)
- **required_tools**: `["Pest Net", "Net Anchor"]` etc.
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (crops vulnerable to pests)
  - [ ] Almonds
  - [ ] Apples
  - [ ] Barley
  - [ ] Bell Peppers
  - [ ] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [ ] Carrots
  - [ ] Corn
  - [ ] Cotton
  - [ ] Cucumbers
  - [ ] Grapes
  - [x] Lettuce
  - [ ] Oats
  - [ ] Onions
  - [ ] Oranges
  - [ ] Peanuts
  - [ ] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [x] Strawberries
  - [ ] Sugar Beets
  - [ ] Sugarcane
  - [ ] Tomatoes
  - [ ] Walnuts
  - [ ] Watermelon
  - [ ] Wheat

#### 13. `Thinning` - Thinning
- **name**: `Thinning`
- **description**: "Thinning overcrowded seedlings"
- **time_per_sqm**: 0.01 hours/sqm
- **weather_dependency**: 'low'
- **required_tools**: `["Shears"]` etc.
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (direct seeded crops requiring thinning)
  - [ ] Almonds
  - [ ] Apples
  - [ ] Barley
  - [ ] Bell Peppers
  - [ ] Blueberries
  - [ ] Broccoli
  - [ ] Cabbage
  - [x] Carrots
  - [x] Corn
  - [ ] Cotton
  - [ ] Cucumbers
  - [ ] Grapes
  - [x] Lettuce
  - [ ] Oats
  - [ ] Onions
  - [ ] Oranges
  - [ ] Peanuts
  - [ ] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [ ] Strawberries
  - [x] Sugar Beets
  - [ ] Sugarcane
  - [ ] Tomatoes
  - [ ] Walnuts
  - [x] Watermelon
  - [ ] Wheat

#### 14. `Pruning` - Pruning
- **name**: `Pruning`
- **description**: "Cutting unnecessary branches"
- **time_per_sqm**: 0.02 hours/sqm
- **weather_dependency**: 'low'
- **required_tools**: `["Pruning Shears"]` etc.
- **skill_level**: 'intermediate' or 'advanced'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (fruit vegetables requiring pruning)
  - [x] Almonds
  - [x] Apples
  - [ ] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [ ] Broccoli
  - [ ] Cabbage
  - [ ] Carrots
  - [ ] Corn
  - [ ] Cotton
  - [ ] Cucumbers
  - [x] Grapes
  - [ ] Lettuce
  - [ ] Oats
  - [ ] Onions
  - [x] Oranges
  - [ ] Peanuts
  - [x] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [x] Strawberries
  - [ ] Sugar Beets
  - [ ] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [ ] Watermelon
  - [ ] Wheat

#### 15. `Training` - Training
- **name**: `Training`
- **description**: "Training crops on supports"
- **time_per_sqm**: 0.015 hours/sqm
- **weather_dependency**: 'low'
- **required_tools**: `["Ties", "Stakes"]` etc.
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (crops requiring training on supports)
  - [ ] Almonds
  - [ ] Apples
  - [ ] Barley
  - [x] Bell Peppers
  - [ ] Blueberries
  - [ ] Broccoli
  - [ ] Cabbage
  - [ ] Carrots
  - [ ] Corn
  - [ ] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [ ] Lettuce
  - [ ] Oats
  - [ ] Onions
  - [ ] Oranges
  - [ ] Peanuts
  - [ ] Pistachios
  - [ ] Potatoes
  - [ ] Rice
  - [ ] Rye
  - [ ] Sorghum
  - [ ] Soybeans
  - [ ] Strawberries
  - [ ] Sugar Beets
  - [ ] Sugarcane
  - [x] Tomatoes
  - [ ] Walnuts
  - [ ] Watermelon
  - [ ] Wheat

#### 16. `Grading` - Grading
- **name**: `Grading`
- **description**: "Sorting harvested produce by grade"
- **time_per_sqm**: 0.05 hours/sqm (manual work)
- **weather_dependency**: 'low'
- **required_tools**: `["Sorting Basket", "Grade Chart", "Scale"]` etc. (no heavy machinery)
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment (crops requiring grading)
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

#### 17. `Packaging` - Packaging
- **name**: `Packaging`
- **description**: "Packing into boxes or bags for shipping"
- **time_per_sqm**: 0.03 hours/sqm
- **weather_dependency**: 'low'
- **required_tools**: `["Boxes", "Bags", "Labels"]` etc.
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'us'
- **TODO**: Confirm crop assignment
  - [x] Almonds
  - [x] Apples
  - [x] Barley
  - [x] Bell Peppers
  - [x] Blueberries
  - [x] Broccoli
  - [x] Cabbage
  - [x] Carrots
  - [x] Corn
  - [x] Cotton
  - [x] Cucumbers
  - [x] Grapes
  - [x] Lettuce
  - [x] Oats
  - [x] Onions
  - [x] Oranges
  - [x] Peanuts
  - [x] Pistachios
  - [x] Potatoes
  - [x] Rice
  - [x] Rye
  - [x] Sorghum
  - [x] Soybeans
  - [x] Strawberries
  - [x] Sugar Beets
  - [x] Sugarcane
  - [x] Tomatoes
  - [x] Walnuts
  - [x] Watermelon
  - [x] Wheat

## Migration Creation Notes

1. **Initial Implementation Policy**: 
   - **Create master data for United States (region='us') only**
   - All tasks created as reference tasks (is_reference=true)
   - Add other regions ('jp', 'in', etc.) later in separate migrations

2. **Regional Creation**: Confirm whether tasks should be created per region ('jp', 'us', 'in')
   - Task names and descriptions may differ by region
   - Create separate records per region when needed
   - Initial implementation creates 'us' only

3. **Reference Task Settings**: 
   - All tasks created with `is_reference=true`
   - `user_id` is `null` (reference tasks are system-owned)

4. **Name Uniqueness**: 
   - Reference tasks (is_reference=true) are unique by name
   - When creating tasks with same name in multiple regions, confirm with region-inclusive search conditions
   - In initial implementation (us only), confirm uniqueness by name and is_reference=true

5. **Required Attributes**: 
   - `name` is required
   - `region` is set to 'us'
   - `is_reference` is set to true
   - `user_id` is set to null
   - Other attributes are nullable but recommended to set when possible

6. **JSON Array Handling**: 
   - `required_tools` stored as JSON array (e.g., `["Tool1", "Tool2"]`)
   - Serialize Ruby arrays with `to_json` for storage

7. **Existing Data Check**: 
   - Before running migration, check if tasks with same name (region='us', is_reference=true) exist in agricultural_tasks table
   - If exists, consider updating with `find_or_initialize_by` or creating new records

8. **Tools**: 
   - **No heavy machinery** premise (exclude tractors, rotary tillers, large machinery)
   - Set `required_tools` assuming manual tools only
   - Set `time_per_sqm` assuming manual work time

9. **Work Time (time_per_sqm)**: 
   - Unit is **hours/sqm**
   - Set realistic values assuming manual work
   - Actual work efficiency varies greatly by crop type, worker skill, weather, etc., so set as guideline
   - Consider adjusting for regional and cultural differences in work efficiency during migration (initial implementation uses standard US values)
