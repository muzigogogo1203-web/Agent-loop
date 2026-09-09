# One explicitly authorized invocation; root controller alone executes this file.
# No retries. Test cleanup is never signaled or shortened by diagnostic failures.
require 'tmpdir'
require 'digest'
require 'time'
require 'json'
require 'open3'
require 'base64'

abort 'run the collector as the ordinary user, never root' if Process.uid == 0 || Process.uid != Process.euid
name, helper, observer = ARGV
approved_helper = '/private/tmp/agentloop-admin-final-compile-20260907-20814-ic98bc/admin-capture'
approved_observer = '/private/tmp/agentloop-child-observer-20260906-94075-n85bj9/observer'
abort 'only the single approved name and exact reviewed binaries are accepted' unless ARGV.length == 3 && name == 'goal-foundation-runtime-admin-observed2' && helper == approved_helper && observer == approved_observer
td = File.dirname(File.realpath(__FILE__))
repo = File.expand_path('../../../..', td)
abort 'wrong checkout' unless repo == '/Users/muzi/Agent-loop' && Dir.pwd == repo
location_path = File.join(td, 'goal-foundation-runtime-admin-observed2-location.json')
abort 'the one authorized attempt is already consumed' if File.exist?(location_path) || File.symlink?(location_path)
script = File.join(td, 'goal-foundation-runtime-admin-capture.applescript')
binary = File.realpath('.build/debug/RunTests')
temp = File.realpath(Dir.tmpdir)
approved = {
  helper => 'ce85c0c1d709898ef2ff36ce12a9f73d13a440f5d49678dac1ebac64316542f5',
  observer => '10461c3041954e75b89a3e7d55d57818cc608935ca82bd313aff8e614ae49365',
  script => 'e71c166d01e19fc0da074dd94aa9279d2743e60af7e773fb32c4a9ffcd7f083d'
}
check_approved = lambda do
  approved.each do |path, hash|
    stat = File.lstat(path); parent = File.dirname(path); directory = File.lstat(parent)
    raise 'approved file identity/permissions mismatch' unless File.realpath(path) == path && stat.file? && !stat.symlink? && stat.nlink == 1 && stat.uid == Process.uid && (stat.mode & 0022) == 0 && File.realpath(parent) == parent && directory.directory? && !directory.symlink? && directory.uid == Process.uid && (directory.mode & 0022) == 0
    raise 'approved binary is not executable' if path != script && !File.executable?(path)
    raise 'approved file SHA mismatch' unless Digest::SHA256.file(path).hexdigest == hash
  end
end
check_approved.call
paths = -> { (Dir.glob('Sources/**/*') + Dir.glob('scripts/**/*') + %w[Package.swift Package.resolved]).select { |p| File.file?(p) }.sort }
frozen = paths.call.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
manifest = frozen.map { |path, hash| "#{hash}  #{path}\n" }.join
pins = [helper, observer, script, __FILE__, File.join(td, 'goal-foundation-runtime-admin-capture.c'),
        File.join(td, 'goal-foundation-runtime-child-observer.c'), File.join(td, 'goal-foundation-runtime-child-observer-run.rb')].to_h { |path| [File.realpath(path), Digest::SHA256.file(path).hexdigest] }
raise 'build inputs do not match approved 305 manifest' unless frozen.length == 305 && Digest::SHA256.hexdigest(manifest) == 'a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f'
raise 'old observer source changed' unless pins.fetch(File.join(td, 'goal-foundation-runtime-child-observer.c')) == '027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf'
raise 'old runner changed' unless pins.fetch(File.join(td, 'goal-foundation-runtime-child-observer-run.rb')) == '74f5a90ac5b94c5631bb9b8f1a65584b3583fe0255cf3aedf12ed7b740e69417'
# All caller arguments and approved pins are checked before any artifact exists.
# O_EXCL consumes the only authorization even if subsequent setup/auth fails.
File.umask(0077)
run = nil
File.open(location_path, File::WRONLY | File::CREAT | File::EXCL, 0600) do |claim|
  claim.write(JSON.generate(attempt: 'reserved', launcher_pid: Process.pid) + "\n"); claim.flush
  run = File.realpath(Dir.mktmpdir('agentloop-admin-' + name + '-', temp))
  File.chmod(0700, run)
  claim.rewind; claim.truncate(0)
  claim.write(JSON.generate(run_directory: run, launcher_pid: Process.pid) + "\n"); claim.flush
