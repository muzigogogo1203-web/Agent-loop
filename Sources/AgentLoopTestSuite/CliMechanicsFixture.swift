import Darwin
import Foundation
import MachO

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

private enum CliMechanicsFixtureResolutionError: Error,
    CustomStringConvertible
{
    case invalidCurrentRunner
    case invalidFixtureArtifact(String)
    case systemCall(String, Int32)

    var description: String {
        switch self {
        case .invalidCurrentRunner:
            return "current RunTests executable identity is invalid"
        case .invalidFixtureArtifact(let detail):
            return "CliMechanicsFixtureRunner artifact is invalid: \(detail)"
        case .systemCall(let operation, let code):
            return "CliMechanicsFixtureRunner \(operation) failed errno=\(code)"
        }
    }
}

func cliMechanicsFixtureExecutableURL() throws -> URL {
    guard let firstArgument = CommandLine.arguments.first,
          !firstArgument.isEmpty
    else {
        throw CliMechanicsFixtureResolutionError.invalidCurrentRunner
    }

    let currentRunner = URL(fileURLWithPath: firstArgument)
        .resolvingSymlinksInPath()
        .standardizedFileURL
    var runnerInformation = stat()
    let runnerResult = currentRunner.path.withCString {
        Darwin.lstat($0, &runnerInformation)
    }
    guard runnerResult == 0,
          runnerInformation.st_mode & S_IFMT == S_IFREG,
          runnerInformation.st_uid == getuid(),
          runnerInformation.st_nlink == 1,
          runnerInformation.st_mode & S_IXUSR != 0
    else {
        throw CliMechanicsFixtureResolutionError.invalidCurrentRunner
    }

    let sibling = currentRunner.deletingLastPathComponent()
        .appendingPathComponent("CliMechanicsFixtureRunner")
        .standardizedFileURL
    guard sibling.lastPathComponent == "CliMechanicsFixtureRunner",
          sibling.deletingLastPathComponent()
            == currentRunner.deletingLastPathComponent()
    else {
        throw CliMechanicsFixtureResolutionError.invalidFixtureArtifact(
            "artifact is not the exact RunTests sibling"
        )
    }

    try cliMechanicsValidateFixtureArtifact(sibling)
    return sibling
}

private func cliMechanicsValidateFixtureArtifact(_ url: URL) throws {
    var pathInformation = stat()
    let pathResult = url.path.withCString {
        Darwin.lstat($0, &pathInformation)
    }
    guard pathResult == 0 else {
        throw CliMechanicsFixtureResolutionError.systemCall(
            "artifact lstat", errno
        )
    }
    try cliMechanicsRequireFixtureIdentity(pathInformation)

    var descriptor = url.path.withCString {
        Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    }
    guard descriptor >= 0 else {
        throw CliMechanicsFixtureResolutionError.systemCall(
            "artifact open", errno
        )
    }

    do {
        var openedInformation = stat()
        guard Darwin.fstat(descriptor, &openedInformation) == 0 else {
            throw CliMechanicsFixtureResolutionError.systemCall(
                "artifact fstat", errno
            )
        }
        try cliMechanicsRequireFixtureIdentity(openedInformation)
        guard cliMechanicsSameFixtureIdentity(
            pathInformation, openedInformation
        ) else {
            throw CliMechanicsFixtureResolutionError.invalidFixtureArtifact(
                "artifact identity changed while opening"
            )
        }

        var header = [UInt8](repeating: 0, count: 16)
        var offset = 0
        while offset < header.count {
            let count = header.withUnsafeMutableBytes { bytes in
                Darwin.pread(
                    descriptor,
                    bytes.baseAddress!.advanced(by: offset),
                    bytes.count - offset,
                    off_t(offset)
                )
            }
            if count > 0 {
                offset += count
                continue
            }
            if count < 0, errno == EINTR { continue }
            if count == 0 {
                throw CliMechanicsFixtureResolutionError
                    .invalidFixtureArtifact("truncated Mach-O header")
            }
            throw CliMechanicsFixtureResolutionError.systemCall(
                "artifact header read", errno
            )
        }

        let magic = header.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        let rawFileType = header.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 12, as: UInt32.self)
        }
        let fileType: UInt32
        switch magic {
        case UInt32(MH_MAGIC), UInt32(MH_MAGIC_64):
            fileType = rawFileType
        case UInt32(MH_CIGAM), UInt32(MH_CIGAM_64):
            fileType = rawFileType.byteSwapped
        default:
            throw CliMechanicsFixtureResolutionError
                .invalidFixtureArtifact("artifact is not a Mach-O image")
        }
        guard fileType == UInt32(MH_EXECUTE) else {
            throw CliMechanicsFixtureResolutionError
                .invalidFixtureArtifact("Mach-O image is not executable")
        }

        var finalInformation = stat()
        guard Darwin.fstat(descriptor, &finalInformation) == 0 else {
            throw CliMechanicsFixtureResolutionError.systemCall(
                "artifact final fstat", errno
            )
        }
        guard cliMechanicsSameFixtureIdentity(
            openedInformation, finalInformation
        ) else {
            throw CliMechanicsFixtureResolutionError.invalidFixtureArtifact(
                "artifact identity changed while validating"
            )
        }
        try cliMechanicsCloseFixtureDescriptor(&descriptor)
    } catch {
        if descriptor >= 0 {
            do {
                try cliMechanicsCloseFixtureDescriptor(&descriptor)
            } catch let closeError {
                throw CliMechanicsFixtureResolutionError
                    .invalidFixtureArtifact(
                        "validation failed [\(error)]; close failed [\(closeError)]"
                    )
            }
        }
        throw error
    }
}

private func cliMechanicsRequireFixtureIdentity(_ information: stat) throws {
    guard information.st_mode & S_IFMT == S_IFREG else {
        throw CliMechanicsFixtureResolutionError
            .invalidFixtureArtifact("artifact is not a regular file")
    }
    guard information.st_uid == getuid() else {
        throw CliMechanicsFixtureResolutionError
            .invalidFixtureArtifact("artifact is not owned by the current uid")
    }
    guard information.st_nlink == 1 else {
        throw CliMechanicsFixtureResolutionError
            .invalidFixtureArtifact("artifact link count is not one")
    }
    guard information.st_mode & S_IXUSR != 0 else {
        throw CliMechanicsFixtureResolutionError
            .invalidFixtureArtifact("artifact is not user-executable")
    }
    guard information.st_mode & mode_t(S_IWGRP | S_IWOTH) == 0 else {
        throw CliMechanicsFixtureResolutionError.invalidFixtureArtifact(
            "artifact is group- or world-writable"
        )
    }
}

private func cliMechanicsSameFixtureIdentity(
    _ lhs: stat,
    _ rhs: stat
) -> Bool {
    lhs.st_dev == rhs.st_dev
        && lhs.st_ino == rhs.st_ino
        && lhs.st_uid == rhs.st_uid
        && lhs.st_nlink == rhs.st_nlink
        && lhs.st_mode == rhs.st_mode
        && lhs.st_size == rhs.st_size
        && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
        && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
}

private func cliMechanicsCloseFixtureDescriptor(
    _ descriptor: inout Int32
) throws {
    let owned = descriptor
    descriptor = -1
    guard Darwin.close(owned) == 0 else {
        throw CliMechanicsFixtureResolutionError.systemCall(
            "artifact close", errno
        )
    }
}
