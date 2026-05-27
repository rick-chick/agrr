# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Sessions
      # template-copy 境界: establish_master_data_relationships へ渡す AR（domain User gateway IF 経由ではない）。
      module PlanSaveTemplateCopyIntegrity
        module_function

        # @param ids [Array<Integer>]
        # @param user_id [Integer]
        # @return [Array<Field>]
        def field_records_for_template_copy(ids:, user_id:)
          normalized_ids = Array(ids).map(&:to_i)
          return [] if normalized_ids.empty?

          uid = user_id.to_i
          records = ::Field.where(id: normalized_ids, user_id: uid).to_a
          by_id = records.index_by(&:id)

          normalized_ids.map do |id|
            record = by_id[id]
            unless record&.persisted?
              raise "Field record not found or not persisted: #{id}"
            end

            record
          end
        end

        # @param ids [Array<Integer>]
        # @return [Array<Crop>]
        def crop_records_for_template_copy(ids:)
          load_persisted_records(::Crop, "Crop", ids: ids)
        end

        # @param ids [Array<Integer>]
        # @return [Array<Pest>]
        def pest_records_for_template_copy(ids:)
          load_persisted_records(::Pest, "Pest", ids: ids)
        end

        # @param ids [Array<Integer>]
        # @return [Array<Fertilize>]
        def fertilize_records_for_template_copy(ids:)
          load_persisted_records(::Fertilize, "Fertilize", ids: ids)
        end

        # @param model_class [Class]
        # @param label [String]
        # @param ids [Array<Integer>]
        # @return [Array<Object>]
        # @raise [RuntimeError]
        def load_persisted_records(model_class, label, ids:)
          normalized_ids = Array(ids).map(&:to_i)
          return [] if normalized_ids.empty?

          records = model_class.where(id: normalized_ids).to_a
          by_id = records.index_by(&:id)

          normalized_ids.map do |id|
            record = by_id[id]
            unless record&.persisted?
              raise "#{label} record not found or not persisted: #{id}"
            end

            record
          end
        end
        private_class_method :load_persisted_records
      end
    end
  end
end
