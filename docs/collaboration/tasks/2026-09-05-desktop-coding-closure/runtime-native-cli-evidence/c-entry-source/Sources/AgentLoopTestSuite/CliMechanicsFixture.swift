import Darwin
import Foundation

let cliMechanicsFixtureSwitch = "--agentloop-cli-mechanics-fixture"

enum CliMechanicsFixtureMode: String {
    case exitZero = "exit-zero"
    case printFinalLine = "print-final-line"
    case waitTerm = "wait-term"
    case ignoreTerm = "ignore-term"
    case readyFileIgnoreTerm = "ready-file-ignore-term"
    case readyFile = "ready-file"
    case readyAndDrainIgnoreTerm = "ready-and-drain-ignore-term"
    case heldStderrParent = "held-stderr-parent"
    case heldStderrChild = "held-stderr-child"
    case environmentSentinel = "environment-sentinel"
}

private enum CliMechanicsNativeFixtureError: Error, CustomStringConvertible {
    case invalidArguments
    case systemCall(String, Int32)
    case invalidReadinessAuthority
    case invalidEnvironment
    case childProcessGroup
    case childAcknowledgement
    case cleanup(primary: String, failures: [String])

    var description: String {
        switch self {
        case .invalidArguments:
            return "invalid fixture arguments"
        case let .systemCall(operation, code):
            return "fixture \(operation) failed errno=\(code)"
        case .invalidReadinessAuthority:
            return "fixture readiness authority is invalid"
        case .invalidEnvironment:
            return "fixture environment sentinel is invalid"
        case .childProcessGroup:
            return "fixture child did not inherit the parent process group"
        case .childAcknowledgement:
            return "fixture child acknowledgement was invalid"
        case let .cleanup(primary, failures):
            return "fixture failure primary=[\(primary)] cleanup=[\(failures.joined(separator: "; "))]"
        }
    }
}

func cliMechanicsCurrentRunnerURL() throws -> URL {
    guard let first = CommandLine.arguments.first, !first.isEmpty else {
        throw CliMechanicsNativeFixtureError.invalidArguments
    }
    let url = URL(fileURLWithPath: first).resolvingSymlinksInPath()
        .standardizedFileURL
    var info = stat()
    let result = url.path.withCString { Darwin.lstat($0, &info) }
    guard result == 0,
          info.st_mode & S_IFMT == S_IFREG,
          info.st_uid == getuid(),
          info.st_nlink == 1,
          info.st_mode & S_IXUSR != 0
    else {
        throw CliMechanicsNativeFixtureError.systemCall(
            "current runner identity", result == 0 ? EINVAL : errno
        )
    }
    return url
}

public func runCliMechanicsFixtureIfRequested() {
    let arguments = CommandLine.arguments
    guard arguments.count >= 2, arguments[1] == cliMechanicsFixtureSwitch else {
        return
    }
    do {
        try runCliMechanicsFixture(arguments: Array(arguments.dropFirst(2)))
        Darwin.exit(EXIT_SUCCESS)
    } catch {
        let message = "AgentLoop CLI mechanics fixture: \(error)\n"
        try? cliMechanicsWrite(Data(message.utf8), to: STDERR_FILENO)
        Darwin.exit(64)
    }
}

