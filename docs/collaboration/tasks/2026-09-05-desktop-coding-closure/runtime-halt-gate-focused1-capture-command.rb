# Historical evidence only. Do not execute: the one-run budget is consumed.
# Copied from root's executed ruby -e tool invocation after focused1 finished,
# for independent lifecycle review; not a pre-execution frozen runner artifact.
# Invocation loaded json,digest,open3,tmpdir,time with ruby -r flags.
STDOUT.sync=true
td="docs/collaboration/tasks/2026-09-05-desktop-coding-closure"
dest="#{td}/runtime-halt-gate-focused1-result.json"
abort "focused1 already recorded; no retry" if File.exist?(dest)
build=JSON.parse(File.read("#{td}/runtime-halt-gate-build1-result.json"))
abort "build gate not passed" unless build["status"]=="finished" && build["exit"]==0 && build["source_stable"]
binary=build.fetch("binary")
abort "binary drift" unless Digest::SHA256.file(binary).hexdigest==build.fetch("binary_after_sha256")
checker="#{td}/runtime-halt-gate-evidence-check.rb"
abort "checker drift" unless Digest::SHA256.file(checker).hexdigest=="d4c882c2290b772dd7df7f8a4f7310c561860ce8ed8c92010e67164e4c4e6a8c"
helper="/private/tmp/agentloop-child-observer-20260906-94075-n85bj9/observer"
abort "identity helper drift" unless Digest::SHA256.file(helper).hexdigest=="10461c3041954e75b89a3e7d55d57818cc608935ca82bd313aff8e614ae49365"
manifest=-> {(Dir.glob("Sources/**/*")+Dir.glob("scripts/**/*")+%w[Package.swift Package.resolved]).select{|p|File.file?(p)}.sort.map{|p|"#{Digest::SHA256.file(p).hexdigest}  #{p}\n"}.join}
before=manifest.call
abort "source drift" unless Digest::SHA256.hexdigest(before)==build.fetch("source_after_sha256")
raw=Dir.mktmpdir("agentloop-runtime-halt-gate-focused1-")
File.write("#{raw}/source-before.sha256",before)
command=%w[swift run --skip-build RunTests --filter emergencyStopCancelsRunningBeforeWaitingForPlanner]
start=Time.now
pid=Process.spawn({"AGENTLOOP_RUNTIME_DIAGNOSTICS"=>"1"},*command,out:"#{raw}/test.log",err:[:child,:out])
record={raw_directory:raw,cwd:Dir.pwd,command:command,diagnostics_enabled:true,pid:pid,launcher_pid:Process.pid,uid:Process.uid,start:start.iso8601(9),status:"running",binary:binary,binary_sha256:Digest::SHA256.file(binary).hexdigest,source_before_sha256:Digest::SHA256.hexdigest(before)}
File.write(dest,JSON.pretty_generate(record)+"\n")
puts JSON.pretty_generate(record)
identities=[]; identity_errors=[]; target_identity=nil; initial_identity=nil; test_status=nil
100.times do
  out,err,s=Open3.capture3(helper,"--identity",pid.to_s)
  item={at:Time.now.iso8601(9),stdout:out,stderr:err,exit:s.exitstatus,signal:s.termsig}
  File.open("#{raw}/identity.ndjson","a"){|f|f.puts(JSON.generate(item))}
  row=JSON.parse(out)
  unless s.success? && err.empty? && row["status"]==0 && row["pid"]==pid && row["ppid"]==Process.pid && row["uid"]==Process.uid
    identity_errors << "identity handshake failed"
    break
  end
  initial_identity ||= row
  unless %w[pid ppid uid start_sec start_usec].all?{|k|row.fetch(k)==initial_identity.fetch(k)}
    identity_errors << "generation drift"
    break
  end
  identities << row
  if row["path"]==binary
    target_identity=row
    break
  end
  waited=Process.wait2(pid,Process::WNOHANG)
  if waited
    test_status=waited[1]
    break
  end
  sleep 0.02
end
unless test_status
  _,test_status=Process.wait2(pid)
