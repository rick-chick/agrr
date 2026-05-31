#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists Ruby test cases that form the masters CRUD parity closure (R1 / GW / R4).
# Usage: ruby scripts/list-masters-parity-sources.rb > docs/migration/lib-domain-rust/MASTERS-PARITY-MATRIX.md

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

R1_GLOBS = [
  "test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb",
  "test/domain/fertilize/interactors/fertilize_{create,list,detail,update,destroy}_interactor_test.rb",
  "test/domain/pest/interactors/pest_{create,list,detail,update,destroy}_interactor_test.rb",
  "test/domain/pest/interactors/masters_crop_pests_{create,destroy,index}_interactor_test.rb",
  "test/domain/pesticide/interactors/pesticide_{create,list,detail,update,destroy}_interactor_test.rb",
  "test/domain/agricultural_task/interactors/agricultural_task_{create,list,detail,update,destroy}_interactor_test.rb",
  "test/domain/crop/interactors/crop_{create,list,detail,update,destroy}_interactor_test.rb",
  "test/domain/crop/interactors/crop_stage_{create,list,detail,update,delete}_interactor_test.rb",
  "test/domain/crop/interactors/crop_load_masters_authorized_crop_stage_interactor_test.rb",
  "test/domain/crop/interactors/crop_load_user_non_reference_for_masters_interactor_test.rb",
  "test/domain/crop/interactors/crop_masters_task_template_{create,index,update,destroy}_interactor_test.rb",
  "test/domain/crop/interactors/masters_{temperature,thermal,sunshine,nutrient}_requirement_api_interactors_test.rb",
  "test/domain/pesticide/interactors/masters_crop_pesticides_index_interactor_test.rb",
  "test/domain/farm/interactors/farm_{create,list,detail,update,destroy}_interactor_test.rb",
  "test/domain/field/interactors/field_{list,detail,update,destroy}_interactor_test.rb",
  "test/domain/interaction_rule/interactors/interaction_rule_{create,list,detail,update,destroy}_interactor_test.rb",
  "test/domain/shared/policies/{referencable_resource,fertilize,pest,pesticide,crop,agricultural_task,farm,interaction_rule}_policy_test.rb",
  "test/domain/crop/policies/crop_{create_limit,destroy,masters_crop_task_template_create,crop_masters_crop_edit_access}_policy_test.rb",
  "test/domain/farm/policies/farm_{create_limit,destroy,reference_ownership}_policy_test.rb",
  "test/domain/pest/policies/pest_destroy_policy_test.rb",
  "test/domain/field/policies/field_{access,create_attributes}_policy_test.rb",
].freeze

GW_GLOBS = [
  "test/adapters/fertilize/gateways/fertilize_active_record_gateway_test.rb",
  "test/adapters/pest/gateways/pest_active_record_gateway_list_index_test.rb",
  "test/adapters/pest/gateways/crop_pest_active_record_gateway_test.rb",
  "test/adapters/pesticide/gateways/pesticide_active_record_gateway_test.rb",
  "test/adapters/crop/gateways/crop_active_record_gateway_test.rb",
  "test/adapters/crop/gateways/crop_stage_active_record_gateway_test.rb",
  "test/adapters/farm/gateways/farm_active_record_gateway_test.rb",
  "test/adapters/field/gateways/field_active_record_gateway_test.rb",
  "test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb",
  "test/adapters/agricultural_task/gateways/crop_task_template_active_record_gateway_test.rb",
].freeze

R4_CONTROLLER_GLOB = "test/controllers/api/v1/masters/**/*.rb"
R4_CONTRACT_GLOB = "test/contract/masters_*.rb"

TEST_LINE = /^\s+test\s+["'](.+?)["']/

def expand_glob(pattern)
  full = ROOT.join(pattern)
  if pattern.include?("{")
    # brace expansion
    m = pattern.match(/\A(.+)\{([^}]+)\}(.+)\z/)
    prefix, alts, suffix = m[1], m[2], m[3]
    alts.split(",").flat_map { |alt| expand_glob("#{prefix}#{alt}#{suffix}") }
  else
    Pathname.glob(full).map(&:to_s).sort
  end
end

def master_from_path(path, layer)
  case path
  when %r{test/domain/fertilize} then "fertilize"
  when %r{test/domain/pest/} then path.include?("masters_crop") ? "crop_pests" : "pest"
  when %r{test/domain/pesticide} then path.include?("masters_crop") ? "crop_pesticides" : "pesticide"
  when %r{test/domain/agricultural_task} then "agricultural_task"
  when %r{test/domain/crop} then path.include?("requirement") ? "crop_requirements" : "crop"
  when %r{test/domain/farm} then "farm"
  when %r{test/domain/field} then "field"
  when %r{test/domain/interaction_rule} then "interaction_rule"
  when %r{test/adapters/fertilize} then "fertilize"
  when %r{test/adapters/pest} then path.include?("crop_pest") ? "crop_pests" : "pest"
  when %r{test/adapters/pesticide} then "pesticide"
  when %r{test/adapters/crop} then path.include?("crop_stage") ? "crop_stages" : "crop"
  when %r{test/adapters/farm} then "farm"
  when %r{test/adapters/field} then "field"
  when %r{test/adapters/interaction_rule} then "interaction_rule"
  when %r{test/adapters/agricultural_task} then "crop_ag_templates"
  when %r{test/controllers/api/v1/masters} then infer_controller_master(path)
  when %r{test/contract/masters} then "contract"
  when %r{shared} then "shared"
  else "unknown"
  end
