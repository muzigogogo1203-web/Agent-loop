#!/usr/bin/env ruby

require 'json'
abort 'usage: check TEST_LOG ADMITTED_EVENTS PARENT_PID' unless ARGV.length == 3
test_log, event_log, parent_pid_text = ARGV
abort 'invalid parent PID' unless parent_pid_text.match?(/\A[1-9][0-9]*\z/)
parent_pid = Integer(parent_pid_text, 10)
uuid = '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
identity = /^haltFixtureIdentity test=emergencyStopCancelsRunningBeforeWaitingForPlanner orchestrator=(#{uuid}) execution=(#{uuid}) provider=(#{uuid}) gate=(#{uuid})$/
matches = File.readlines(test_log).map { |line| identity.match(line.chomp) }.compact
abort 'expected exactly one fixture identity' unless matches.length == 1
execution = matches.fetch(0)[2]
events = File.readlines(event_log).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
abort 'wrong parent event scope' unless !events.empty? && events.all? { |e| e.fetch('processID') == parent_pid && e.fetch('subsystem') == 'com.muzi.agentloop' && e.fetch('category') == 'runtime-lifecycle' }
pattern = /\Astage=(\w+) owner=(#{uuid}) mono=([0-9]+) value=(-?[0-9]+)\z/
stages = {}
events.each do |event|
  match = pattern.match(event.fetch('eventMessage'))
  abort 'malformed admitted event' unless match
  next unless match[2] == execution
  next unless match[1].start_with?('haltGate')
  abort "duplicate gate stage #{match[1]}" if stages.key?(match[1])
  stages[match[1]] = { mono: Integer(match[3], 10), value: Integer(match[4], 10) }
end
required = %w[haltGateActorWaitEntered haltGateStateWaitEntered haltGateWaitContinuationEntered haltGateWaitLockReturned haltGateStateWaitSucceeded haltGateActorWaitSucceeded haltGateActorOpenEntered haltGateStateOpenEntered haltGateOpenLockReturned haltGateOpenResumeAttempt haltGateOpenResumeReturned haltGateActorOpenSucceeded]
missing = required.reject { |name| stages.key?(name) }
abort "missing gate observations: #{missing.join(',')}" unless missing.empty?
wait_value = stages.fetch('haltGateWaitLockReturned').fetch(:value)
open_value = stages.fetch('haltGateOpenLockReturned').fetch(:value)
abort 'successful observation requires registered(0) or opened(1)' unless [0, 1].include?(wait_value)
abort 'invalid open waiter presence' unless [0, 1].include?(open_value)
%w[haltGateOpenResumeAttempt haltGateOpenResumeReturned].each do |name|
  abort 'open waiter-presence drift' unless stages.fetch(name).fetch(:value) == open_value
end
immediate = %w[haltGateWaitResumeAttempt haltGateWaitResumeReturned]
if wait_value == 1
  abort 'opened wait must have no detached opener waiter' unless open_value == 0
  immediate.each { |name| abort "missing successful immediate resume #{name}" unless stages.key?(name) && stages.fetch(name).fetch(:value) == 1 }
else
  abort 'registered waiter not detached by opener' unless open_value == 1
  abort 'registered branch emitted immediate resume' if immediate.any? { |name| stages.key?(name) }
end
abort 'canceled gate is not the selected successful observation path' if stages.keys.any? { |name| name.start_with?('haltGateCancel') }
chains = [
  %w[haltGateActorWaitEntered haltGateStateWaitEntered haltGateWaitContinuationEntered haltGateWaitLockReturned],
  %w[haltGateStateWaitSucceeded haltGateActorWaitSucceeded],
  %w[haltGateActorOpenEntered haltGateStateOpenEntered haltGateOpenLockReturned haltGateOpenResumeAttempt haltGateOpenResumeReturned haltGateActorOpenSucceeded]
]
chains << immediate if wait_value == 1
chains.each do |chain|
  chain.each_cons(2) { |left, right| abort "invalid local event order #{left}/#{right}" unless stages.fetch(left).fetch(:mono) <= stages.fetch(right).fetch(:mono) }
end
allowed = required + (wait_value == 1 ? immediate : [])
abort 'unrecognized gate observation' unless (stages.keys - allowed).empty?
puts JSON.pretty_generate({ execution: execution, parent_pid: parent_pid, branch: wait_value == 0 ? 'registered' : 'already_open', stages: stages, coverage: 'PASS', runtime_gate: 'NOT_EVALUATED' })