end
raw = %w[process test observer observer-stderr apple apple-stderr identity events events-stderr sample-stdout sample-stderr].to_h { |role| [role, File.join(run, role + '.log')] }
raw.each_value { |path| File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) {} }
meta = File.open(raw.fetch('process'), 'a'); meta.sync = true
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
status_record = ->(role, status) { meta.puts(JSON.generate(event: 'status', role: role, exit: status&.exitstatus, signal: status&.termsig)) }
File.write(File.join(run, 'source.sha256'), manifest)
File.write(File.join(run, 'pins.json'), JSON.pretty_generate(pins))
meta.puts(JSON.generate(event: 'start', launcher: Process.pid, uid: Process.uid, run_directory: run, pins: pins))

# Every helper identity result, including API errors, is retained before parsing.
identity = lambda do |pid|
  out, err, status = Open3.capture3(observer, '--identity', pid.to_s)
  File.open(raw.fetch('identity'), 'a') do |file|
    file.puts(JSON.generate(request_pid: pid, stdout: out, stderr: err, exit: status.exitstatus, signal: status.termsig))
  end
  row = JSON.parse(out)
  raise 'identity unavailable' unless status.success? && err.empty? && row['status'] == 0 && row['pid'] == pid && row['uid'] == Process.uid
  row
end
same_identity = ->(a, b) { %w[pid ppid uid pgid start_sec start_usec].all? { |key| a.fetch(key) == b.fetch(key) } }
birth = ->(row) { row.fetch('start_sec') * 1_000_000 + row.fetch('start_usec') }
apple_pid = nil; apple_status = nil; apple_identity = nil; apple_cleanup_attempted = false; apple_reap_deadline = nil
selector_identity = nil; selector_deadline = nil
test_pid = nil; test_status = nil; observer_pid = nil; observer_status = nil
log_pid = nil; log_status = nil; invocation_start = nil; invocation_end = nil
ready_at = nil; deadline = nil; errors = []; result = 93