end

def infer_controller_master(path)
  return "auth" if path.include?("base_controller")
  return "crop_stages" if path.include?("crop_stages_controller")
  return "crop_pests" if path.include?("/pests_controller")
  return "crop_ag_tasks" if path.include?("agricultural_tasks_controller")
  return "crop_pesticides" if path.include?("/pesticides_controller")
  return "requirements" if path.include?("_requirements_controller")

  base = File.basename(path, "_controller_test.rb")
  base.delete_suffix("_test")
end

def r1_rust_path(ruby_rel)
  return nil unless ruby_rel.start_with?("test/domain/")

  s = ruby_rel.delete_prefix("test/domain/").sub(/\.rb$/, "")
  dir = File.dirname(s)
  base = File.basename(s)
  parent = dir.split("/").last
  "crates/agrr-domain/test/#{dir}/#{parent}_#{base}.rs"
end

def gw_rust_path(ruby_rel)
  return nil unless ruby_rel.include?("/gateways/")

  if ruby_rel.include?("crop_stage")
    "crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs"
  elsif ruby_rel.include?("crop_pest")
    "crates/agrr-adapters-sqlite/src/pest/crop_pest_gateway_test.rs"
  elsif ruby_rel.include?("crop_task_template")
    "crates/agrr-adapters-sqlite/src/crop/crop_masters_task_template_gateway.rs"
  else
    master = ruby_rel[%r{test/adapters/([^/]+)/}, 1]
    "crates/agrr-adapters-sqlite/src/#{master}/#{master}_gateway_test.rs"
  end
end

def rust_test_line?(rust_rel, ruby_test)
  path = ROOT.join(rust_rel)
  return false unless path.file?

  slug = ruby_test.gsub(/[^\p{Alnum}]+/, "_").downcase.squeeze("_")
  path.read.include?("fn ") && (
    path.read.downcase.include?(slug[0, 40]) ||
    path.read.include?("// Ruby:") ||
    path.read.include?("Ruby parity")
  )
end

def contract_test_exists?(ruby_test)
  Pathname.glob(ROOT.join("test/contract/masters_*.rb")).any? do |f|
    f.read.include?(%(test "#{ruby_test}"))
  end
end

def enrich_row!(row)
  case row[:layer]
  when "R1"
    rp = r1_rust_path(row[:ruby_path])
    if rp && ROOT.join(rp).file?
      row[:rust_path] = rp
      row[:status] = rust_test_line?(rp, row[:ruby_test]) ? "added" : "partial"
    end
  when "GW"
    rp = gw_rust_path(row[:ruby_path])
    if rp && ROOT.join(rp).file?
      row[:rust_path] = rp
      row[:status] = "added"
    end
  when "R4"
    if row[:source] == "contract"
      row[:rust_path] = "agrr-server (contract)"
      row[:status] = "added"
    elsif contract_test_exists?(row[:ruby_test])
      row[:rust_path] = "test/contract/masters_*"
      row[:status] = "added"
    end
  end
end

def extract_tests(path, layer, source: "ar")
  rel = Pathname.new(path).relative_path_from(ROOT).to_s
  lines = File.readlines(path, chomp: true)
  rows = []
  lines.each do |line|
    next unless (m = line.match(TEST_LINE))

    rows << {
      layer: layer,
      master: master_from_path(rel, layer),
      ruby_path: rel,
      ruby_test: m[1],
      source: source,
      rust_path: "",
      rust_fn: "",
      status: "pending"
    }
  end
  rows
end

rows = []
R1_GLOBS.each { |g| expand_glob(g).each { |p| rows.concat(extract_tests(p, "R1", source: "domain")) } }
GW_GLOBS.each { |g| expand_glob(g).each { |p| rows.concat(extract_tests(p, "GW", source: "ar")) } }
Pathname.glob(ROOT.join(R4_CONTROLLER_GLOB)).sort.each { |p| rows.concat(extract_tests(p.to_s, "R4", source: "controller")) }
Pathname.glob(ROOT.join(R4_CONTRACT_GLOB)).sort.each { |p| rows.concat(extract_tests(p.to_s, "R4", source: "contract")) }

rows.each { |r| enrich_row!(r) }

pending = rows.count { |r| r[:status] == "pending" }
partial = rows.count { |r| r[:status] == "partial" }

counts = rows.group_by { |r| r[:layer] }.transform_values(&:count)

puts "# Masters CRUD parity matrix (generated)"
puts
puts "Generated: #{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')}"
puts
puts "| Layer | Count |"
puts "|-------|------:|"
counts.sort.each { |layer, n| puts "| #{layer} | #{n} |" }
puts "| **Total** | **#{rows.size}** |"
puts
puts "Status: added=#{rows.count { |r| r[:status] == 'added' }}, partial=#{partial}, pending=#{pending}"
puts
puts "| Layer | Master | Source | Ruby path | Ruby test | Rust path | Rust fn | Status |"
puts "|-------|--------|--------|-----------|-----------|-----------|---------|--------|"
rows.each do |r|
  puts "| #{r[:layer]} | #{r[:master]} | #{r[:source]} | `#{r[:ruby_path]}` | #{r[:ruby_test]} | #{r[:rust_path]} | #{r[:rust_fn]} | #{r[:status]} |"
end

warn "R1=#{counts['R1'] || 0} GW=#{counts['GW'] || 0} R4=#{counts['R4'] || 0} total=#{rows.size}"
