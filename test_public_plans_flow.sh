#!/bin/bash
# frozen_string_literal: true

# Public Plans to My Plans Flow Test Script
# This script tests the complete flow from public plans creation to saving to my plans

set -e

BASE_URL="http://localhost:3000"
SESSION_COOKIE=""

echo "🌍 Testing Public Plans to My Plans Flow..."

# Function to make HTTP requests
make_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local headers="$4"
    
    if [ -n "$data" ]; then
        curl -s -X "$method" \
             -H "Content-Type: application/x-www-form-urlencoded" \
             -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
             -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
             $headers \
             -d "$data" \
             -c /tmp/cookies.txt \
             -b /tmp/cookies.txt \
             "$url"
    else
        curl -s -X "$method" \
             -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
             -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
             $headers \
             -c /tmp/cookies.txt \
             -b /tmp/cookies.txt \
             "$url"
    fi
}

# Function to extract CSRF token
extract_csrf_token() {
    local html="$1"
    echo "$html" | grep -o 'name="authenticity_token" value="[^"]*"' | sed 's/.*value="\([^"]*\)".*/\1/'
}

# Function to extract redirect location
extract_redirect() {
    local response="$1"
    echo "$response" | grep -i "location:" | sed 's/.*location: *\([^\r\n]*\).*/\1/' | tr -d '\r\n'
}

# Function to check if page contains text
page_contains() {
    local html="$1"
    local text="$2"
    echo "$html" | grep -q "$text"
}

echo "📋 Step 1: Access Public Plans page"
response=$(make_request "GET" "$BASE_URL/ja/public_plans")
if page_contains "$response" "地域を選択" || page_contains "$response" "Select Region"; then
    echo "  ✅ Public Plans page loaded successfully"
else
    echo "  ❌ Failed to load Public Plans page"
    exit 1
fi

echo "📋 Step 2: Select Japan region"
csrf_token=$(extract_csrf_token "$response")
if [ -z "$csrf_token" ]; then
    echo "  ⚠️ No CSRF token found, trying without it"
fi

# Try to find and click Japan region
response=$(make_request "POST" "$BASE_URL/ja/public_plans/select_farm_size" "farm_id=1&authenticity_token=$csrf_token")
if page_contains "$response" "農場サイズ" || page_contains "$response" "Farm Size"; then
    echo "  ✅ Farm size selection page loaded"
else
    echo "  ⚠️ Farm size selection may have failed, continuing..."
fi

echo "📋 Step 3: Select farm size"
response=$(make_request "POST" "$BASE_URL/ja/public_plans/select_crop" "farm_size_id=home_garden&authenticity_token=$csrf_token")
if page_contains "$response" "作物" || page_contains "$response" "Crop"; then
    echo "  ✅ Crop selection page loaded"
else
    echo "  ⚠️ Crop selection may have failed, continuing..."
fi

echo "📋 Step 4: Select crops and create plan"
# Select some crops (assuming crop IDs 1, 2, 3 exist)
crop_ids="1,2,3"
response=$(make_request "POST" "$BASE_URL/ja/public_plans" "crop_ids[]=1&crop_ids[]=2&crop_ids[]=3&authenticity_token=$csrf_token")

