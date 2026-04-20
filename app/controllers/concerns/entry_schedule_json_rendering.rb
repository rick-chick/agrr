# frozen_string_literal: true

require "digest"

# ETag 付き JSON 応答（エントリ作物スケジュール API 共通）
module EntryScheduleJsonRendering
  extend ActiveSupport::Concern

  private

  def render_entry_json_with_etag(payload)
    json_str = ActiveSupport::JSON.encode(payload)
    etag = Digest::SHA256.hexdigest(json_str)
    quoted = %("#{etag}")
    if request.headers["If-None-Match"].present?
      client = request.headers["If-None-Match"].strip
      return head :not_modified if client == quoted || client == etag
    end

    response.headers["ETag"] = quoted
    render json: payload
  end
end
