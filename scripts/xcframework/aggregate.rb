#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "artifacts"
require "optparse"
options = {plan: "build-plan.json", input: "dist"}
OptionParser.new do |parser|
  parser.on("--plan PATH") { |v| options[:plan] = v }
  parser.on("--input PATH") { |v| options[:input] = v }
end.parse!
manifest = XCFramework::Artifacts.aggregate(JSON.parse(File.read(options[:plan])), options[:input])
puts "Ready to release #{manifest['packages'].size} packages"
