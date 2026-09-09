# Root-only one-workload launcher. Compile/review/self-check helper separately first.
require 'tempfile'
require 'fileutils'
require 'digest'
require 'time'
require 'json'
require 'open3'

td = 'docs/collaboration/tasks/2026-09-05-desktop-coding-closure'
name, helper = ARGV
abort 'usage: ruby runner NAME ABSOLUTE_REVIEWED_HELPER' unless name&.match?(/\A[a-z0-9-]+\z/) && helper&.start_with?('/') && File.executable?(helper)
abort 'evidence name already exists' unless Dir.glob("#{td}/#{name}*").empty?
binary = File.realpath('.build/debug/RunTests')
fixture_parent = File.realpath(ENV.fetch('TMPDIR'))
helper_hash = Digest::SHA256.file(helper).hexdigest
observer_source = "#{td}/goal-foundation-runtime-child-observer.c"
observer_source_hash = Digest::SHA256.file(observer_source).hexdigest
paths = -> { (Dir.glob('Sources/**/*') + Dir.glob('scripts/**/*') + %w[Package.swift Package.resolved]).select { |p| File.file?(p) }.sort }
frozen = paths.call.to_h { |p| [p, Digest::SHA256.file(p).hexdigest] }
abort 'unexpected build input count' unless frozen.length == 305
File.write("#{td}/#{name}-source.sha256", frozen.map { |p,h| "#{h}  #{p}\n" }.join)
raw = %w[stdout process observer observer-stderr identity identity-stderr events events-stderr].to_h do |kind|
  file = Tempfile.create(["agentloop-#{name}-#{kind}-", '.log'], '/tmp')
  file.close
  [kind, file.path]
end
meta = File.open(raw.fetch('process'), 'a'); meta.sync = true
meta.puts("command=AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests\nlauncher_pid=#{Process.pid}")
meta.puts("helper=#{helper}\nhelper_sha256=#{helper_hash}\nobserver_source_sha256=#{observer_source_hash}\nexpected_binary=#{binary}")
meta.puts("raw_paths=#{JSON.generate(raw)}")
system('df', '-h', '/System/Volumes/Data', out: meta, err: meta)
system('sysctl', 'kern.memorystatus_vm_pressure_level', 'vm.swapusage', out: meta, err: meta)
frozen.each { |p,h| meta.puts("before #{h}  #{p}") }
invocation_start = Time.now
meta.puts("invocation_start=#{invocation_start.iso8601(9)}")
pid = Process.spawn({'AGENTLOOP_RUNTIME_DIAGNOSTICS'=>'1'}, 'swift', 'run', 'RunTests', out: raw.fetch('stdout'), err: [:child, :out])
meta.puts("pid=#{pid}"); puts("pid=#{pid} raw_output=#{raw.fetch('stdout')}"); STDOUT.flush
observer_pid = nil; observer_status = nil; observation_error = nil
begin
  identity_stdout, identity_stderr, identity_status = Open3.capture3(helper, '--identity', pid.to_s)
  File.write(raw.fetch('identity'), identity_stdout)
  File.write(raw.fetch('identity-stderr'), identity_stderr)
  identity = JSON.parse(identity_stdout)
  birth = identity.fetch('start_sec') * 1_000_000 + identity.fetch('start_usec')
  raise 'identity handshake failed' unless identity_status.success? && identity_stderr.empty? && identity['event']=='identity' && identity['status']==0 && identity['pid']==pid && identity['ppid']==Process.pid && identity['uid']==Process.uid && birth >= (invocation_start.to_r*1_000_000).floor && birth <= (Time.now.to_r*1_000_000).ceil
  observer_cmd = [helper, '--observe', pid.to_s, identity.fetch('start_sec').to_s, identity.fetch('start_usec').to_s, binary, fixture_parent]
  meta.puts("identity=#{JSON.generate(identity)}\nobserver_command=#{observer_cmd.inspect}")
  observer_pid = Process.spawn(*observer_cmd, out: raw.fetch('observer'), err: raw.fetch('observer-stderr'))
  meta.puts("observer_pid=#{observer_pid}")
rescue StandardError => error
  observation_error = "#{error.class}: #{error.message}"
  meta.puts("observer_launch_error=#{observation_error}")
