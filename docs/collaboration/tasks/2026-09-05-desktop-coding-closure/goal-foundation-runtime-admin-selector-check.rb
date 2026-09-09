# Ordinary-only regression: removing selector's shell exec must fail the actual
# direct-parent assertion. Root owns execution. No auth, RunTests, or signals.
require 'json'
require 'digest'
require 'tmpdir'
require 'open3'
require 'time'

abort 'ordinary user and no arguments required' unless ARGV.empty? && Process.uid != 0 && Process.uid == Process.euid
td = File.dirname(File.realpath(__FILE__))
script = File.join(td, 'goal-foundation-runtime-admin-capture.applescript')
helper = '/private/tmp/agentloop-admin-final-compile-20260907-20814-ic98bc/admin-capture'
observer = '/private/tmp/agentloop-child-observer-20260906-94075-n85bj9/observer'
raise 'unexpected helper binary' unless Digest::SHA256.file(helper).hexdigest == 'ce85c0c1d709898ef2ff36ce12a9f73d13a440f5d49678dac1ebac64316542f5'
raise 'unexpected observer binary' unless Digest::SHA256.file(observer).hexdigest == '10461c3041954e75b89a3e7d55d57818cc608935ca82bd313aff8e614ae49365'
source = File.binread(script)
auth = "    do shell script \"/usr/bin/true\" with administrator privileges altering line endings false\n"
capture = "    return do shell script captureCommand with administrator privileges altering line endings false\n"
raise 'unsafe variant: expected exactly one fixed auth and capture statement' unless source.scan(auth).length == 1 && source.scan(capture).length == 1
variant = source.sub(auth, '').sub(capture, "    return ticket\n")
raise 'unsafe variant: administrator statement remains' if variant.include?('with administrator privileges')
raise 'unsafe variant: capture invocation remains' if variant.include?('do shell script captureCommand')
# No disk variant and no privileged original invocation; only this memory string
# is passed to osascript -e. Selector construction and all seven fields are real.
binary = File.realpath(File.join(td, '../../../../.build/debug/RunTests'))
temp = File.realpath(Dir.tmpdir)
File.umask(0077)
run = File.realpath(Dir.mktmpdir('agentloop-selector-check-', temp))
File.chmod(0700, run)
meta = File.open(File.join(run, 'process.ndjson'), 'wx', 0600); meta.sync = true
apple_out = File.join(run, 'osascript.stdout'); apple_err = File.join(run, 'osascript.stderr')
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
record = ->(event, fields) { meta.puts(JSON.generate({event: event, wall: Time.now.iso8601(9)}.merge(fields))) }
record.call('start', {controller_pid: Process.pid, source_sha256: Digest::SHA256.hexdigest(source), variant_sha256: Digest::SHA256.hexdigest(variant), run_directory: run})
puts JSON.generate(retained_directory: run); STDOUT.flush

read_identity = lambda do |pid|
  out, err, status = Open3.capture3(observer, '--identity', pid.to_s)
  record.call('identity', {requested_pid: pid, stdout: out, stderr: err, exit: status.exitstatus, signal: status.termsig})
  [JSON.parse(out), status, err]
end
valid_identity = lambda do |pid|
  row, status, err = read_identity.call(pid)
  raise 'identity handshake failed' unless status.success? && err.empty? && row['status'] == 0 && row['pid'] == pid && row['uid'] == Process.uid
  row
end
same = ->(a, b) { %w[pid ppid uid pgid start_sec start_usec].all? { |key| a.fetch(key) == b.fetch(key) } }
birth = ->(row) { row.fetch('start_sec') * 1_000_000 + row.fetch('start_usec') }
wait_until = lambda do |pid, deadline, role|
  loop do
    begin
      waited = Process.wait2(pid, Process::WNOHANG)
    rescue Errno::EINTR => error
      record.call('wait_interrupted', {role: role, pid: pid, errno: error.errno})
      raise 'wait deadline after EINTR' if clock.call >= deadline
      next
    end
    if waited
      record.call('reaped', {role: role, pid: pid, exit: waited[1].exitstatus, signal: waited[1].termsig})
      break waited[1]
    end
    if clock.call >= deadline
      record.call('cleanup_incomplete', {role: role, pid: pid})
      raise "#{role} not reaped within bounded wait; no signal permitted"
    end
    sleep 0.05
  end
end