private func runCliMechanicsFixture(arguments: [String]) throws {
    guard let rawMode = arguments.first,
          let mode = CliMechanicsFixtureMode(rawValue: rawMode)
    else { throw CliMechanicsNativeFixtureError.invalidArguments }
    let trailing = Array(arguments.dropFirst())

    switch mode {
    case .exitZero:
        try requireNoArguments(trailing)
        try cliMechanicsDrainStdin()
    case .printFinalLine:
        try requireNoArguments(trailing)
        try cliMechanicsDrainStdin()
        try cliMechanicsWrite(Data("final-line".utf8), to: STDOUT_FILENO)
    case .waitTerm:
        try requireNoArguments(trailing)
        try cliMechanicsDrainStdin()
        try cliMechanicsWrite(Data("ready\n".utf8), to: STDOUT_FILENO)
        try cliMechanicsWaitForever()
    case .ignoreTerm:
        try requireNoArguments(trailing)
        try cliMechanicsIgnoreTerm()
        try cliMechanicsDrainStdin()
        try cliMechanicsWrite(Data("ready\n".utf8), to: STDOUT_FILENO)
        try cliMechanicsWaitForever()
    case .readyFileIgnoreTerm:
        try cliMechanicsIgnoreTerm()
        try cliMechanicsDrainStdin()
        try cliMechanicsCreateReadyFile(arguments: trailing)
        try cliMechanicsWaitForever()
    case .readyFile:
        // The backend creates its stdin writer only after the inspector's
        // synchronous SIGCONT call returns, so readiness must precede draining.
        try cliMechanicsCreateReadyFile(arguments: trailing)
        try cliMechanicsWaitForever()
    case .readyAndDrainIgnoreTerm:
        try requireNoArguments(trailing)
        try cliMechanicsIgnoreTerm()
        try cliMechanicsDrainStdin()
        try cliMechanicsWrite(Data("p1f1d-ready\n".utf8), to: STDOUT_FILENO)
        try cliMechanicsWrite(Data("p1f1d-drain\n".utf8), to: STDERR_FILENO)
        try cliMechanicsWaitForever()
    case .heldStderrParent:
        try requireNoArguments(trailing)
        try cliMechanicsDrainStdin()
        try cliMechanicsRunHeldStderrParent()
    case .heldStderrChild:
        try cliMechanicsRunHeldStderrChild(arguments: trailing)
    case .environmentSentinel:
        try requireNoArguments(trailing)
        try cliMechanicsDrainStdin()
        try cliMechanicsReportEnvironmentSentinel()
    }
}

private func requireNoArguments(_ arguments: [String]) throws {
    guard arguments.isEmpty else {
        throw CliMechanicsNativeFixtureError.invalidArguments
    }
}

private func cliMechanicsDrainStdin() throws {
    var bytes = [UInt8](repeating: 0, count: 4_096)
    while true {
        let count = bytes.withUnsafeMutableBytes {
            Darwin.read(STDIN_FILENO, $0.baseAddress, $0.count)
        }
        if count > 0 { continue }
        if count == 0 { return }
        if errno == EINTR { continue }
        throw CliMechanicsNativeFixtureError.systemCall("stdin read", errno)
    }
}

private func cliMechanicsWrite(_ data: Data, to descriptor: Int32) throws {
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let result = Darwin.write(
                descriptor,
                bytes.baseAddress!.advanced(by: offset),
                bytes.count - offset
            )
            if result > 0 {
                offset += result
                continue
            }
            if result < 0, errno == EINTR { continue }
            throw CliMechanicsNativeFixtureError.systemCall("write", errno)
        }
    }
}

private func cliMechanicsIgnoreTerm() throws {
    var action = sigaction()
    action.__sigaction_u.__sa_handler = SIG_IGN
    action.sa_flags = 0
    guard sigemptyset(&action.sa_mask) == 0,
          sigaction(SIGTERM, &action, nil) == 0 else {
        throw CliMechanicsNativeFixtureError.systemCall("signal", errno)
    }
}

private func cliMechanicsWaitForever() throws -> Never {
    while true {
        if Darwin.pause() == -1, errno == EINTR { continue }
        throw CliMechanicsNativeFixtureError.systemCall("pause", errno)
    }
}

private func cliMechanicsCreateReadyFile(arguments: [String]) throws {
    guard arguments.count == 2 else {
        throw CliMechanicsNativeFixtureError.invalidArguments
    }
    let root = URL(fileURLWithPath: arguments[0], isDirectory: true)
        .standardizedFileURL
    let leaf = arguments[1]
    let readyURL = root.appendingPathComponent(leaf).standardizedFileURL
    let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        .standardizedFileURL
    let currentDirectory = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true
    ).resolvingSymlinksInPath().standardizedFileURL
    guard root.path.hasPrefix("/tmp/al65-"),
          currentDirectory.path
            == workspace.resolvingSymlinksInPath().standardizedFileURL.path,
          readyURL.deletingLastPathComponent().path == root.path,
          ["cold-ready", "resume-ready"].contains(leaf)
    else { throw CliMechanicsNativeFixtureError.invalidReadinessAuthority }

    var rootFD: Int32 = -1
    var readyFD: Int32 = -1
    do {
        rootFD = root.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard rootFD >= 0 else {
            throw CliMechanicsNativeFixtureError.systemCall(
                "readiness root open", errno
            )
        }
        var rootInfo = stat()
        guard Darwin.fstat(rootFD, &rootInfo) == 0,
              rootInfo.st_mode & S_IFMT == S_IFDIR,
              rootInfo.st_uid == getuid(),
              rootInfo.st_mode & mode_t(0o777) == mode_t(0o700)
        else { throw CliMechanicsNativeFixtureError.invalidReadinessAuthority }
        readyFD = leaf.withCString {
            Darwin.openat(
                rootFD, $0,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                mode_t(0o600)
            )
        }
        guard readyFD >= 0 else {
            throw CliMechanicsNativeFixtureError.systemCall(
                "readiness file open", errno
            )
        }
        if let error = cliMechanicsCloseOwned(
            &readyFD, operation: "readiness file close"
        ) { throw error }
        if let error = cliMechanicsCloseOwned(
            &rootFD, operation: "readiness root close"
        ) { throw error }
    } catch {
        var cleanupFailures: [any Error] = []
        if let failure = cliMechanicsCloseOwned(
            &readyFD, operation: "readiness file cleanup close"
        ) { cleanupFailures.append(failure) }
        if let failure = cliMechanicsCloseOwned(
            &rootFD, operation: "readiness root cleanup close"
        ) { cleanupFailures.append(failure) }
        try cliMechanicsThrow(error, cleanupFailures: cleanupFailures)
    }
}