# Sole signaling authority: exact still-unreaped own osascript on its bounded
# authentication/transport deadline. Never a process group, test, or target.
finish_apple = lambda do
  next if apple_pid.nil? || apple_status
  begin
    unless apple_cleanup_attempted
      apple_cleanup_attempted = true
      loop do
        waited = Process.wait2(apple_pid, Process::WNOHANG)
        if waited
          apple_status = waited[1]; break
        end
        break if clock.call >= deadline
        sleep 0.05
      end
      unless apple_status
        # Keep the initiating failure even if a raced exit is successfully reaped.
        errors << 'osascript deadline expired; no capture admission'
        raise 'osascript deadline without pinned identity; no signal authorized' unless apple_identity
        fresh = identity.call(apple_pid)
        raise 'osascript generation changed; no signal authorized' unless same_identity.call(apple_identity, fresh) && fresh['ppid'] == Process.pid && fresh['path'] == '/usr/bin/osascript'
        meta.puts(JSON.generate(event: 'osascript_deadline', pid: apple_pid, identity: fresh))
        sent = Process.kill('TERM', apple_pid)
        meta.puts(JSON.generate(event: 'osascript_signal', pid: apple_pid, signal: 'TERM', result: sent))
        grace = clock.call + 2
        until clock.call >= grace
          waited = Process.wait2(apple_pid, Process::WNOHANG)
          if waited
            apple_status = waited[1]; break
          end
          sleep 0.05
        end
        unless apple_status
          fresh = identity.call(apple_pid)
          raise 'osascript identity lost before KILL; no signal authorized' unless same_identity.call(apple_identity, fresh) && fresh['ppid'] == Process.pid && fresh['path'] == '/usr/bin/osascript'
          sent = Process.kill('KILL', apple_pid)
          meta.puts(JSON.generate(event: 'osascript_signal', pid: apple_pid, signal: 'KILL', result: sent))
        end
      end
    end
  rescue StandardError => error
    errors << "osascript cleanup original error: #{error.class}: #{error.message}"
    meta.puts(JSON.generate(event: 'osascript_cleanup_error', error: error.class.name, detail: error.message, errno: error.respond_to?(:errno) ? error.errno : nil))
  ensure
    # This runs after EVERY identity/signal exception, even when the signal path
    # was already attempted. Re-entry does not extend the original three seconds.
    unless apple_status
      apple_reap_deadline ||= clock.call + 3
      begin
        loop do
          begin
            waited = Process.wait2(apple_pid, Process::WNOHANG)
          rescue Errno::EINTR => error
            meta.puts(JSON.generate(event: 'osascript_reap_interrupted', errno: error.errno))
            break if clock.call >= apple_reap_deadline
            next
          end
          if waited
            apple_status = waited[1]; break
          end
          break if clock.call >= apple_reap_deadline
          sleep 0.05
        end
      rescue StandardError => error
        errors << "osascript final reap: #{error.class}: #{error.message}"
        meta.puts(JSON.generate(event: 'osascript_reap_error', error: error.class.name, detail: error.message, errno: error.respond_to?(:errno) ? error.errno : nil))
      end
    end
    unless apple_status
      meta.puts(JSON.generate(event: 'cleanup_incomplete', role: 'osascript', pid: apple_pid, identity: apple_identity))
      errors << 'osascript not confirmed reaped within final three-second bound'
    end
    status_record.call('osascript', apple_status)
  end
end

# Selector is not our direct child; never pretend waitpid/osascript status reaped
# it. Observe only the already admitted PID/generation until its finite deadline.
finish_selector = lambda do
  next unless selector_identity
  loop do
    out, err, status = Open3.capture3(observer, '--identity', selector_identity.fetch('pid').to_s)
    File.open(raw.fetch('identity'), 'a') { |file| file.puts(JSON.generate(role: 'selector_exit_check', stdout: out, stderr: err, exit: status.exitstatus, signal: status.termsig)) }
    row = JSON.parse(out)
    if !status.success? && err.empty? && row['bsd_length'] == 0 && row['bsd_errno'] == Errno::ESRCH::Errno
      meta.puts(JSON.generate(event: 'selector_no_longer_present', identity: selector_identity))
      break
    end
    raise 'selector exit state unavailable' unless status.success? && err.empty? && row['status'] == 0
    same_birth = %w[pid uid start_sec start_usec].all? { |key| row[key] == selector_identity[key] }
    raise 'selector PID generation changed; no further observation' unless same_birth
    if clock.call >= selector_deadline
      meta.puts(JSON.generate(event: 'cleanup_incomplete', role: 'selector', identity: row))
      raise 'selector still present after its finite deadline'
    end
    sleep 0.1
  end
end

