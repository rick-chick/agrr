# frozen_string_literal: true

require "test_helper"

class ApplicationFormTest < ActiveSupport::TestCase
  class SampleForm < Adapters::Shared::Forms::ApplicationForm
    attribute :name, :string
    attribute :amount, :integer
  end

  test "from_params builds form with attributes" do
    form = SampleForm.from_params({ name: "Hello", amount: "5" })
    assert_equal "Hello", form.name
    assert_equal 5, form.amount
    assert_nil form.id
    refute form.persisted?
    assert form.new_record?
    assert_nil form.to_param
    assert_nil form.to_key
  end

  test "from_entity builds form from entity-like object" do
    entity = Struct.new(:id, :name, :amount, keyword_init: true).new(id: 7, name: "X", amount: 9)
    form = SampleForm.from_entity(entity)
    assert_equal 7, form.id
    assert_equal "X", form.name
    assert_equal 9, form.amount
    assert form.persisted?
    assert_equal "7", form.to_param
    assert_equal [ 7 ], form.to_key
  end

  test "errors_from accepts hash, array, string" do
    form = SampleForm.new
    form.errors_from(name: [ "は必須です" ])
    assert_includes form.errors[:name], "は必須です"

    form2 = SampleForm.new
    form2.errors_from([ "何かが失敗" ])
    assert_includes form2.errors[:base], "何かが失敗"

    form3 = SampleForm.new
    form3.errors_from("単一エラー")
    assert_includes form3.errors[:base], "単一エラー"
  end

  test "model_name returns ActiveModel::Name with inferred resource name" do
    assert_equal "sample", SampleForm.resource_name
    assert_kind_of ActiveModel::Name, SampleForm.model_name
    assert_equal "Sample", SampleForm.model_name.name
  end
end
