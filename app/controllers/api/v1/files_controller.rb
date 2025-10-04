# frozen_string_literal: true

module Api
  module V1
    class FilesController < BaseController
      before_action :set_file, only: [:show, :destroy]

      # GET /api/v1/files
      def index
        @files = ActiveStorage::Blob.all.order(created_at: :desc)
        render json: @files.map { |file| file_attributes(file) }
      end

      # GET /api/v1/files/:id
      def show
        render json: file_attributes(@file)
      end

      # POST /api/v1/files
      def create
        if params[:file].present?
          blob = ActiveStorage::Blob.create_and_upload!(
            io: params[:file],
            filename: params[:file].original_filename,
            content_type: params[:file].content_type
          )
          
          render json: file_attributes(blob), status: :created
        else
          render json: { error: 'No file provided' }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/files/:id
      def destroy
        @file.purge
        head :no_content
      end

      private

      def set_file
        @file = ActiveStorage::Blob.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'File not found' }, status: :not_found
      end

      def file_attributes(blob)
        {
          id: blob.id,
          filename: blob.filename.to_s,
          content_type: blob.content_type,
          byte_size: blob.byte_size,
          created_at: blob.created_at,
          url: Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: false)
        }
      end
    end
  end
end
