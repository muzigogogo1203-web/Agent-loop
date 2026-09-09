require 'json'
require 'digest'
require 'time'

entry = JSON.parse(File.read('docs/collaboration/tasks/2026-09-05-desktop-coding-closure/runtime-native-cli-fixture-entry.json'))
base = entry.fetch('evidence_dir')
run = JSON.parse(File.read(File.join(base, 'boundary1.json')))
collector = JSON.parse(File.read(File.join(base, 'boundary1.oslog.json')))
raw = File.join(base, 'boundary1.oslog.ndjson')
abort 'collector or raw integrity mismatch' unless collector['exit_code'] == 0 && collector['signal'].nil? && Digest::SHA256.file(raw).hexdigest == collector.fetch('log_sha256')
abort 'workload log integrity mismatch' unless Digest::SHA256.file(run.fetch('log')).hexdigest == run.fetch('log_sha256')
start_time = Time.parse(run.fetch('started_at'))
end_time = Time.parse(run.fetch('finished_at'))
pid = run.fetch('owned_pid')
image = run.fetch('command').fetch(0)
errors = []
events = []
statistics = []
File.foreach(raw).with_index(1) do |line, number|
  begin
    item = JSON.parse(line)
    if item.keys.sort == ['count', 'finished'] && item['finished'] == 1
      statistics << item
      next
    end
    timestamp = Time.parse(item.fetch('timestamp'))
    valid = item['processID'] == pid && item['processImagePath'] == image && item['senderImagePath'] == image && item['subsystem'] == 'com.muzi.agentloop' && item['category'] == 'runtime-lifecycle' && timestamp >= start_time && timestamp <= end_time
    unless valid
      errors << { line: number, reason: 'scope or horizon mismatch' }
      next
    end
    match = /\Astage=(\w+) owner=([0-9A-F-]{36}) mono=(\d+) value=(-?\d+)\z/.match(item.fetch('eventMessage'))
    unless match
      errors << { line: number, reason: 'event schema mismatch' }
      next
    end
    events << { line: number, stage: match[1], owner: match[2], mono: Integer(match[3]), value: Integer(match[4]), timestamp: item['timestamp'] }
  rescue StandardError => error
    errors << { line: number, reason: "#{error.class}: #{error.message}" }
  end
end
errors << { reason: 'statistics/count mismatch' } unless statistics.length == 1 && statistics[0]['count'] == events.length
snapshot = run.fetch('identity_snapshot')
identity_ok = snapshot['exit_code'] == 0 && snapshot['signal'].nil? && snapshot['stderr'] == '' && snapshot['stdout'].lines.length == 1 && snapshot['stdout'].strip.start_with?(pid.to_s + ' ') && snapshot['stdout'].strip.end_with?(image)
errors << { reason: 'identity snapshot mismatch' } unless identity_ok && run['waited_pid'] == pid && collector['target_pid'] == pid
errors << { reason: 'source or binary drift' } unless run['source_unchanged'] && run['source_before'] == run['source_after'] && run['binary_before'] == run['binary_after'] && run['fixture_before'] == run['fixture_after']
errors << { reason: 'empty events' } if events.empty?

text = File.read(run.fetch('log'))
mappings = text.scan(/CLI readiness identity recorder=([0-9A-F-]{36}) execution=([0-9a-f-]{36})/)
timelines = %w[346 372 347].map do |identity|
  execution = '00000000-0000-4000-8000-' + identity.rjust(12, '0')
  recorders = mappings.select { |_, candidate| candidate == execution }.map(&:first).uniq
  abort "ambiguous recorder #{execution}" unless recorders.length == 1
  recorder = recorders[0]
  pids = events.select { |event| event[:owner] == recorder && event[:stage] == 'cliFixtureCancellationPID' }.map { |event| event[:value] }
  cleanup_pids = text.scan(/CLI fixture cleanup execution=#{Regexp.escape(execution)} continuedPIDs=\[(\d+)\]/).flatten.map(&:to_i)
  abort "ambiguous fixture PID #{execution}" unless pids.length == 1 && pids[0] > 0 && cleanup_pids == pids
  owners = events.select { |event| event[:stage] == 'cliSpawned' && event[:value] == pids[0] }.map { |event| event[:owner] }.uniq
  abort "ambiguous backend owner #{execution}" unless owners.length == 1
  selected = events.select { |event| [recorder, owners[0]].include?(event[:owner]) }.sort_by { |event| event[:mono] }
  %w[cliRunQueued cliRunStarted cliFixtureReadyWaitStarted cliFixtureReadyWaitEnded].each do |stage|
    expected_owner = stage.start_with?('cliFixture') ? recorder : owners[0]
    matches = selected.select { |event| event[:stage] == stage && event[:owner] == expected_owner }
    abort "missing or duplicate #{stage} #{execution}" unless matches.length == 1
  end
  ready_starts = selected.select { |event| event[:stage] == 'cliFixtureReadyWaitStarted' }
  abort "missing or duplicate ready start #{execution}" unless ready_starts.length == 1
  origin = ready_starts[0][:mono]
  { execution: execution, recorder: recorder, pid: pids[0], backend: owners[0], events: selected.map { |event| event.merge(seconds_from_ready_start: (event[:mono] - origin) / 1_000_000_000.0) } }
end
result = { admitted: errors.empty?, pid: pid, total_events: events.length, statistics: statistics, errors: errors, workload_exit: run['exit_code'], raw_sha256: collector['log_sha256'], timelines: timelines }
output = File.join(base, 'boundary1.analysis-reviewed.json')
abort 'analysis already exists' if File.exist?(output)
File.write(output, JSON.pretty_generate(result) + "\n")
puts JSON.pretty_generate(result)
abort 'capture admission failed' unless errors.empty?
