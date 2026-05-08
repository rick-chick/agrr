# frozen_string_literal: true

module Api
  module V1
    class FilesController < BaseController
      before_action :authenticate_user!

      def index
        presenter = Presenters::Api::Files::FileBlobJsonPresenter.new(view: self, translator: CompositionRoot.translator)
        Domain::FileBlob::Interactors::FileBlobListInteractor.new(
          output_port: presenter,
          gateway: CompositionRoot.file_blob_gateway
        ).call
      end

      def show
        presenter = Presenters::Api::Files::FileBlobJsonPresenter.new(view: self, translator: CompositionRoot.translator)
        Domain::FileBlob::Interactors::FileBlobShowInteractor.new(
          output_port: presenter,
          gateway: CompositionRoot.file_blob_gateway
        ).call(blob_id: params[:id])
      end

      def create
        presenter = Presenters::Api::Files::FileBlobJsonPresenter.new(view: self, translator: CompositionRoot.translator)
        Domain::FileBlob::Interactors::FileBlobCreateInteractor.new(
          output_port: presenter,
          gateway: CompositionRoot.file_blob_gateway
        ).call(
          io: params[:file],
          filename: params[:file]&.original_filename,
          content_type: params[:file]&.content_type
        )
      end

      def destroy
        presenter = Presenters::Api::Files::FileBlobJsonPresenter.new(view: self, translator: CompositionRoot.translator)
        Domain::FileBlob::Interactors::FileBlobDestroyInteractor.new(
          output_port: presenter,
          gateway: CompositionRoot.file_blob_gateway
        ).call(blob_id: params[:id])
      end
    end
  end
end
