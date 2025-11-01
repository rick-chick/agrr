# frozen_string_literal: true

require "test_helper"

module Adapters
  module Fertilize
    module Gateways
      class FertilizeMemoryGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = FertilizeMemoryGateway.new
        end

        test "should find fertilize by id" do
          fertilize = create(:fertilize, name: "尿素")
          
          entity = @gateway.find_by_id(fertilize.id)
          
          assert_not_nil entity
          assert_equal fertilize.id, entity.id
          assert_equal "尿素", entity.name
          assert_equal 20.0, entity.n
        end

        test "should return nil when fertilize not found" do
          entity = @gateway.find_by_id(9999)
          
          assert_nil entity
        end

        test "should create fertilize from data" do
          fertilize_data = {
            'name' => '尿素',
            'n' => 46.0,
            'p' => nil,
            'k' => nil,
            'description' => '窒素肥料として広く使用される',
            'usage' => '基肥・追肥に使用可能',
            'application_rate' => '1㎡あたり10-30g',
            'package_size' => '25kg'
          }

          entity = @gateway.create(fertilize_data)

          assert_not_nil entity
          assert_equal '尿素', entity.name
          assert_equal 46.0, entity.n
          assert_nil entity.p
          assert_nil entity.k
          assert_equal '25kg', entity.package_size
          assert entity.reference?
          
          # Verify it was saved to database
          record = ::Fertilize.find_by(name: '尿素')
          assert_not_nil record
          assert_equal '25kg', record.package_size
        end

        test "should create fertilize with nil package_size" do
          fertilize_data = {
            'name' => '尿素',
            'n' => 46.0,
            'p' => nil,
            'k' => nil,
            'description' => '窒素肥料として広く使用される',
            'usage' => '基肥・追肥に使用可能',
            'application_rate' => '1㎡あたり10-30g',
            'package_size' => nil
          }

          entity = @gateway.create(fertilize_data)

          assert_not_nil entity
          assert_nil entity.package_size
          
          record = ::Fertilize.find_by(name: '尿素')
          assert_nil record.package_size
        end

        test "should raise error when create fails validation" do
          fertilize_data = {
            'name' => '',
            'n' => 46.0
          }

          assert_raises(StandardError) do
            @gateway.create(fertilize_data)
          end
        end

        test "should update fertilize" do
          fertilize = create(:fertilize, name: "尿素", n: 46.0)
          
          update_data = {
            :name => "尿素（粒状）",
            :description => "粒状の尿素肥料"
          }

          entity = @gateway.update(fertilize.id, update_data)

          assert_equal "尿素（粒状）", entity.name
          assert_equal "粒状の尿素肥料", entity.description
          assert_equal 46.0, entity.n  # unchanged
        end

        test "should update fertilize package_size" do
          fertilize = create(:fertilize, name: "尿素", n: 46.0, package_size: "20kg")
          
          update_data = {
            :package_size => "25kg"
          }

          entity = @gateway.update(fertilize.id, update_data)

          assert_equal "25kg", entity.package_size
          assert_equal "尿素", entity.name  # unchanged
          assert_equal 46.0, entity.n  # unchanged
        end

        test "should only update provided attributes" do
          fertilize = create(:fertilize, name: "尿素", n: 46.0, p: nil)
          
          update_data = {
            :n => 50.0
          }

          entity = @gateway.update(fertilize.id, update_data)

          assert_equal "尿素", entity.name  # unchanged
          assert_equal 50.0, entity.n
          assert_nil entity.p
        end

        test "should find all reference fertilizes" do
          create(:fertilize, name: "尿素1", is_reference: true)
          create(:fertilize, name: "尿素2", is_reference: true)
          create(:fertilize, name: "尿素3", is_reference: false)
          
          entities = @gateway.find_all_reference
          
          assert_equal 2, entities.length
          assert entities.all? { |e| e.reference? }
        end

        test "should delete fertilize" do
          fertilize = create(:fertilize, name: "尿素")
          
          result = @gateway.delete(fertilize.id)
          
          assert result
          assert_nil ::Fertilize.find_by(id: fertilize.id)
        end

        test "should return false when delete fails with RecordNotFound" do
          result = @gateway.delete(9999)
          
          assert_not result
        end

        test "should check existence" do
          fertilize = create(:fertilize, name: "尿素")
          
          assert @gateway.exists?(fertilize.id)
          assert_not @gateway.exists?(9999)
        end
      end
    end
  end
end