private func cliMechanicsRunHeldStderrParent() throws {
    var pipeFDs: [Int32] = [-1, -1]
    guard Darwin.pipe(&pipeFDs) == 0 else {
        throw CliMechanicsNativeFixtureError.systemCall("ack pipe", errno)
    }
    var readFD = pipeFDs[0]
    var writeFD = pipeFDs[1]
    var actions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?
    var actionsInitialized = false
    var attributesInitialized = false
    var child: pid_t = 0
    var ownsChild = false
    do {
        let childAckFD = Int32(3)
        try cliMechanicsNormalizeOwnedDescriptor(
            &readFD, minimum: childAckFD + 1
        )
        try cliMechanicsNormalizeOwnedDescriptor(
            &writeFD, minimum: childAckFD + 1
        )
        var code = posix_spawn_file_actions_init(&actions)
        guard code == 0 else {
            throw CliMechanicsNativeFixtureError.systemCall(
                "spawn actions init", code
            )
        }
        actionsInitialized = true
        try cliMechanicsCheckSpawn(
            posix_spawn_file_actions_addclose(&actions, readFD)
        )
        try "/dev/null".withCString { path in
            try cliMechanicsCheckSpawn(posix_spawn_file_actions_addopen(
                &actions, STDIN_FILENO, path, O_RDONLY, 0
            ))
            try cliMechanicsCheckSpawn(posix_spawn_file_actions_addopen(
                &actions, STDOUT_FILENO, path, O_WRONLY, 0
            ))
        }
        try cliMechanicsCheckSpawn(posix_spawn_file_actions_adddup2(
            &actions, STDERR_FILENO, STDERR_FILENO
        ))
        try cliMechanicsCheckSpawn(posix_spawn_file_actions_adddup2(
            &actions, writeFD, childAckFD
        ))
        try cliMechanicsCheckSpawn(
            posix_spawn_file_actions_addclose(&actions, writeFD)
        )

        code = posix_spawnattr_init(&attributes)
        guard code == 0 else {
            throw CliMechanicsNativeFixtureError.systemCall(
                "spawn attributes init", code
            )
        }
        attributesInitialized = true
        var defaultSignals = sigset_t()
        var signalMask = sigset_t()
        guard sigemptyset(&defaultSignals) == 0,
              sigaddset(&defaultSignals, SIGTERM) == 0,
              sigemptyset(&signalMask) == 0
        else {
            throw CliMechanicsNativeFixtureError.systemCall(
                "spawn signals", errno
            )
        }
        try cliMechanicsCheckSpawn(posix_spawnattr_setsigdefault(
            &attributes, &defaultSignals
        ))
        try cliMechanicsCheckSpawn(
            posix_spawnattr_setsigmask(&attributes, &signalMask)
        )
        try cliMechanicsCheckSpawn(posix_spawnattr_setflags(
            &attributes,
            Int16(
                POSIX_SPAWN_CLOEXEC_DEFAULT
                    | POSIX_SPAWN_SETSIGDEF
                    | POSIX_SPAWN_SETSIGMASK
            )
        ))

        let executable = try cliMechanicsCurrentRunnerURL().path
        var argv = try cliMechanicsCStringVector([
            executable, cliMechanicsFixtureSwitch,
            CliMechanicsFixtureMode.heldStderrChild.rawValue,
            String(childAckFD),
        ])
        defer { cliMechanicsFreeCStringVector(argv) }
        var envp = try cliMechanicsCStringVector([
            "LC_ALL=C", "PATH=/usr/bin:/bin",
        ])
        defer { cliMechanicsFreeCStringVector(envp) }
        code = executable.withCString { path in
            argv.withUnsafeMutableBufferPointer { argvBuffer in
                envp.withUnsafeMutableBufferPointer { envBuffer in
                    posix_spawn(
                        &child, path, &actions, &attributes,
                        argvBuffer.baseAddress, envBuffer.baseAddress
                    )
                }
            }
        }
        guard code == 0 else {
            throw CliMechanicsNativeFixtureError.systemCall(
                "spawn held child", code
            )
        }
        ownsChild = true
        let teardownFailures = cliMechanicsReleaseSpawnStructures(
            actions: &actions,
            actionsInitialized: &actionsInitialized,
            attributes: &attributes,
            attributesInitialized: &attributesInitialized
        )
        if let primary = teardownFailures.first {
            try cliMechanicsThrow(
                primary,
                cleanupFailures: Array(teardownFailures.dropFirst())
            )
        }
        if let error = cliMechanicsCloseOwned(
            &writeFD, operation: "parent ack write close"
        ) { throw error }
        let acknowledgement = try cliMechanicsReadAcknowledgement(from: readFD)
        guard acknowledgement == 0x41 else {
            throw CliMechanicsNativeFixtureError.childAcknowledgement
        }
        guard Darwin.getpgid(child) == Darwin.getpgrp() else {
            throw CliMechanicsNativeFixtureError.childProcessGroup
        }
        if let error = cliMechanicsCloseOwned(
            &readFD, operation: "parent ack read close"
        ) { throw error }
        try cliMechanicsWrite(Data("parent-exited\n".utf8), to: STDOUT_FILENO)
        ownsChild = false
    } catch {
        var cleanupFailures = cliMechanicsReleaseSpawnStructures(
            actions: &actions,
            actionsInitialized: &actionsInitialized,
            attributes: &attributes,
            attributesInitialized: &attributesInitialized
        )
        if ownsChild {
            do {
                try cliMechanicsTerminateOwnedChild(child)
                ownsChild = false
            } catch {
                cleanupFailures.append(error)
            }
        }
        if let failure = cliMechanicsCloseOwned(
            &readFD, operation: "parent ack read cleanup close"
        ) { cleanupFailures.append(failure) }
        if let failure = cliMechanicsCloseOwned(
            &writeFD, operation: "parent ack write cleanup close"
        ) { cleanupFailures.append(failure) }
        try cliMechanicsThrow(error, cleanupFailures: cleanupFailures)
    }
}

