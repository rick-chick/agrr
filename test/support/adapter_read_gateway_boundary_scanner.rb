# frozen_string_literal: true

# Read 系 adapter gateway が domain mapper の組立オーケストレーションを呼ばないことを検査する。
# ARCHITECTURE.md — Read snapshot assembly: Interactor + domain mapper、adapter は narrow I/O のみ。
module AdapterReadGatewayBoundaryScanner
  ADAPTER_GATEWAYS_ROOT = Pathname.new(__dir__).join("..", "..", "app", "adapters").expand_path

  # adapter 内から domain mapper の複数 gateway 呼び出し・snapshot 組立を禁止
  DOMAIN_MAPPER_ORCHESTRATION = /
    Domain::[A-Za-z0-9:]+::Mappers::[A-Za-z0-9:]+
    \.
    (?:load_snapshot|load_plan_rows|from_snapshots|assemble)
    \s*\(
  /x.freeze

  READ_GATEWAY_GLOB = "**/gateways/*read*_gateway.rb"

  module_function

  # @return [Array<String>]
  def violations
    found = []

    ADAPTER_GATEWAYS_ROOT.glob(READ_GATEWAY_GLOB).sort.each do |path|
      scan_file(path, found)
    end

    found
  end

  def scan_file(path, found = [])
    rel = path.relative_path_from(ADAPTER_GATEWAYS_ROOT.parent.parent).to_s

    LibDomainActiveRecordReferenceScanner.executable_source(path).each_with_index do |line, index|
      next unless line.match?(DOMAIN_MAPPER_ORCHESTRATION)

      snippet = line.strip[0, 140]
      found << "#{rel}:#{index + 1}: domain mapper orchestration in adapter read gateway: `#{snippet}`"
    end

    found
  end
end
