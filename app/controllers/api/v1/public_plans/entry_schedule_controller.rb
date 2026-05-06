# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      # 作物スケジュール（エントリ）— 参照農場・参照作物・予測気象に基づく植え/まき帯
      class EntryScheduleController < ApplicationController
        skip_before_action :authenticate_user!
        skip_before_action :verify_authenticity_token

        before_action :apply_entry_locale

        # GET .../public_plans/entry_schedule/farms
        def farms
          region = params[:region].presence || locale_to_region(I18n.locale)
          presenter = Presenters::Api::PublicPlans::ReferenceFarmsPresenter.new(view: self)
          Domain::Farm::Interactors::FarmListReferenceForRegionInteractor.new(output_port: presenter, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger).call(region)
        end

        # GET .../public_plans/entry_schedule/crops?farm_id=&prediction_end_date=&limit=&cursor=
        def crops
          resolve_entry_schedule_reference_farm!
          return if performed?

          farm = @entry_schedule_reference_farm
          limit = parse_entry_limit
          offset = decode_entry_cursor(params[:cursor])
          CompositionRoot.entry_schedule_crops_index_interactor(
            output_port: Presenters::Api::PublicPlans::EntryScheduleCropsIndexPresenter.new(view: self)
          ).call(
            farm: farm,
            prediction_end_date_raw: params[:prediction_end_date].presence,
            limit: limit,
            offset: offset,
            reference_date: Date.current
          )
        end

        # GET .../public_plans/entry_schedule/crops/:id?farm_id=
        def show
          resolve_entry_schedule_reference_farm!
          return if performed?

          farm = @entry_schedule_reference_farm
          presenter = Presenters::Api::PublicPlans::EntryScheduleReferenceCropPresenter.new(view: self)
          Domain::Crop::Interactors::CropFindReferenceForEntryScheduleInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger).call(farm.region, params[:id])
          return if performed?

          crop = @reference_crop
          reference_date = Date.current
          presenter = Presenters::Api::PublicPlans::EntryScheduleShowPresenter.new(view: self)
          CompositionRoot.entry_schedule_show_interactor(output_port: presenter, clock: Time.zone).call(
            farm: farm,
            crop: crop,
            reference_date: reference_date,
            prediction_end_date_raw: params[:prediction_end_date].presence
          )
        end

        private

        def resolve_entry_schedule_reference_farm!
          CompositionRoot.entry_schedule_resolve_reference_farm_interactor(
            output_port: Presenters::Api::PublicPlans::EntryScheduleResolveReferenceFarmPresenter.new(view: self)
          ).call(params[:farm_id])
        end

        def parse_entry_limit
          raw = params[:limit]
          return 20 if raw.blank?

          [ [ raw.to_i, 1 ].max, 50 ].min
        end

        def decode_entry_cursor(raw)
          CompositionRoot.entry_schedule_cursor_decode_gateway.decode(raw)
        end

        def apply_entry_locale
          loc = params[:locale].presence
          loc ||= extract_locale_from_accept_language_header if respond_to?(:extract_locale_from_accept_language_header, true)
          loc = I18n.default_locale if loc.blank?
          loc = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(loc.to_s)
          I18n.locale = loc.to_sym
        end

        def locale_to_region(locale)
          case locale.to_s
          when "ja" then "jp"
          when "us" then "us"
          when "in" then "in"
          else "jp"
          end
        end
      end
    end
  end
end
