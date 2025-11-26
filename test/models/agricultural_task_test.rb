# frozen_string_literal: true

require "test_helper"

class AgriculturalTaskTest < ActiveSupport::TestCase
  test "should validate name presence" do
    task = AgriculturalTask.new
    task.valid?
    assert_includes task.errors[:name], "を入力してください"
  end

  test "should initialize with default required_tools as empty array" do
    task = AgriculturalTask.new(name: "テストタスク")
    assert_equal [], task.required_tools
  end

  test "should validate time_per_sqm is greater than 0" do
    task = build(:agricultural_task, time_per_sqm: -1)
    task.valid?
    assert_includes task.errors[:time_per_sqm], "は0より大きい値にしてください"
  end

  test "should allow nil for time_per_sqm" do
    task = build(:agricultural_task, time_per_sqm: nil)
    assert task.valid?
  end

  test "should validate user presence when is_reference is false" do
    task = AgriculturalTask.new(
      name: "テストタスク",
      is_reference: false,
      user_id: nil
    )
    assert_not task.valid?
    assert_includes task.errors[:user], "を入力してください"
  end

  test "should allow nil user_id when is_reference is true" do
    task = AgriculturalTask.new(
      name: "テストタスク",
      is_reference: true,
      user_id: nil
    )
    assert task.valid?
  end

  test "should not allow user for reference tasks" do
    user = create(:user)
    task = AgriculturalTask.new(
      name: "参照タスク",
      is_reference: true,
      user: user
    )
    task.valid?

    assert_includes task.errors[:user], "は参照データには設定できません"
  end

  test "reference scope should return only reference tasks" do
    create(:agricultural_task, is_reference: true, user_id: nil)
    user = create(:user)
    create(:agricultural_task, is_reference: false, user: user)
    
    assert_equal 1, AgriculturalTask.reference.count
  end

  test "user_owned scope should return only user owned tasks" do
    create(:agricultural_task, is_reference: true, user_id: nil)
    user = create(:user)
    user_task = create(:agricultural_task, is_reference: false, user: user)
    
    assert_equal 1, AgriculturalTask.user_owned.count
    assert_includes AgriculturalTask.user_owned, user_task
  end

  test "to_agrr_format should convert to agrr CLI format" do
    task = create(:agricultural_task,
      name: "土壌準備",
      description: "畑の土壌を耕す",
      time_per_sqm: 0.1,
      weather_dependency: "low",
      required_tools: ["トラクター", "耕運機"],
      skill_level: "beginner"
    )
    
    agrr_format = task.to_agrr_format
    
    assert_equal task.id.to_s, agrr_format['task_id']
    assert_equal "土壌準備", agrr_format['name']
    assert_equal "畑の土壌を耕す", agrr_format['description']
    assert_equal 0.1, agrr_format['time_per_sqm']
    assert_equal "low", agrr_format['weather_dependency']
    assert_equal ["トラクター", "耕運機"], agrr_format['required_tools']
    assert_equal "beginner", agrr_format['skill_level']
  end

  test "to_agrr_format should handle nil values" do
    task = create(:agricultural_task,
      name: "テストタスク",
      description: nil,
      time_per_sqm: nil,
      weather_dependency: nil,
      required_tools: [],
      skill_level: nil
    )
    
    agrr_format = task.to_agrr_format
    
    assert_equal task.id.to_s, agrr_format['task_id']
    assert_equal "テストタスク", agrr_format['name']
    assert_nil agrr_format['description']
    assert_nil agrr_format['time_per_sqm']
  end

  test "to_agrr_format_array should convert multiple tasks" do
    task1 = create(:agricultural_task, name: "タスク1")
    task2 = create(:agricultural_task, name: "タスク2")
    
    array = AgriculturalTask.to_agrr_format_array([task1, task2])
    
    assert_equal 2, array.length
    assert_equal task1.id.to_s, array[0]['task_id']
    assert_equal task2.id.to_s, array[1]['task_id']
  end

  # ========== name 一意性のテスト ==========
  
  test "should validate name uniqueness for reference tasks" do
    create(:agricultural_task, name: "土壌準備", is_reference: true)
    task = AgriculturalTask.new(name: "土壌準備", is_reference: true)
    task.valid?
    assert_includes task.errors[:name], "はすでに存在します"
  end

  test "should validate name uniqueness within same user for user-owned tasks" do
    user = create(:user)
    create(:agricultural_task, name: "カスタムタスク", is_reference: false, user: user)
    task = AgriculturalTask.new(name: "カスタムタスク", is_reference: false, user: user)
    task.valid?
    assert_includes task.errors[:name], "はすでに存在します"
  end

  test "should allow same name for different users" do
    user1 = create(:user)
    user2 = create(:user)
    create(:agricultural_task, name: "カスタムタスク", is_reference: false, user: user1)
    task = AgriculturalTask.new(name: "カスタムタスク", is_reference: false, user: user2)
    assert task.valid?
  end

  test "should allow updating with same name (exclude self)" do
    task = create(:agricultural_task, name: "土壌準備")
    task.name = "土壌準備"  # 同じ名前で更新
    assert task.valid?, "編集時は同じ名前で更新できる必要がある"
    assert task.save
  end

  # ========== required_tools シリアライズのテスト ==========
  
  test "should serialize required_tools as JSON array" do
    task = create(:agricultural_task, required_tools: ["トラクター", "耕運機"])
    
    assert_equal ["トラクター", "耕運機"], task.required_tools
    assert_kind_of Array, task.required_tools
  end

  test "should handle empty required_tools array" do
    task = create(:agricultural_task, required_tools: [])
    
    assert_equal [], task.required_tools
    assert_kind_of Array, task.required_tools
  end

  test "should handle nil required_tools and default to empty array" do
    task = AgriculturalTask.new(name: "テストタスク", required_tools: nil)
    assert_equal [], task.required_tools
  end

  # ========== user_id バリデーションのテスト ==========
  
  test "should allow user_id when is_reference is false" do
    user = create(:user)
    task = AgriculturalTask.new(
      name: "テストタスク",
      is_reference: false,
      user_id: user.id
    )
    assert task.valid?
  end

  test "should require user_id when is_reference changes from true to false" do
    task = create(:agricultural_task, is_reference: true, user_id: nil)
    
    task.is_reference = false
    assert_not task.valid?
    assert_includes task.errors[:user], "を入力してください"
    
    user = create(:user)
    task.user_id = user.id
    assert task.valid?
  end

  test "should enforce uniqueness of source_agricultural_task_id per user" do
    user = create(:user)
    reference = create(:agricultural_task, is_reference: true)

    create(:agricultural_task,
           is_reference: false,
           user: user,
           source_agricultural_task_id: reference.id)

    duplicated = build(:agricultural_task,
                       is_reference: false,
                       user: user,
                       source_agricultural_task_id: reference.id)
    assert_not duplicated.valid?
    assert_includes duplicated.errors[:source_agricultural_task_id], "はすでに存在します"

    another_user = create(:user)
    other = build(:agricultural_task,
                  is_reference: false,
                  user: another_user,
                  source_agricultural_task_id: reference.id)
    assert other.valid?
  end

  test "should belong to user" do
    user = create(:user)
    task = create(:agricultural_task, :user_owned, user: user)
    
    assert_equal user.id, task.user_id
    assert_equal user, task.user
  end

  test "should allow nil user for reference tasks" do
    task = create(:agricultural_task, is_reference: true, user_id: nil)
    
    assert_nil task.user_id
    assert_nil task.user
  end

  test "user should have many agricultural_tasks" do
    user = create(:user)
    task1 = create(:agricultural_task, :user_owned, user: user)
    task2 = create(:agricultural_task, :user_owned, user: user)
    
    assert_includes user.agricultural_tasks, task1
    assert_includes user.agricultural_tasks, task2
    assert_equal 2, user.agricultural_tasks.count
  end

  test "should filter agricultural_tasks by is_reference and user_id combination" do
    user1 = create(:user)
    user2 = create(:user)
    
    ref_task = create(:agricultural_task, is_reference: true, user_id: nil)
    user1_task = create(:agricultural_task, :user_owned, user: user1)
    user2_task = create(:agricultural_task, :user_owned, user: user2)
    
    # 一般ユーザーの視点（自身のタスクのみ）
    visible_tasks = AgriculturalTask.where(user_id: user1.id, is_reference: false)
    
    assert_includes visible_tasks, user1_task
    assert_not_includes visible_tasks, ref_task
    assert_not_includes visible_tasks, user2_task
    
    # 管理者の視点（参照タスクまたは自身のタスク）
    admin_user = create(:user, admin: true)
    admin_visible_tasks = AgriculturalTask.where("is_reference = ? OR user_id = ?", true, admin_user.id)
    
    assert_includes admin_visible_tasks, ref_task
  end

  # ========== スコープのテスト ==========
  
  test "recent scope should return tasks ordered by created_at desc" do
    task1 = create(:agricultural_task, name: "タスク1", created_at: 2.days.ago)
    task2 = create(:agricultural_task, name: "タスク2", created_at: 1.day.ago)
    task3 = create(:agricultural_task, name: "タスク3", created_at: Time.current)
    
    recent_tasks = AgriculturalTask.recent
    
    assert_equal task3.id, recent_tasks.first.id
    assert_equal task1.id, recent_tasks.last.id
  end

  # ========== is_reference バリデーションのテスト ==========
  
  test "should default is_reference to true" do
    task = AgriculturalTask.new(name: "テストタスク")
    assert task.is_reference?
  end

  test "should allow false for is_reference" do
    user = create(:user)
    task = AgriculturalTask.new(name: "テストタスク", is_reference: false, user: user)
    assert task.valid?
    assert_not task.is_reference?
  end

  # ========== time_per_sqm バリデーションのテスト ==========
  
  test "should validate time_per_sqm is greater than 0 when present" do
    task = build(:agricultural_task, time_per_sqm: 0)
    task.valid?
    assert_includes task.errors[:time_per_sqm], "は0より大きい値にしてください"
  end

  test "should allow 0.1 for time_per_sqm" do
    task = build(:agricultural_task, time_per_sqm: 0.1)
    assert task.valid?
  end

  # ========== required_tools の保存と読み込みテスト ==========
  
  test "should persist required_tools array correctly" do
    task = create(:agricultural_task, required_tools: ["トラクター", "耕運機", "肥料散布機"])
    
    reloaded_task = AgriculturalTask.find(task.id)
    assert_equal ["トラクター", "耕運機", "肥料散布機"], reloaded_task.required_tools
  end

  test "should handle complex required_tools data" do
    complex_tools = ["大型トラクター", "小型耕運機", "施肥機"]
    task = create(:agricultural_task, required_tools: complex_tools)
    
    reloaded_task = AgriculturalTask.find(task.id)
    assert_equal complex_tools, reloaded_task.required_tools
  end
end

