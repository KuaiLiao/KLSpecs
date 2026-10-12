#!/usr/bin/env ruby
# frozen_string_literal: true
require "open3"
require "fileutils"
require "json"

module XCFramework
  class Sync
    def initialize(root, source)
      raise ArgumentError, "Source must be a full commit SHA" unless source.match?(/\A[0-9a-f]{40}\z/i)
      @root, @source = File.expand_path(root), source
    end

    def git(*args)
      stdout, stderr, status = Open3.capture3("git", "-C", @root, *args)
      raise "git #{args.first}: #{stderr}" unless status.success?
      stdout
    end

    def call
      blobs = git("ls-tree", "-r", "-z", @source).split("\0").filter_map do |entry|
        header, path = entry.split("\t", 2)
        next unless path.match?(/\.podspec(?:\.json)?\z/)
        mode, type, = header.split(" ")
        raise ArgumentError, "Spec must be a regular blob: #{path}" unless type == "blob" && %w[100644 100755].include?(mode)
        [path, git("show", "#{@source}:#{path}")]
      end.to_h
      tracked = git("ls-files", "-z").split("\0").grep(/\.podspec(?:\.json)?\z/)
      # Validate the complete write/delete set before changing any file.
      (tracked + blobs.keys).uniq.each do |path|
        current = @root
        path.split("/").each do |component|
          current = File.join(current, component)
          raise ArgumentError, "Target spec path traverses a symlink: #{path}" if File.symlink?(current)
        end
      end
      changes = []
      (tracked - blobs.keys).each do |path|
        FileUtils.rm_f(File.join(@root, path))
        changes << path
      end
      blobs.each do |path, contents|
        full = File.join(@root, path)
        next if File.file?(full) && File.binread(full) == contents
        FileUtils.mkdir_p(File.dirname(full))
        File.binwrite(full, contents)
        changes << path
      end
      changes.sort
    end
  end
end

if $PROGRAM_NAME == __FILE__
  source = ARGV.fetch(0)
  changed = XCFramework::Sync.new(File.expand_path("../..", __dir__), source).call
  puts JSON.pretty_generate({source: source, changed: changed})
end
