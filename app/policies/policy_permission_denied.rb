# frozen_string_literal: true

# Policy レイヤで「レコードは存在するが権限がない」ことを表す例外。
# コントローラ側で ActiveRecord::RecordNotFound と区別して扱う。
class PolicyPermissionDenied < StandardError; end

