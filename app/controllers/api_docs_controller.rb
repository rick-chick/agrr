# frozen_string_literal: true

class ApiDocsController < ApplicationController
  # APIリファレンスは認証不要で公開
  skip_before_action :authenticate_user!

  # GET /api/docs
  def index
    # OpenAPI仕様ファイルを読み込んでJSONに変換
    openapi_spec = YAML.load_file(Rails.root.join('config', 'openapi.yml'))
    @openapi_spec = openapi_spec.to_json
  end
end