capture_logs = lambda do
  predicate = "processIdentifier == #{test_pid} AND subsystem == \"com.muzi.agentloop\" AND category == \"runtime-lifecycle\""
  log_args = ['/usr/bin/log', 'show', '--style', 'ndjson', '--last', '10m', '--predicate', predicate]
  horizon_ok = Time.now - 600 <= invocation_start
  meta.puts(JSON.generate(event: 'oslog_capture', args: log_args, horizon_covers_invocation: horizon_ok))
  log_pid = Process.spawn(*log_args, out: raw.fetch('events'), err: raw.fetch('events-stderr'))
  _, log_status = Process.wait2(log_pid)
  status_record.call('oslog', log_status)
  rows = File.readlines(raw.fetch('events')).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
  events = rows.select { |row| row.key?('eventMessage') }
  metadata = rows.reject { |row| row.key?('eventMessage') }
  admitted = []; rejected = []
  events.each_with_index do |row, index|
    timestamp = row['timestamp']; reason = nil
    if row['processID'] != test_pid || row['subsystem'] != 'com.muzi.agentloop' || row['category'] != 'runtime-lifecycle'
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
  metadata_ok = metadata.length == 1 && metadata.first['count'] == events.length && metadata.first['finished'] == 1
  oslog_ok = horizon_ok && log_status.success? && !admitted.empty? && rejected.empty? && metadata_ok
  File.write(File.join(run, 'events-admitted.ndjson'), admitted.map { |row| JSON.generate(row) + "\n" }.join)
  meta.puts(JSON.generate(event: 'oslog_admission', admitted: admitted.length, rejected: rejected, metadata: metadata, valid: oslog_ok))
  errors << 'OSLog capture/admission failed' unless oslog_ok
end

