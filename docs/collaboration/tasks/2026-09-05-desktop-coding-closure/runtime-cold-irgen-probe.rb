# Diagnostic only: emit the one test primary file before LLVM optimization.
# Does not change source, compiler settings in the package, or build products.
require 'json'
require 'open3'
require 'shellwords'
require 'tmpdir'
require 'digest'

$stdout.sync = true
root = '/Users/muzi/Agent-loop'
Dir.chdir(root)
boundary_probe = ARGV == ['--coro-split-boundary']
raise 'unsupported arguments' unless ARGV.empty? || boundary_probe
source = File.join(root, 'Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift')
before = Digest::SHA256.file(source).hexdigest
output = Dir.mktmpdir('agentloop-cold-irgen.')
puts "OUTPUT_DIRECTORY=#{output} SOURCE_SHA256=#{before}"
description = JSON.parse(File.read('.build/arm64-apple-macosx/debug/description.json'))
command = description.fetch('swiftCommands').values.find { |entry| entry['moduleName'] == 'AgentLoopTestSuite' }
raise 'missing SwiftPM test command' unless command
driver = [command.fetch('executable'), '-module-name', command.fetch('moduleName'),
          '-emit-dependencies', '-emit-module', '-emit-module-path', command.fetch('moduleOutputPath'),
          '-output-file-map', command.fetch('outputFileMapPath'), '-c', "@#{command.fetch('fileList')}",
          '-I', command.fetch('importPath')] + command.fetch('otherArguments') +
         ['-j1', '-disable-batch-mode', '-driver-print-jobs']
jobs, diagnostics, status = Open3.capture3(*driver)
File.write(File.join(output, 'driver.log'), diagnostics + jobs)
raise "driver-print-jobs failed #{status.exitstatus}" unless status.success?
candidates = jobs.lines.map { |line| Shellwords.split(line) }.select do |args|
  primary = args.each_index.select { |index| args[index] == '-primary-file' }
  primary.length == 1 && args[primary.first + 1] == source
end
raise "expected exactly one primary-file job, got #{candidates.length}" unless candidates.length == 1
original = candidates.first
raise 'unexpected frontend' unless original.first == '/Library/Developer/CommandLineTools/usr/bin/swift-frontend'
File.write(File.join(output, 'original-argv.json'), JSON.pretty_generate(original))
removed_pairs = ['-emit-dependencies-path', '-emit-reference-dependencies-path',
                 '-serialize-diagnostics-path', '-o', '-index-store-path']
args = []
index = 0
while index < original.length
  argument = original[index]
  if removed_pairs.include?(argument)
    index += 2
    next
  end
  args << (argument == '-c' && !boundary_probe ? '-emit-irgen' : argument) unless argument == '-index-system-modules'
  index += 1
end
if boundary_probe
  args += ['-Xllvm', '-print-before=coro-split', '-Xllvm',
           '-filter-print-funcs=$s18AgentLoopTestSuite31ExecutionEngineConformanceTestsV38p1f1_069BoardTerminalExactlyOnceMatrixyyYaKF']
end
args += ['-o', File.join(output, boundary_probe ? 'diagnostic.o' : 'ExecutionEngineConformanceTests.ll')]
File.write(File.join(output, 'probe-argv.json'), JSON.pretty_generate(args))
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
start = clock.call
pid = nil
result = nil
stop_reason = nil
begin
File.open(File.join(output, 'frontend.log'), 'w') do |log|
  pid = Process.spawn(*args, out: log, err: log)
  puts "FRONTEND_PID=#{pid} START=#{Time.now}"
  loop do
    finished = Process.waitpid2(pid, Process::WNOHANG)
    if finished
      result = finished.last
      break
    end
    disk, disk_error, disk_status = Open3.capture3('df', '-k', root)
    raise "df failed: #{disk_error}" unless disk_status.success?
    available_kib = Integer(disk.lines.last.split[3])
    elapsed = clock.call - start
    puts "ELAPSED=#{elapsed.round(2)} AVAILABLE_KIB=#{available_kib}"
    stop_reason = 'disk_below_6GiB' if available_kib < 6 * 1024 * 1024
    stop_reason ||= 'elapsed_60s' if elapsed >= 60
    probe_prefix = File.read(File.join(output, 'frontend.log'), 8192) if boundary_probe
    if boundary_probe && probe_prefix && probe_prefix.include?('IR Dump Before CoroSplitPass')
      stop_reason ||= 'target_CoroSplit_entry_observed'
    end
    if stop_reason
      # This is our unreaped direct child; the PID cannot have been reused.
      Process.kill('TERM', pid)
      puts "OWNED_TERM pid=#{pid} reason=#{stop_reason}"
      20.times do
        finished = Process.waitpid2(pid, Process::WNOHANG)
        if finished
          result = finished.last
          break
        end
        sleep 0.25
      end
      unless result
        Process.kill('KILL', pid)
        result = Process.waitpid2(pid).last
        puts "OWNED_KILL pid=#{pid} after_TERM_5s"
      end
      break
    end
    sleep 2
  end
end
ensure
  if pid && !result
    finished = Process.waitpid2(pid, Process::WNOHANG)
    if finished
      result = finished.last
    else
      warn "DIAGNOSTIC_ERROR_OWNED_CLEANUP pid=#{pid}"
      Process.kill('KILL', pid)
      result = Process.waitpid2(pid).last
    end
  end
end
after = Digest::SHA256.file(source).hexdigest
puts "END=#{Time.now} ELAPSED=#{(clock.call - start).round(2)} EXIT=#{result.exitstatus.inspect} SIGNAL=#{result.termsig.inspect} STOP_REASON=#{stop_reason.inspect} SOURCE_SHA256_AFTER=#{after}"
raise 'source changed during diagnostic' unless before == after
exit(result.exitstatus || 128 + result.termsig)