end
# Even a diagnostic failure must leave the test command its normal checked cleanup.
_, test_status = Process.wait2(pid)
invocation_end = Time.now
meta.puts("invocation_end=#{invocation_end.iso8601(9)}\nexit=#{test_status.exitstatus.inspect}\nsignal=#{test_status.termsig.inspect}")
_, observer_status = Process.wait2(observer_pid) if observer_pid
meta.puts("observer_exit=#{observer_status&.exitstatus.inspect}\nobserver_signal=#{observer_status&.termsig.inspect}")
observer_rows = []
begin
  observer_rows = File.readlines(raw.fetch('observer')).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
  raise 'empty observer output' if observer_rows.empty?
rescue StandardError => error
  observation_error ||= "#{error.class}: #{error.message}"
end
meta.puts("observer_rows=#{observer_rows.length}\nobserver_parse_or_launch_error=#{observation_error.inspect}")
meta.puts('observer_target_admission=requires independent same-run cleanup and OSLog joins; not inferred from exit status')
drift = frozen.filter_map do |path, hash|
  current = File.file?(path) ? Digest::SHA256.file(path).hexdigest : 'MISSING'
  meta.puts("after #{current == hash ? 'OK' : 'MISMATCH'} #{current}  #{path}")
  path unless current == hash
end
drift += (paths.call-frozen.keys) + (frozen.keys-paths.call)
drift << observer_source unless Digest::SHA256.file(observer_source).hexdigest == observer_source_hash
drift << helper unless Digest::SHA256.file(helper).hexdigest == helper_hash
meta.puts("source_drift=#{drift.inspect}\nexecuted_binary_sha256=#{Digest::SHA256.file(binary).hexdigest}")
system('df', '-h', '/System/Volumes/Data', out: meta, err: meta)
predicate = "processIdentifier == #{pid} AND subsystem == \"com.muzi.agentloop\" AND category == \"runtime-lifecycle\""
log_cmd = ['/usr/bin/log', 'show', '--style', 'ndjson', '--last', '10m', '--predicate', predicate]
meta.puts("capture_command=#{log_cmd.inspect}")
capture_pid = Process.spawn(*log_cmd, out: raw.fetch('events'), err: raw.fetch('events-stderr'))
_, capture_status = Process.wait2(capture_pid)
rows = []; parse_error = nil
begin
  rows = File.readlines(raw.fetch('events')).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
rescue JSON::ParserError => error
  parse_error = error.class.name
end
event_rows = rows.select { |row| row.key?('eventMessage') }
admitted = []; rejected = []
event_rows.each_with_index do |row, index|
  reason = nil; timestamp = row['timestamp']
  if row['processID']!=pid || row['subsystem']!='com.muzi.agentloop' || row['category']!='runtime-lifecycle'
    reason = 'identity_mismatch'
  elsif !timestamp.is_a?(String) || !timestamp.match?(/(Z|[+-]\d{2}:?\d{2})\z/)
    reason = 'missing_absolute_timestamp'
  else
    begin
      instant = Time.parse(timestamp)
      reason = 'outside_invocation_interval' unless instant >= invocation_start && instant <= invocation_end
    rescue ArgumentError
      reason = 'timestamp_parse_error'
    end
  end
  reason ? rejected << {index: index, reason: reason} : admitted << row
end
metadata = rows.reject { |row| row.key?('eventMessage') }
metadata_ok = metadata.length==1 && metadata.first['count']==event_rows.length && metadata.first['finished']==1
capture_ok = capture_status.success? && parse_error.nil? && !admitted.empty? && rejected.empty? && metadata_ok
meta.puts("capture_admitted_count=#{admitted.length}\ncapture_rejected=#{JSON.generate(rejected)}\ncapture_metadata=#{JSON.generate(metadata)}\ncapture_metadata_ok=#{metadata_ok}\ncapture_exit=#{capture_status.exitstatus.inspect}\ncapture_parse_error=#{parse_error.inspect}\ncapture_ok=#{capture_ok}")
File.write("#{td}/#{name}-events-admitted.ndjson", admitted.map { |row| JSON.generate(row)+"\n" }.join)
meta.close
raw.each { |kind, path| FileUtils.cp(path, "#{td}/#{name}#{kind=='stdout' ? '' : '-'+kind}.#{kind=='events' || kind=='observer' ? 'ndjson' : kind=='stdout' ? 'log' : 'txt'}") }
puts("retained_prefix=#{td}/#{name}")
puts File.readlines(raw.fetch('stdout')).last(35).join
exit(!drift.empty? ? 90 : !capture_ok || observation_error || !observer_status&.success? ? 92 : (test_status.exitstatus || 128+test_status.termsig))
