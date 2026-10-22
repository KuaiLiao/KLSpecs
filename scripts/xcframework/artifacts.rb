# frozen_string_literal: true
require "json"
require "digest"
require "open3"

module XCFramework
  class Artifacts
    def self.aggregate(plan, directory)
      expected = plan.fetch("tasks").map { |t| t.fetch("id") }.sort
      raise ArgumentError, "Nothing to publish" if expected.empty?
      files = Dir.glob(File.join(directory, "*.build.json"))
      packages = files.map { |f| JSON.parse(File.read(f)) }
      raise ArgumentError, "Incomplete or duplicate task metadata" unless packages.map { |p| p.fetch("id") }.sort == expected
      packages.each do |package|
        task = plan.fetch("tasks").find { |t| t["id"] == package["id"] }
        raise ArgumentError, "Unvalidated #{package['id']}" unless package["validated"] == true
        raise ArgumentError, "Wrong fingerprint #{package['id']}" unless package["fingerprint"] == task["fingerprint"]
        raise ArgumentError, "Wrong checkout #{package['id']}" unless package["repository_commit"] == plan["repository_commit"]
        asset = package.fetch("asset")
        raise ArgumentError, "Unsafe asset path" unless asset == "#{package['id']}.xcframework.zip"
        path = File.join(directory, asset)
        raise ArgumentError, "Missing or changed #{asset}" unless File.file?(path) && Digest::SHA256.file(path).hexdigest == package["sha256"]
        _, status = Open3.capture2e("unzip", "-t", path)
        raise ArgumentError, "Invalid zip #{asset}" unless status.success?
        text, status = Open3.capture2e("unzip", "-p", path, "#{package['id']}/Metadata/build-info.json")
        raise ArgumentError, "Missing zip metadata #{asset}" unless status.success?
        embedded = JSON.parse(text)
        raise ArgumentError, "Zip/sidecar mismatch #{asset}" unless embedded == package.reject { |k, _| %w[asset sha256].include?(k) }
      end
      raise ArgumentError, "Unexpected ZIP files" unless Dir.glob(File.join(directory, "*.xcframework.zip")).map { |p| File.basename(p) }.sort == packages.map { |p| p["asset"] }.sort
      manifest = {"schema" => 1, "repository_commit" => plan.fetch("repository_commit"), "packages" => packages.sort_by { |p| p["id"] }}
      File.write(File.join(directory, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
      File.write(File.join(directory, "SHA256SUMS"), manifest["packages"].map { |p| "#{p['sha256']}  #{p['asset']}\n" }.join)
      rows = manifest["packages"].map do |p|
        minimums = p.fetch("slices").map { |s| "#{s['platform']} #{s['minimum']}" }.uniq.join(", ")
        "| #{p['name']} | #{p['version']} | #{minimums} |"
      end
      notes = <<~TEXT
        # Latest Git-sourced XCFrameworks

        Spec checkout: `#{plan.fetch('repository_commit')}`. Build scope: `#{plan.fetch('platform_scope', 'ios')}`. Each ZIP contains one pod, not its dependency binaries.
        In the default `ios` scope, device uses arm64 and simulator uses arm64_sim (actual Mach-O arm64 simulator slice) plus x86_64 when supported.
        Only declared platforms in the selected scope are built. SDK deployment floors may raise the minimum OS version; the **effective** minimums are listed below and in each package's Metadata/build-info.json.

        | Pod | Version | Effective platform minimums |
        | --- | --- | --- |
        #{rows.join("\n")}

        Resource bundles are under Resources/<slice>; install the matching slice's bundles with the application. Do not copy bundles from all slices together.
        Inspect Metadata/Podfile-*.lock for resolved dependencies and integrate those dependencies separately.
        SHA256SUMS covers the ZIP attachments. No source.http pods were repackaged. XCFrameworks are unsigned.
      TEXT
      File.write(File.join(directory, "release-notes.md"), notes)
      manifest
    end
  end
end
