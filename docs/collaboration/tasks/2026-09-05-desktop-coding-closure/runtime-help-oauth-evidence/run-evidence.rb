require 'json'
require 'digest'
require 'time'

entry_path = ENV.fetch('AGENTLOOP_EVIDENCE_ENTRY', 'docs/collaboration/tasks/2026-09-05-desktop-coding-closure/runtime-native-cli-fixture-entry.json')
entry = JSON.parse(File.read(entry_path))
label = ARGV.shift
abort 'invalid label or command' unless label && label.match?(/\A[a-z0-9-]+\z/) && !ARGV.empty?
base = entry.fetch('evidence_dir')
result_path = File.join(base, "#{label}.json")
log_path = File.join(base, "#{label}.log")
abort 'evidence already exists' if File.exist?(result_path) || File.exist?(log_path)

def manifest
  paths = (Dir.glob('Sources/**/*') + Dir.glob('scripts/**/*') + ['Package.swift', 'Package.resolved']).select { |p| File.file?(p) }.sort
  paths.map { |p| "#{Digest::SHA256.file(p).hexdigest}  #{p}\n" }.join
end

before = manifest
File.write(File.join(base, "#{label}-before.sha256"), before)
binary = '.build/arm64-apple-macosx/debug/RunTests'
fixture_binary = '.build/arm64-apple-macosx/debug/CliMechanicsFixtureRunner'
record = { command: ARGV, cwd: Dir.pwd, started_at: Time.now.iso8601(6), before_sha256: Digest::SHA256.hexdigest(before), log: log_path }
record[:binary_before_sha256] = Digest::SHA256.file(binary).hexdigest if File.file?(binary)
record[:fixture_binary_before_sha256] = Digest::SHA256.file(fixture_binary).hexdigest if File.file?(fixture_binary)
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
File.open(log_path, File::WRONLY | File::CREAT | File::EXCL, 0600) do |log|
  pid = Process.spawn(*ARGV, out: log, err: log)
  record[:owned_pid] = pid
  puts "started #{label} pid=#{pid} log=#{log_path}"
  STDOUT.flush
  waited, status = Process.wait2(pid)
  record.merge!(waited_pid: waited, exit_code: status.exitstatus, signal: status.termsig)
end
record[:wall_seconds] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
record[:finished_at] = Time.now.iso8601(6)
after = manifest
File.write(File.join(base, "#{label}-after.sha256"), after)
record[:after_sha256] = Digest::SHA256.hexdigest(after)
record[:source_unchanged] = before == after
record[:log_sha256] = Digest::SHA256.file(log_path).hexdigest
record[:binary_after_sha256] = Digest::SHA256.file(binary).hexdigest if File.file?(binary)
record[:fixture_binary_after_sha256] = Digest::SHA256.file(fixture_binary).hexdigest if File.file?(fixture_binary)
File.write(result_path, JSON.pretty_generate(record) + "\n")
puts JSON.pretty_generate(record)
exit(record[:source_unchanged] ? (record[:exit_code] || 128 + record[:signal]) : 98)
