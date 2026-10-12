#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "catalog"
require "optparse"

options = {output: "build-plan.json", names: [], base: nil}
OptionParser.new do |parser|
  parser.on("--output PATH") { |v| options[:output] = v }
  parser.on("--base SHA") { |v| options[:base] = v }
  parser.on("--pods NAMES") { |v| options[:names] = v.split(",").map(&:strip).reject(&:empty?) }
end.parse!
root = File.expand_path("../..", __dir__)
plan = XCFramework::Catalog.new(root).plan(base: options[:base], names: options[:names])
plan["repository_commit"] = IO.popen(["git", "-C", root, "rev-parse", "HEAD"], &:read).strip
File.write(options[:output], JSON.pretty_generate(plan) + "\n")
if ENV["GITHUB_OUTPUT"]
  matrix = {"include" => plan["tasks"].map { |task| {"id" => task["id"]} }}
  File.open(ENV["GITHUB_OUTPUT"], "a") do |f|
    f.puts "matrix=#{JSON.generate(matrix)}"
    f.puts "has_tasks=#{!plan['tasks'].empty?}"
  end
end
puts "Planned #{plan['tasks'].size} latest source pods; skipped #{plan['skipped'].size} non-git pods"
plan["tasks"].each { |t| puts "#{t['id']}: #{t['platforms'].keys.join(', ')}" }