private func cliMechanicsNormalizeOwnedDescriptor(
    _ descriptor: inout Int32,
    minimum: Int32
) throws {
    guard descriptor >= 0 else {
        throw CliMechanicsNativeFixtureError.systemCall("ack descriptor", EBADF)
    }
    if descriptor >= minimum {
        guard Darwin.fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
            throw CliMechanicsNativeFixtureError.systemCall("ack cloexec", errno)
        }
        return
    }
    let original = descriptor
    let duplicate = Darwin.fcntl(original, F_DUPFD_CLOEXEC, minimum)
    guard duplicate >= minimum else {
        throw CliMechanicsNativeFixtureError.systemCall("ack duplicate", errno)
    }
    descriptor = duplicate
    guard Darwin.close(original) == 0 else {
        throw CliMechanicsNativeFixtureError.systemCall("ack original close", errno)
    }
}

private func cliMechanicsRunHeldStderrChild(arguments: [String]) throws -> Never {
    guard arguments.count == 1,
          let descriptor = Int32(arguments[0]), descriptor == 3,
          Darwin.fcntl(descriptor, F_GETFD) >= 0
    else { throw CliMechanicsNativeFixtureError.invalidArguments }
    try cliMechanicsWrite(Data([0x41]), to: descriptor)
    guard Darwin.close(descriptor) == 0 else {
        throw CliMechanicsNativeFixtureError.systemCall("child ack close", errno)
    }
    try cliMechanicsWaitForever()
}

