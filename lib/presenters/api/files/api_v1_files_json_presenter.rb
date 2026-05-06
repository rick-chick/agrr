# frozen_string_literal: true

module Presenters
  module Api
    module Files
      class ApiV1FilesJsonPresenter
        def initialize(view:, translator:)
          @view = view
          @translator = translator
        end

        def on_list_success(rows:)
          @view.render json: rows
        end

        def on_show_success(row:)
          @view.render json: row
        end

        def on_created(row:)
          @view.render json: row, status: :created
        end

        def on_deleted
          @view.head :no_content
        end

        def on_not_found
          @view.render json: { error: @translator.t("api.errors.common.files.not_found") }, status: :not_found
        end

        def on_missing_file
          @view.render json: { error: @translator.t("api.errors.common.files.no_file") }, status: :unprocessable_entity
        end
      end
    end
  end
end