begin
  system('df', '-h', '/System/Volumes/Data', out: meta, err: meta)
  system('sysctl', 'kern.memorystatus_vm_pressure_level', 'vm.swapusage', out: meta, err: meta)
  launcher = identity.call(Process.pid)
  args = [Process.uid.to_s, Process.pid.to_s, launcher.fetch('start_sec').to_s, launcher.fetch('start_usec').to_s, binary, temp, run]
  meta.puts(JSON.generate(event: 'authentication_requested', wall: Time.now.iso8601(9), launcher_identity: launcher))
  deadline = clock.call + 180
  apple_birth_floor = (Time.now.to_r * 1_000_000).floor
  check_approved.call
  apple_pid = Process.spawn('/usr/bin/osascript', script, *args, out: raw.fetch('apple'), err: raw.fetch('apple-stderr'))
  apple_identity = identity.call(apple_pid)
  raise 'osascript is not the fresh owned child' unless apple_identity['ppid'] == Process.pid && apple_identity['path'] == '/usr/bin/osascript' && birth.call(apple_identity) >= apple_birth_floor
  marker = File.join(run, 'auth-ready')
  loop do
    waited = Process.wait2(apple_pid, Process::WNOHANG)
    if waited
      apple_status = waited[1]
      raise 'authentication or selector ended before ready; workload not started'
    end
    raise 'authentication deadline; workload not started' if clock.call >= deadline
    if File.exist?(marker) || File.symlink?(marker)
      stat = File.lstat(marker)
      raise 'invalid auth marker ownership/type/mode' unless stat.file? && !stat.symlink? && stat.uid == Process.uid && (stat.mode & 07777) == 0600 && stat.nlink == 1 && stat.size <= 256
      # O_EXCL creation precedes one small write. A zero-length file is not ready.
      if stat.size > 0
        marked = JSON.parse(File.binread(marker))
        raise 'unexpected auth marker fields' unless marked.keys.sort == %w[selector_pid start_sec start_usec]
        selected_identity = identity.call(marked.fetch('selector_pid'))
        raise 'selector generation/image mismatch' unless selected_identity['start_sec'] == marked['start_sec'] && selected_identity['start_usec'] == marked['start_usec'] && selected_identity['path'] == helper && birth.call(selected_identity) >= apple_birth_floor
        # Selector exec replaces the shell: only the exact osascript is allowed.
        selector_parent = identity.call(selected_identity.fetch('ppid'))
        raise 'selector direct osascript ancestry mismatch' unless same_identity.call(selector_parent, apple_identity) && selector_parent['path'] == '/usr/bin/osascript'
        ready_at = clock.call; deadline = ready_at + 145
        selector_identity = selected_identity; selector_deadline = ready_at + 120
        meta.puts(JSON.generate(event: 'authenticated_ready', wall: Time.now.iso8601(9), selector: selected_identity))
        break
      end
    end
    sleep 0.01
  end
  # No product command appears above this verified authenticated-ready boundary.
  check_approved.call
  raise 'diagnostic inputs changed before workload' unless pins.all? { |path, hash| Digest::SHA256.file(path).hexdigest == hash }
  invocation_start = Time.now
  meta.puts(JSON.generate(event: 'workload_start', wall: invocation_start.iso8601(9), command: 'AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests'))
  test_pid = Process.spawn({'AGENTLOOP_RUNTIME_DIAGNOSTICS' => '1'}, 'swift', 'run', 'RunTests', out: raw.fetch('test'), err: [:child, :out])
  meta.puts(JSON.generate(event: 'workload_spawned', pid: test_pid))
  begin
    target_root = identity.call(test_pid)
    raise 'test root identity handshake failed' unless target_root['ppid'] == Process.pid && birth.call(target_root) >= (invocation_start.to_r * 1_000_000).floor && birth.call(target_root) <= (Time.now.to_r * 1_000_000).ceil
    observer_pid = Process.spawn(observer, '--observe', test_pid.to_s, target_root.fetch('start_sec').to_s, target_root.fetch('start_usec').to_s, binary, temp, out: raw.fetch('observer'), err: raw.fetch('observer-stderr'))
    meta.puts(JSON.generate(event: 'observer_spawned', pid: observer_pid, root: target_root))
  rescue StandardError => error
    errors << "observer launch: #{error.class}: #{error.message}"
  end
  _, test_status = Process.wait2(test_pid)
  invocation_end = Time.now
  meta.puts(JSON.generate(event: 'workload_end', wall: invocation_end.iso8601(9)))
  status_record.call('test', test_status)
  _, observer_status = Process.wait2(observer_pid) if observer_pid
  status_record.call('observer', observer_status)
  finish_apple.call
  errors << 'osascript failed' unless apple_status&.success?
  observation = File.readlines(raw.fetch('observer')).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
  errors << 'native observer failed or empty' unless observer_status&.success? && !observation.empty?
  # osascript transports ASCII JSONL only; raw spindump bytes never pass through
  # AppleScript's text conversion. Unknown framing is a failure, not ignored data.
  frames = File.readlines(raw.fetch('apple')).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
  allowed = %w[stream api_error capture_started spindump_started spindump_result helper_result refused tool_wait tool_signal cleanup_incomplete]
  raise 'unknown capture frame' unless frames.all? { |row| allowed.include?(row['event']) }
  streams = {'stdout' => File.open(raw.fetch('sample-stdout'), 'wb'), 'stderr' => File.open(raw.fetch('sample-stderr'), 'wb')}
  begin
    frames.select { |row| row['event'] == 'stream' }.each do |row|
      raise 'bad stream frame' unless row.keys.sort == %w[base64 event role] && streams.key?(row['role'])
      streams.fetch(row['role']).write(Base64.strict_decode64(row.fetch('base64')))
    end
  ensure
    streams.each_value(&:close)
  end
  helper_results = frames.select { |row| row['event'] == 'helper_result' }
  samples = frames.select { |row| row['event'] == 'spindump_result' }
  starts = frames.select { |row| row['event'] == 'capture_started' }
  sample = samples.first
  transport_ok = helper_results.length == 1 && helper_results.first['exit'] == 0 && starts.length == 1 && samples.length == 1 && sample['exit'] == 0 && sample['signal'] == 0 && sample['io_ok'] == 1 && sample['bytes_complete'] == 1 && sample['deadline_expired'] == 0 && sample['cleanup_incomplete'] == 0 && frames.none? { |row| row['event'] == 'cleanup_incomplete' } && sample['waited'] == sample['pid'] && sample['target'] == starts.first['pid'] && !(sample['post_available'] == 1 && sample['post_same'] != 1) && File.size(raw.fetch('sample-stdout')) > 0
  errors << 'capture absent, refused, incomplete, nonzero, or identity mismatched' unless transport_ok
  meta.puts(JSON.generate(event: 'capture_transport', valid: transport_ok, sample: sample, stdout_sha256: Digest::SHA256.file(raw.fetch('sample-stdout')).hexdigest, stderr_sha256: Digest::SHA256.file(raw.fetch('sample-stderr')).hexdigest))
  meta.puts('capture_admission=PENDING independent report-scope, generation, timeline and same-run cleanup/OSLog joins; transport success is not acceptance')

  capture_logs.call
  result = errors.empty? ? (test_status.exitstatus || 128 + test_status.termsig) : 92
