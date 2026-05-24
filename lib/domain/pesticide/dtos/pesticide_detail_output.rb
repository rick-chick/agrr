# frozen_string_literal: true

require "forwardable"

module Domain
  module Pesticide
    module Dtos
      # API / HTML 共通の詳細出力。HTML では crop / pest 名と nested スナップショットを同梱する。
      class PesticideDetailOutput
        extend Forwardable

        def_delegators :pesticide, :id, :user_id, :name, :active_ingredient, :description,
                       :is_reference, :created_at, :updated_at

        attr_reader :pesticide, :crop_name, :pest_name,
                    :usage_constraint_snapshot, :application_detail_snapshot

        def initialize(pesticide:, crop_name:, pest_name:,
                       usage_constraint_snapshot:, application_detail_snapshot:)
          @pesticide = pesticide
          @crop_name = crop_name
          @pest_name = pest_name
          @usage_constraint_snapshot = usage_constraint_snapshot
          @application_detail_snapshot = application_detail_snapshot
        end

        def crop
          @crop ||= Struct.new(:name).new(crop_name)
        end

        def pest
          @pest ||= Struct.new(:name).new(pest_name)
        end

        def pesticide_usage_constraint
          usage_constraint_snapshot
        end

        def pesticide_application_detail
          application_detail_snapshot
        end
      end
    end
  end
end
