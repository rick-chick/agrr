# frozen_string_literal: true

class ApiDocsController < ApplicationController
  # GET /api/docs
  def index
    # OpenAPI仕様ファイルを読み込んでJSONに変換
    openapi_spec = YAML.load_file(Rails.root.join("config", "openapi.yml"))
    @openapi_spec = openapi_spec.to_json
  end
end
