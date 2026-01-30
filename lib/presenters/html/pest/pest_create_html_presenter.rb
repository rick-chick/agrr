# frozen_string_literal: true

module Presenters
  module Html
    module Pest
      class PestCreateHtmlPresenter < Domain::Pest::Ports::PestCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pest_entity)
          # crop association は Interactor 内で実施済み
          @view.redirect_to(
            @view.pest_path(pest_entity.id),
            notice: I18n.t('pests.flash.created')
          )
        end

        def on_failure(error_dto)
          ref_msg = I18n.t('pests.flash.reference_only_admin')
          if error_dto.message.to_s == ref_msg || error_dto.message.to_s.include?(ref_msg.to_s)
            @view.redirect_to @view.pests_path, alert: ref_msg
            return
          end
          @view.flash.now[:alert] = error_dto.message
          # 失敗時はフォームを再表示するために @pest を再構築
          permitted = [
            :name,
            :name_scientific,
            :family,
            :order,
            :description,
            :occurrence_season,
            :is_reference,
            pest_temperature_profile_attributes: [
              :id,
              :base_temperature,
              :max_temperature,
              :_destroy
            ],
            pest_thermal_requirement_attributes: [
              :id,
              :required_gdd,
              :first_generation_gdd,
              :_destroy
            ],
            pest_control_methods_attributes: [
              :id,
              :method_type,
              :method_name,
              :description,
              :timing_hint,
              :_destroy
            ]
          ]
          # 管理者のみregionを許可（Interactorでチェック済みなので常に許可）
          permitted << :region
          pest = ::Pest.new(@view.params[:pest].permit(*permitted))
          @view.instance_variable_set(:@pest, pest)
          crop_ids = @view.params[:crop_ids] ? @view.normalize_crop_ids_for(pest, @view.params[:crop_ids]) : []
          @view.prepare_crop_selection_for(pest, selected_ids: crop_ids)
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end