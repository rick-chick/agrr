# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # HTML マスタ画面の表示制御（認可結果の boolean のみ。I/O なし）。
      class ResourceDisplayCapabilities
        attr_reader :show_reference_badge,
                    :show_edit_button,
                    :show_delete_button,
                    :show_reference_form_fields,
                    :show_remove_crop_stage_button,
                    :show_add_crop_stage_button,
                    :show_generate_task_schedule_blueprints_button,
                    :show_delete_task_schedule_blueprint_button,
                    :show_admin_list_filters,
                    :show_reference_rules_section,
                    :show_my_rules_section_header

        def initialize(
          show_reference_badge: false,
          show_edit_button: false,
          show_delete_button: false,
          show_reference_form_fields: false,
          show_remove_crop_stage_button: false,
          show_add_crop_stage_button: false,
          show_generate_task_schedule_blueprints_button: false,
          show_delete_task_schedule_blueprint_button: false,
          show_admin_list_filters: false,
          show_reference_rules_section: false,
          show_my_rules_section_header: false
        )
          @show_reference_badge = show_reference_badge
          @show_edit_button = show_edit_button
          @show_delete_button = show_delete_button
          @show_reference_form_fields = show_reference_form_fields
          @show_remove_crop_stage_button = show_remove_crop_stage_button
          @show_add_crop_stage_button = show_add_crop_stage_button
          @show_generate_task_schedule_blueprints_button = show_generate_task_schedule_blueprints_button
          @show_delete_task_schedule_blueprint_button = show_delete_task_schedule_blueprint_button
          @show_admin_list_filters = show_admin_list_filters
          @show_reference_rules_section = show_reference_rules_section
          @show_my_rules_section_header = show_my_rules_section_header
        end

        def self.for_detail_record(user, record)
          is_reference = record.respond_to?(:reference?) ? record.reference? : !!record.is_reference
          for_list_row(user, is_reference: is_reference, user_id: record.user_id)
        end

        def self.for_list_row(user, is_reference:, user_id:)
          policy = Domain::Shared::Policies::ReferencableResourcePolicy
          edit = policy.show_edit_actions?(user, is_reference: is_reference, user_id: user_id)
          new(
            show_reference_badge: policy.show_reference_badge?(user, is_reference: is_reference),
            show_edit_button: edit,
            show_delete_button: edit
          )
        end

        def self.for_referencable_form(user, crop_is_reference: false, crop_user_id: nil)
          policy = Domain::Shared::Policies::ReferencableResourcePolicy
          new(
            show_reference_form_fields: policy.show_reference_form_fields?(user),
            show_remove_crop_stage_button: policy.show_crop_stage_remove_button?(
              user, crop_is_reference: crop_is_reference, crop_user_id: crop_user_id
            ),
            show_add_crop_stage_button: policy.show_add_crop_stage_button?(
              user, crop_is_reference: crop_is_reference, crop_user_id: crop_user_id
            )
          )
        end

        def self.for_crop_detail(user, crop:)
          policy = Domain::Shared::Policies::ReferencableResourcePolicy
          is_reference = crop.respond_to?(:reference?) ? crop.reference? : !!crop.is_reference
          user_id = crop.user_id
          edit = policy.show_edit_actions?(user, is_reference: is_reference, user_id: user_id)
          new(
            show_reference_badge: policy.show_reference_badge?(user, is_reference: is_reference),
            show_edit_button: edit,
            show_delete_button: edit,
            show_generate_task_schedule_blueprints_button: policy.show_generate_task_schedule_blueprints_button?(
              user, crop_is_reference: is_reference, crop_user_id: user_id
            ),
            show_delete_task_schedule_blueprint_button: policy.show_delete_task_schedule_blueprint_button?(
              user, crop_is_reference: is_reference, crop_user_id: user_id
            )
          )
        end

        def self.for_agricultural_task_list(user)
          new(show_admin_list_filters: Domain::Shared::Policies::ReferencableResourcePolicy.show_admin_list_filters?(user))
        end

        def self.for_interaction_rule_index(user, reference_rules_any:)
          policy = Domain::Shared::Policies::ReferencableResourcePolicy
          new(
            show_reference_rules_section: policy.show_reference_rules_section?(
              user, reference_rules_any: reference_rules_any
            ),
            show_my_rules_section_header: policy.show_my_rules_section_header?(
              user, reference_rules_any: reference_rules_any
            )
          )
        end
      end
    end
  end
end
