# frozen_string_literal: true

# テスト用ロガー: 送出行を entries に蓄積する（Logger DI の検証・Rails.logger 非依存）。
# 本ファイルは `.yardopts` に明示されている（YARD が lib のコメントと突き合わせ可能）。
class CapturingLogger
  include Domain::Shared::Ports::LoggerPort
  attr_reader :entries

  def initialize
    @entries = []
  end

  def debug(message, progname = nil)
    @entries << [ :debug, message ]
  end

  def info(message, progname = nil)
    @entries << [ :info, message ]
  end

  def warn(message, progname = nil)
    @entries << [ :warn, message ]
  end

  def error(message, progname = nil)
    @entries << [ :error, message ]
  end

  def fatal(message, progname = nil)
    @entries << [ :fatal, message ]
  end

  def unknown(message, progname = nil)
    @entries << [ :unknown, message ]
  end
end