private func cliMechanicsCloseOwned(
    _ descriptor: inout Int32,
    operation: String
) -> (any Error)? {
    guard descriptor >= 0 else { return nil }
    let owned = descriptor
    descriptor = -1
    guard Darwin.close(owned) == 0 else {
        return CliMechanicsNativeFixtureError.systemCall(operation, errno)
    }
    return nil
}

private func cliMechanicsReleaseSpawnStructures(
    actions: inout posix_spawn_file_actions_t?,
    actionsInitialized: inout Bool,
    attributes: inout posix_spawnattr_t?,
    attributesInitialized: inout Bool
) -> [any Error] {
    var failures: [any Error] = []
    if attributesInitialized {
        attributesInitialized = false
        let code = posix_spawnattr_destroy(&attributes)
        if code != 0 {
            failures.append(CliMechanicsNativeFixtureError.systemCall(
                "spawn attributes destroy", code
            ))
        }
    }
    if actionsInitialized {
        actionsInitialized = false
        let code = posix_spawn_file_actions_destroy(&actions)
        if code != 0 {
            failures.append(CliMechanicsNativeFixtureError.systemCall(
                "spawn actions destroy", code
            ))
        }
    }
    return failures
}

private func cliMechanicsThrow(
    _ primary: any Error,
    cleanupFailures: [any Error]
) throws -> Never {
    guard !cleanupFailures.isEmpty else { throw primary }
    throw CliMechanicsNativeFixtureError.cleanup(
        primary: String(describing: primary),
        failures: cleanupFailures.map { String(describing: $0) }
    )
}

private func cliMechanicsTerminateOwnedChild(_ child: pid_t) throws {
    if Darwin.kill(child, SIGKILL) != 0, errno != ESRCH {
        throw CliMechanicsNativeFixtureError.systemCall("child kill", errno)
    }
    var status: Int32 = 0
    while true {
        let result = Darwin.waitpid(child, &status, 0)
        if result == child { return }
        if result < 0, errno == EINTR { continue }
        if result < 0, errno == ECHILD { return }
        throw CliMechanicsNativeFixtureError.systemCall("child reap", errno)
    }
}

private func cliMechanicsReadAcknowledgement(from descriptor: Int32) throws -> UInt8 {
    var acknowledgement: UInt8 = 0
    while true {
        let count = withUnsafeMutableBytes(of: &acknowledgement) { bytes in
            Darwin.read(descriptor, bytes.baseAddress, 1)
        }
        if count == 1 { return acknowledgement }
        if count < 0, errno == EINTR { continue }
        if count == 0 { throw CliMechanicsNativeFixtureError.childAcknowledgement }
        throw CliMechanicsNativeFixtureError.systemCall("ack read", errno)
    }
}

private func cliMechanicsReportEnvironmentSentinel() throws {
    func value(_ key: String) -> String? {
        key.withCString { keyPointer in
            guard let raw = getenv(keyPointer) else { return nil }
            return String(cString: raw)
        }
    }
    guard let sentinel = value("AGENTLOOP_FIXTURE_SENTINEL"),
          sentinel == "present" else {
        throw CliMechanicsNativeFixtureError.invalidEnvironment
    }
    let report = "environment-sentinel=present;path=\(value("PATH") == "/usr/bin:/bin" ? 1 : 0);locale=\(value("LC_ALL") == "C" ? 1 : 0);home=\(value("HOME") == nil ? 0 : 1);tmpdir=\(value("TMPDIR") == nil ? 0 : 1)\n"
    try cliMechanicsWrite(Data(report.utf8), to: STDOUT_FILENO)
}

private func cliMechanicsCheckSpawn(_ code: Int32) throws {
    guard code == 0 else {
        throw CliMechanicsNativeFixtureError.systemCall("spawn setup", code)
    }
}

private func cliMechanicsCStringVector(
    _ strings: [String]
) throws -> [UnsafeMutablePointer<CChar>?] {
    var result: [UnsafeMutablePointer<CChar>?] = []
    result.reserveCapacity(strings.count + 1)
    for string in strings {
        guard let pointer = strdup(string) else {
            cliMechanicsFreeCStringVector(result)
            throw CliMechanicsNativeFixtureError.systemCall("argv allocation", ENOMEM)
        }
        result.append(pointer)
    }
    result.append(nil)
    return result
}

private func cliMechanicsFreeCStringVector(
    _ vector: [UnsafeMutablePointer<CChar>?]
) {
    for case let pointer? in vector { free(pointer) }
}
