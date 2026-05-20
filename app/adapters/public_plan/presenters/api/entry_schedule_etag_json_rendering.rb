# frozen_string_literal: true

require "digest"

module Adapters
  module PublicPlan
    module Presenters
      module Api
        # ETag 付き JSON（entry_schedule の成功応答のみ）。HTTP 形状は Presenter 側に閉じる。
        module EntryScheduleEtagJsonRendering
          private

          def render_entry_schedule_etag_json(payload)
            json_str = ActiveSupport::JSON.encode(payload)
            etag = Digest::SHA256.hexdigest(json_str)
            quoted = %("#{etag}")
            if @view.request.headers["If-None-Match"].present?
              client = @view.request.headers["If-None-Match"].strip
              return @view.head :not_modified if client == quoted || client == etag
            end

            @view.response.headers["ETag"] = quoted
            @view.render json: payload
          end
        end
      end
    end
  end
end