rescue StandardError => error
  errors << "#{error.class}: #{error.message}"
  meta.puts(JSON.generate(event: 'main_error', wall: Time.now.iso8601(9), error_class: error.class.name, message: error.message))
  result = 93
ensure
  # Retain each command's status independently on every failure path. Never signal
  # the workload. Native observer and selector have their own finite deadlines.
  [[test_pid, :test], [observer_pid, :observer], [log_pid, :oslog]].each do |pid, role|
    status = role == :test ? test_status : role == :observer ? observer_status : log_status
    next if pid.nil? || status
    begin
      _, status = Process.wait2(pid)
      if role == :test
        test_status = status; invocation_end = Time.now
        meta.puts(JSON.generate(event: 'workload_end_after_error', wall: invocation_end.iso8601(9)))
      elsif role == :observer
        observer_status = status
      else
        log_status = status
      end
      status_record.call(role, status)
    rescue StandardError => error
      errors << "#{role} wait: #{error.class}: #{error.message}"; result = 93
    end
  end
  begin
    finish_apple.call
  rescue StandardError => error
    errors << "osascript cleanup: #{error.class}: #{error.message}"; result = 93
  end
  begin
    finish_selector.call
  rescue StandardError => error
    errors << "selector cleanup: #{error.class}: #{error.message}"; result = 93
  end
  # Malformed capture transport must not suppress this one OSLog collection.
  if test_status && log_pid.nil?
    begin
      capture_logs.call
    rescue StandardError => error
      errors << "OSLog collection: #{error.class}: #{error.message}"; result = 93
    ensure
      if log_pid && log_status.nil?
        _, log_status = Process.wait2(log_pid)
        status_record.call('oslog', log_status)
      end
    end
  end
  begin
    begin
      check_approved.call
    rescue StandardError => error
      errors << "post-run approved pin: #{error.class}: #{error.message}"
      result = 93
    end
    drift = frozen.keys.select { |path| !File.file?(path) || Digest::SHA256.file(path).hexdigest != frozen[path] }
    drift += (paths.call - frozen.keys) + (frozen.keys - paths.call)
    drift += pins.keys.select { |path| !File.file?(path) || Digest::SHA256.file(path).hexdigest != pins[path] }
    after = paths.call.map { |path| "#{Digest::SHA256.file(path).hexdigest}  #{path}\n" }.join
    File.write(File.join(run, 'source-after.sha256'), after)
    meta.puts(JSON.generate(event: 'final', drift: drift, errors: errors, test_exit: test_status&.exitstatus, test_signal: test_status&.termsig, run_directory: run))
    result = 90 unless drift.empty?
    result = 93 if test_pid && test_status.nil?
  rescue StandardError => error
    meta.puts(JSON.generate(event: 'retention_error', error: "#{error.class}: #{error.message}")); result = 93
  end
  meta.puts(JSON.generate(event: 'collector_exit', code: result))
  meta.close
end
puts JSON.generate(retained_directory: run, test_exit: test_status&.exitstatus, diagnostic_errors: errors.length, collector_exit: result)
exit(result)