end
finish=Time.now
identity_errors << "no live RunTests image identity" unless target_identity
if initial_identity
  birth=initial_identity.fetch("start_sec")*1_000_000+initial_identity.fetch("start_usec")
  identity_errors << "birth outside fresh invocation" unless birth >= (start.to_r*1_000_000).floor && birth <= (finish.to_r*1_000_000).ceil
end
record.merge!(end:finish.iso8601(9),wall_seconds:finish-start,test_exit:test_status.exitstatus,test_signal:test_status.termsig,initial_identity:initial_identity,runtests_identity:target_identity,identity_observations:identities.size,identity_errors:identity_errors,status:"test_finished_collecting")
File.write(dest,JSON.pretty_generate(record)+"\n")
predicate="processIdentifier == #{pid} AND subsystem == \"com.muzi.agentloop\" AND category == \"runtime-lifecycle\""
log_command=["/usr/bin/log","show","--style","ndjson","--last","10m","--predicate",predicate]
horizon=Time.now-600 <= start
log_pid=Process.spawn(*log_command,out:"#{raw}/events.ndjson",err:"#{raw}/events.stderr.log")
_,log_status=Process.wait2(log_pid)
rows=[]; parse_errors=[]
File.readlines("#{raw}/events.ndjson").each_with_index do |line,i|
  next if line.strip.empty?
  begin
    rows << JSON.parse(line)
  rescue JSON::ParserError => e
    parse_errors << {line:i+1,error:e.message}
  end
end
events=rows.select{|e|e.key?("eventMessage")}
metadata=rows.reject{|e|e.key?("eventMessage")}
admitted=[]; rejected=[]
events.each_with_index do |e,i|
  reason=nil
  if e["processID"]!=pid || e["userID"]!=Process.uid || e["processImagePath"]!=binary || e["senderImagePath"]!=binary || e["subsystem"]!="com.muzi.agentloop" || e["category"]!="runtime-lifecycle"
    reason="identity_or_image_mismatch"
  elsif !e["timestamp"].is_a?(String) || !e["timestamp"].match?(/(Z|[+-]\d{2}:?\d{2})\z/)
    reason="missing_absolute_timestamp"
  else
    begin
      instant=Time.parse(e["timestamp"])
      reason="outside_invocation" unless instant>=start && instant<=finish
    rescue ArgumentError
      reason="timestamp_parse_error"
    end
  end
  reason ? rejected << {index:i,reason:reason} : admitted << e
end
File.write("#{raw}/events-admitted.ndjson",admitted.map{|e|JSON.generate(e)+"\n"}.join)
metadata_ok=metadata.length==1 && metadata[0]["count"]==events.length && metadata[0]["finished"]==1
scope_ok=horizon && log_status.success? && File.size("#{raw}/events.stderr.log")==0 && parse_errors.empty? && rejected.empty? && !admitted.empty? && metadata_ok && identity_errors.empty?
record[:oslog]={command:log_command,pid:log_pid,exit:log_status.exitstatus,signal:log_status.termsig,horizon_covers_invocation:horizon,raw_event_count:events.length,admitted:admitted.size,rejected:rejected,parse_errors:parse_errors,metadata:metadata,scope_ok:scope_ok}
if scope_ok
  checker_command=["ruby",checker,"#{raw}/test.log","#{raw}/events-admitted.ndjson",pid.to_s]
  out,err,s=Open3.capture3(*checker_command)
  File.write("#{raw}/checker.stdout.log",out)
  File.write("#{raw}/checker.stderr.log",err)
  record[:checker]={command:checker_command,exit:s.exitstatus,signal:s.termsig}
else
  record[:checker]={skipped:"scope gate failed; no empty or ambiguous GREEN"}
end
after=manifest.call
File.write("#{raw}/source-after.sha256",after)
record.merge!(status:"finished",source_after_sha256:Digest::SHA256.hexdigest(after),source_stable:before==after,binary_after_sha256:Digest::SHA256.file(binary).hexdigest)
record[:raw_file_hashes]=Dir.glob("#{raw}/*").select{|p|File.file?(p)}.sort.to_h{|p|[File.basename(p),Digest::SHA256.file(p).hexdigest]}
File.write(dest,JSON.pretty_generate(record)+"\n")
puts JSON.pretty_generate(record)
exit(test_status.success? && scope_ok && record[:checker][:exit]==0 && before==after ? 0 : 1)