dummy_pid = nil; dummy_status = nil; apple_pid = nil; apple_status = nil
selector_identity = nil; pipe_read = nil; pipe_write = nil
failure = nil; cleanup_errors = []
begin
  pipe_read, pipe_write = IO.pipe
  floor = (Time.now.to_r * 1_000_000).floor
  dummy_pid = fork do
    pipe_write.close
    pipe_read.read(1) # EOF from our controller is the only exit trigger.
    pipe_read.close
    exit! 0 # No subprocesses, application code, handlers, or inherited at_exit.
  end
  pipe_read.close
  dummy = valid_identity.call(dummy_pid)
  raise 'dummy not a fresh exact owned child' unless dummy['ppid'] == Process.pid && birth.call(dummy) >= floor
  args = [Process.uid.to_s, dummy_pid.to_s, dummy.fetch('start_sec').to_s, dummy.fetch('start_usec').to_s, binary, temp, run]
  apple_floor = (Time.now.to_r * 1_000_000).floor
  apple_pid = Process.spawn('/usr/bin/osascript', '-e', variant, *args, out: apple_out, err: apple_err, close_others: true)
  apple = valid_identity.call(apple_pid)
  raise 'osascript not a fresh exact owned child' unless apple['ppid'] == Process.pid && apple['path'] == '/usr/bin/osascript' && birth.call(apple) >= apple_floor
  ready_deadline = clock.call + 20
  marker = File.join(run, 'auth-ready')
  loop do
    waited = Process.wait2(apple_pid, Process::WNOHANG)
    if waited
      apple_status = waited[1]
      record.call('reaped', {role: 'osascript_early', pid: apple_pid, exit: apple_status.exitstatus, signal: apple_status.termsig})
      raise 'ordinary selector exited before marker'
    end
    raise 'ordinary selector readiness deadline' if clock.call >= ready_deadline
    if File.exist?(marker) || File.symlink?(marker)
      stat = File.lstat(marker)
      raise 'unsafe marker' unless stat.file? && !stat.symlink? && stat.uid == Process.uid && (stat.mode & 07777) == 0600 && stat.nlink == 1 && stat.size <= 256
      if stat.size > 0
        row = JSON.parse(File.binread(marker))
        raise 'unexpected marker keys' unless row.keys.sort == %w[selector_pid start_sec start_usec]
        selector_identity = valid_identity.call(row.fetch('selector_pid'))
        raise 'selector marker generation/image mismatch' unless selector_identity['start_sec'] == row['start_sec'] && selector_identity['start_usec'] == row['start_usec'] && selector_identity['path'] == helper && birth.call(selector_identity) >= apple_floor
        parent = valid_identity.call(selector_identity.fetch('ppid'))
        fresh_apple = valid_identity.call(apple_pid)
        record.call('direct_parent_assertion', {selector: selector_identity, actual_parent: parent, expected_osascript: apple})
        raise 'owned osascript generation changed' unless same.call(apple, fresh_apple)
        # Literal behavior oracle: no /bin/bash or /bin/sh bridge is allowed.
        raise "selector parent is not direct osascript: actual=#{parent['path']} pid=#{parent['pid']} expected=#{apple_pid}" unless same.call(parent, apple) && parent['path'] == '/usr/bin/osascript'
        break
      end
    end
    sleep 0.01
  end
rescue StandardError => error
  failure = "#{error.class}: #{error.message}"
  record.call('assertion_failed', {error: failure})
  warn failure
ensure
  # Closing only our pipe makes the child exit; then real selector sees its
  # launcher disappear and refuses. Never kill any process or run the capture.
  pipe_write.close if pipe_write && !pipe_write.closed?
  pipe_read.close if pipe_read && !pipe_read.closed?
  begin
    dummy_status ||= wait_until.call(dummy_pid, clock.call + 5, 'dummy') if dummy_pid
    raise 'dummy exit was not clean' if dummy_status && !dummy_status.success?
  rescue StandardError => error
    cleanup_errors << "dummy: #{error.class}: #{error.message}"
  end
  begin
    apple_status ||= wait_until.call(apple_pid, clock.call + 10, 'osascript') if apple_pid
    raise 'expected ordinary selector refusal after dummy exit' if apple_status && (apple_status.success? || apple_status.termsig)
  rescue StandardError => error
    cleanup_errors << "osascript: #{error.class}: #{error.message}"
  end
  begin
    if selector_identity
      deadline = clock.call + 5
      loop do
        row, status, err = read_identity.call(selector_identity.fetch('pid'))
        if !status.success? && err.empty? && row['bsd_length'] == 0 && row['bsd_errno'] == Errno::ESRCH::Errno
          record.call('selector_absent', {generation: selector_identity}); break
        end
        raise 'selector exit identity unavailable or changed' unless status.success? && err.empty? && %w[pid uid start_sec start_usec].all? { |key| row[key] == selector_identity[key] }
        raise 'selector still present after cleanup bound' if clock.call >= deadline
        sleep 0.1
      end
    end
    rows = File.readlines(File.join(run, 'selector.ndjson')).map { |line| JSON.parse(line) }
    raise 'missing real launcher refusal' unless rows.any? { |row| row['event'] == 'refused' && row['reason'] == 'launcher' }
    raise 'unexpected capture activity' if rows.any? { |row| %w[capture_started spindump_started spindump_result].include?(row['event']) }
    raise 'source changed during check' unless File.binread(script) == source
  rescue StandardError => error
    cleanup_errors << "selector: #{error.class}: #{error.message}"
  end
  record.call('finished', {assertion_failure: failure, cleanup_errors: cleanup_errors, dummy_exit: dummy_status&.exitstatus, osascript_exit: apple_status&.exitstatus})
  meta.close
end
puts JSON.generate(passed: failure.nil? && cleanup_errors.empty?, assertion_failure: failure, cleanup_errors: cleanup_errors, retained_directory: run)
exit(failure.nil? && cleanup_errors.empty? ? 0 : 1)
