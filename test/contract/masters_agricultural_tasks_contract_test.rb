# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersAgriculturalTasksContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
  end

  test "should get index" do
    create(:agricultural_task, :user_owned, user: @user, name: "Contract Task")

    if rust_contract?
      response = rust_get("/api/v1/masters/agricultural_tasks", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/agricultural_tasks", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert json.is_a?(Array)
    assert json.any? { |t| t["name"] == "Contract Task" }
  end

  test "should show agricultural_task" do
    task = create(:agricultural_task, :user_owned, user: @user, name: "Show Task")

    if rust_contract?
      response = rust_get("/api/v1/masters/agricultural_tasks/#{task.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/agricultural_tasks/#{task.id}", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal task.id, json["id"]
    assert_equal "Show Task", json["name"]
  end

  test "should create agricultural_task" do
    if rust_contract?
      response = rust_post(
        "/api/v1/masters/agricultural_tasks",
        session_id: @session_id,
        body: { agricultural_task: { name: "Created Task" } }
      )
      assert_equal 201, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      post "/api/v1/masters/agricultural_tasks",
           params: { agricultural_task: { name: "Created Task" } },
           headers: { "Accept" => "application/json" }
      assert_response :created
      json = JSON.parse(response.body)
    end

    assert_equal "Created Task", json["name"]
    assert json["id"].present?
  end

  test "should update agricultural_task" do
    task = create(:agricultural_task, :user_owned, user: @user, name: "Before")

    if rust_contract?
      response = rust_patch(
        "/api/v1/masters/agricultural_tasks/#{task.id}",
        session_id: @session_id,
        body: { agricultural_task: { name: "After" } }
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      patch "/api/v1/masters/agricultural_tasks/#{task.id}",
            params: { agricultural_task: { name: "After" } },
            headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal "After", json["name"]
  end

  test "should destroy agricultural_task" do
    task = create(:agricultural_task, :user_owned, user: @user, name: "Delete Task")

    if rust_contract?
      response = rust_delete("/api/v1/masters/agricultural_tasks/#{task.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
    else
      sign_in_as @user
      delete "/api/v1/masters/agricultural_tasks/#{task.id}",
             headers: { "Accept" => "application/json" }
      assert_response :success
    end

    assert_nil AgriculturalTask.find_by(id: task.id)
  end
end