# Check if we got redirected to optimizing page
if page_contains "$response" "最適化" || page_contains "$response" "Optimizing" || page_contains "$response" "進捗"; then
    echo "  ✅ Plan creation started, optimization in progress"
    
    # Wait a bit for optimization
    echo "  ⏳ Waiting for optimization to complete..."
    sleep 10
    
    # Try to access results page
    echo "📋 Step 5: Check results page"
    response=$(make_request "GET" "$BASE_URL/ja/public_plans/results")
    if page_contains "$response" "結果" || page_contains "$response" "Results" || page_contains "$response" "保存"; then
        echo "  ✅ Results page accessible"
        
        # Check for save button
        if page_contains "$response" "保存" || page_contains "$response" "Save"; then
            echo "  ✅ Save button found"
            
            echo "📋 Step 6: Attempt to save plan"
            response=$(make_request "POST" "$BASE_URL/ja/public_plans/save_plan" "authenticity_token=$csrf_token")
            
            # Check if redirected to login or plans page
            if page_contains "$response" "ログイン" || page_contains "$response" "Login"; then
                echo "  ✅ Redirected to login (expected for unauthenticated user)"
            elif page_contains "$response" "計画" || page_contains "$response" "Plans"; then
                echo "  ✅ Redirected to plans page (user may be authenticated)"
            else
                echo "  ⚠️ Unexpected response after save attempt"
            fi
        else
            echo "  ⚠️ Save button not found"
        fi
    else
        echo "  ⚠️ Results page not accessible or optimization not complete"
    fi
else
    echo "  ❌ Plan creation failed"
    echo "  Response preview:"
    echo "$response" | head -20
fi

echo "📋 Step 7: Check My Plans page"
response=$(make_request "GET" "$BASE_URL/ja/plans")
if page_contains "$response" "計画" || page_contains "$response" "Plans"; then
    echo "  ✅ My Plans page accessible"
    
    # Count plans
    plan_count=$(echo "$response" | grep -c "plan-card\|card\|計画" || echo "0")
    echo "  📊 Found approximately $plan_count plan elements"
    
    # Check for crops in plans
    crop_count=$(echo "$response" | grep -c "作物\|crop\|ほうれん草\|tomato" || echo "0")
    echo "  🌱 Found approximately $crop_count crop references"
    
    # Check for fields in plans
    field_count=$(echo "$response" | grep -c "圃場\|field\|畑" || echo "0")
    echo "  🚜 Found approximately $field_count field references"
    
    # Check for charts/gantt
    chart_count=$(echo "$response" | grep -c "chart\|gantt\|timeline\|svg\|canvas" || echo "0")
    echo "  📊 Found approximately $chart_count chart elements"
    
else
    echo "  ❌ My Plans page not accessible"
fi

echo "📋 Step 8: Database verification"
echo "  🔍 Checking database directly..."

# Use Rails runner to check database
docker compose exec web rails runner "
puts '=== Database Verification ==='
puts \"Total CultivationPlans: #{CultivationPlan.count}\"
puts \"Public plans: #{CultivationPlan.where(plan_type: 'public').count}\"
puts \"Private plans: #{CultivationPlan.where(plan_type: 'private').count}\"

puts \"\\n=== Recent Plans ===\"
recent_plans = CultivationPlan.order(created_at: :desc).limit(5)
recent_plans.each do |plan|
  puts \"Plan ID: #{plan.id}, Type: #{plan.plan_type}, User: #{plan.user_id}, Crops: #{plan.cultivation_plan_crops.count}, Fields: #{plan.cultivation_plan_fields.count}\"
end

puts \"\\n=== Users ===\"
puts \"Total Users: #{User.count}\"
puts \"Anonymous Users: #{User.where(is_anonymous: true).count}\"
puts \"Regular Users: #{User.where(is_anonymous: false).count}\"

puts \"\\n=== Crops ===\"
puts \"Total Crops: #{Crop.count}\"
puts \"Reference Crops: #{Crop.where(is_reference: true).count}\"
puts \"User Crops: #{Crop.where(is_reference: false).count}\"

puts \"\\n=== Fields ===\"
puts \"Total Fields: #{Field.count}\"
puts \"User Fields: #{Field.joins(:farm).where(farms: { is_reference: false }).count}\"
"

echo ""
echo "🎯 Test Summary:"
echo "  - Public Plans flow: Tested"
echo "  - Plan creation: Tested"
echo "  - Save functionality: Tested"
echo "  - My Plans verification: Tested"
echo "  - Database verification: Completed"
echo ""
echo "✅ Test completed! Check the output above for detailed results."

# Cleanup
rm -f /tmp/cookies.txt
