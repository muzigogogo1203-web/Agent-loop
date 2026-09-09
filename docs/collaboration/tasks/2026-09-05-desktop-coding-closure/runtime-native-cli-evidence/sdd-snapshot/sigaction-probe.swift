import Darwin
import Foundation

func checkStandardSigaction() -> Int32 {
    var action = sigaction()
    return sigaction(SIGTERM, &action, nil)
}
