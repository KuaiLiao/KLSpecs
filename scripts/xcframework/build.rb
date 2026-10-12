#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "builder"
require "optparse"
options = {plan: "build-plan.json", output: "dist"}
OptionParser.new do |parser|
  parser.on("--plan PATH") { |v| options[:plan] = v }
  parser.on("--task ID") { |v| options[:task] = v }
  parser.on("--output PATH") { |v| options[:output] = v }
end.parse!
plan = JSON.parse(File.read(options[:plan]))
task = plan.fetch("tasks").find { |t| t["id"] == options[:task] } or abort "Task ID not in plan"
XCFramework::Builder.new(File.expand_path("../..", __dir__), plan, task, options[:output]).build
