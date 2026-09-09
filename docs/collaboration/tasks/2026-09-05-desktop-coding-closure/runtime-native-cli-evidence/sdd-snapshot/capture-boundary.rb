require 'json'
require 'digest'
require 'time'
require 'open3'

entry = JSON.parse(File.read('docs/collaboration/tasks/2026-09-05-desktop-coding-closure/runtime-native-cli-fixture-entry.json'))
base = entry.fetch('evidence_dir')
label = 'boundary1'
paths = %w[log json before.sha256 after.sha256 oslog.ndjson oslog.json].to_h { |suffix| [suffix, File.join(base, "#{label}.#{suffix}")] }
abort 'boundary evidence already exists' if paths.values.any? { |path| File.exist?(path) }

def input_manifest
  (Dir.glob('Sources/**/*') + Dir.glob('scripts/**/*') + ['Package.swift', 'Package.resolved'])
    .select { |path| File.file?(path) }.sort
    .map { |path| "#{Digest::SHA256.file(path).hexdigest}  #{path}\n" }.join
end

binary = File.realpath('.build/arm64-apple-macosx/debug/RunTests')
fixture = File.realpath('.build/arm64-apple-macosx/debug/CliMechanicsFixtureRunner')
before = input_manifest
abort 'source pin drift' unless Digest::SHA256.hexdigest(before) == 'ea0160bd12c977a93fb645cb042af90f4d575efe7507d2a12c0a94fbadee18d1'
abort 'runner pin drift' unless Digest::SHA256.file(binary).hexdigest == '453286486bd7f5073d9c457de17f7c4e78e0e26798715e06d01c88f925b1d0c6'
abort 'fixture pin drift' unless Digest::SHA256.file(fixture).hexdigest == '4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2'
File.write(paths.fetch('before.sha256'), before)
started = Time.now
mono_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
record = {
  command: [binary], child_environment_override: { 'AGENTLOOP_RUNTIME_DIAGNOSTICS' => '1' },
  started_at: started.iso8601(9), monotonic_start: mono_start,
  source_before: Digest::SHA256.hexdigest(before), binary_before: Digest::SHA256.file(binary).hexdigest,
  fixture_before: Digest::SHA256.file(fixture).hexdigest, log: paths.fetch('log')
}
File.open(paths.fetch('log'), File::WRONLY | File::CREAT | File::EXCL, 0600) do |log|
  pid = Process.spawn({ 'AGENTLOOP_RUNTIME_DIAGNOSTICS' => '1' }, binary, out: log, err: log)
  record[:owned_pid] = pid
  puts "boundary1 direct RunTests pid=#{pid} log=#{paths.fetch('log')}"
  STDOUT.flush
  begin
    output, error, status = Open3.capture3('/bin/ps', '-p', pid.to_s, '-o', 'pid=,lstart=,comm=')
    record[:identity_snapshot] = { stdout: output, stderr: error, exit_code: status.exitstatus, signal: status.termsig }
  rescue StandardError => error
    record[:identity_snapshot_error] = "#{error.class}: #{error.message}"
  ensure
    waited, status = Process.wait2(pid)
    record.merge!(waited_pid: waited, exit_code: status.exitstatus, signal: status.termsig)
  end
end
finished = Time.now
record[:finished_at] = finished.iso8601(9)
record[:monotonic_finish] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
record[:wall_seconds] = record[:monotonic_finish] - mono_start
after = input_manifest
File.write(paths.fetch('after.sha256'), after)
record.merge!(source_after: Digest::SHA256.hexdigest(after), source_unchanged: before == after,
              binary_after: Digest::SHA256.file(binary).hexdigest, fixture_after: Digest::SHA256.file(fixture).hexdigest,
              log_sha256: Digest::SHA256.file(paths.fetch('log')).hexdigest)
File.write(paths.fetch('json'), JSON.pretty_generate(record) + "\n")
puts JSON.pretty_generate(record)
STDOUT.flush

# Round the query horizon outward to whole seconds; admission later enforces
# the exact nanosecond wall interval, PID, image, subsystem and category.
predicate = "processIdentifier == #{record.fetch(:owned_pid)} AND subsystem == \"com.muzi.agentloop\" AND category == \"runtime-lifecycle\""
command = ['/usr/bin/log', 'show', '--style', 'ndjson', '--start', started.strftime('%Y-%m-%d %H:%M:%S%z'),
           '--end', (Time.at(finished.to_i + 1)).strftime('%Y-%m-%d %H:%M:%S%z'), '--predicate', predicate]
collector = { command: command, target_pid: record.fetch(:owned_pid), exact_start: record.fetch(:started_at), exact_end: record.fetch(:finished_at) }
File.open(paths.fetch('oslog.ndjson'), File::WRONLY | File::CREAT | File::EXCL, 0600) do |log|
  pid = Process.spawn(*command, out: log, err: log)
  collector[:owned_pid] = pid
  waited, status = Process.wait2(pid)
  collector.merge!(waited_pid: waited, exit_code: status.exitstatus, signal: status.termsig)
end
collector[:log_sha256] = Digest::SHA256.file(paths.fetch('oslog.ndjson')).hexdigest
File.write(paths.fetch('oslog.json'), JSON.pretty_generate(collector) + "\n")
puts JSON.pretty_generate(collector)
abort 'source or executable drift during diagnostic' unless record[:source_unchanged] && record[:binary_before] == record[:binary_after] && record[:fixture_before] == record[:fixture_after]
abort 'OSLog collection failed' unless collector[:exit_code] == 0 && collector[:signal].nil?
# Workload status is reported separately. Collector completion is not evidence
# admission, runtime success, or an authoritative full acceptance gate.
