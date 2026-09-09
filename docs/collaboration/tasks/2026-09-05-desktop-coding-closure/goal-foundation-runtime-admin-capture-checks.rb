# Run only under the ordinary-user controller. No authentication or sampling.
# Removing a guard must change its exact refusal reason or create a forbidden effect.
require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'timeout'

abort 'never run these checks as root' if Process.euid == 0
helper, observer = ARGV
abort 'usage: ruby checks.rb ADMIN_HELPER OBSERVER_HELPER' unless ARGV.length == 2 && [helper, observer].all? { |p| p.start_with?('/') && File.executable?(p) }
identity_text, identity_error, identity_status = Open3.capture3(observer, '--identity', Process.pid.to_s)
identity = JSON.parse(identity_text)
raise 'own identity unavailable' unless identity_status.success? && identity_error.empty? && identity['pid'] == Process.pid && identity['uid'] == Process.uid && identity['status'] == 0
td = File.dirname(File.realpath(__FILE__))
repo = File.expand_path('../../../..', td)
binary = File.realpath(File.join(repo, '.build/debug/RunTests'))
temp = File.realpath(Dir.tmpdir)
run = Dir.mktmpdir('agentloop-admin-refusal-', temp)
File.chmod(0700, run)
run = File.realpath(run)
base = [Process.uid.to_s, Process.pid.to_s, identity.fetch('start_sec').to_s,
        identity.fetch('start_usec').to_s, binary, temp, run]
ticket = [Process.pid, identity['start_sec'], identity['start_usec'], Process.pid,
          identity['start_sec'], identity['start_usec']].join(' ')
cases = [
  ['forbidden mode', ['--anything'] + base, 'mode'],
  ['missing ticket', ['--capture'] + base, 'arguments'],
  ['extra argument', ['--capture'] + base + [ticket, 'extra'], 'arguments'],
  ['five ticket fields', ['--capture'] + base + ['1 2 3 4 5'], 'ticket'],
  ['seven ticket fields', ['--capture'] + base + ['1 2 3 4 5 6 7'], 'ticket'],
  ['nondecimal ticket', ['--capture'] + base + ['1 2 3 x 5 6'], 'ticket'],
  ['negative ticket', ['--capture'] + base + ['1 2 3 -4 5 6'], 'ticket'],
  ['overflow ticket', ['--capture'] + base + ['1 2 3 18446744073709551616 5 6'], 'ticket'],
  ['PID range ticket', ['--capture'] + base + ['2147483648 2 3 4 5 6'], 'ticket'],
  ['microsecond range', ['--capture'] + base + ['1 2 1000000 4 5 6'], 'ticket'],
  ['leading whitespace', ['--capture'] + base + [' ' + ticket], 'ticket'],
  ['trailing whitespace', ['--capture'] + base + [ticket + ' '], 'ticket'],
  ['newline ticket', ['--capture'] + base + [ticket + "\n"], 'ticket'],
  ['zero owner', ['--capture', '0'] + base.drop(1) + [ticket], 'owner'],
  ['wrong owner', ['--capture', (Process.uid + 1).to_s] + base.drop(1) + [ticket], 'directory'],
  ['wrong launcher generation', ['--capture'] + base.each_with_index.map { |v,i| i == 2 ? '1' : v } + [ticket], 'launcher'],
  ['wrong ancestry', ['--capture'] + base + [ticket], 'runtests'],
  ['wrong executable path', ['--capture'] + base.each_with_index.map { |v,i| i == 4 ? '/bin/sh' : v } + [ticket], 'paths']
]
passed = 0
begin
  cases.each do |label, args, reason|
    out, err, status = Timeout.timeout(5) { Open3.capture3(helper, *args) }
    rows = err.lines.reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
    raise "#{label}: wrong refusal #{status.exitstatus} #{rows.inspect}" unless status.exitstatus != 0 && rows.any? { |r| r['event'] == 'refused' && r['reason'] == reason }
    raise "#{label}: capture side effect" unless out.empty? && rows.none? { |r| %w[capture_started spindump_started spindump_result].include?(r['event']) } && Dir.children(run).empty?
    puts JSON.generate(check: label, passed: true)
    passed += 1
  end
  [['nonprivate directory', 0755, false], ['symlink directory', 0700, true]].each do |label, mode, symlink|
    File.chmod(mode, run)
    link = run + '-link'
    File.symlink(run, link) if symlink
    args = base.dup
    args[-1] = link if symlink
    out, err, status = Timeout.timeout(5) { Open3.capture3(helper, '--capture', *args, ticket) }
    rows = err.lines.map { |line| JSON.parse(line) }
    raise "#{label}: guard did not reject" unless !status.success? && out.empty? && rows.any? { |r| r['event'] == 'refused' && r['reason'] == 'directory' }
    raise "#{label}: unexpected marker" unless Dir.children(run).empty?
    puts JSON.generate(check: label, passed: true)
    passed += 1
  ensure
    File.unlink(link) if symlink && File.symlink?(link)
    File.chmod(0700, run)
  end
ensure
  # Retain refusal evidence directory; do not recursively remove anything.
  puts JSON.generate(retained_check_directory: run, passed: passed)
end
