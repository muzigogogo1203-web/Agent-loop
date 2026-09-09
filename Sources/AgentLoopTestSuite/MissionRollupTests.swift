import Testing
import AgentLoopCore

@Test func rollupEmptyCardsIsPlanning() {
    #expect(MissionStatus.rollup(current: .planning, cards: []) == .planning)
}

@Test func rollupMixedIsExecuting() {
    #expect(MissionStatus.rollup(current: .executing, cards: [.done, .blocked]) == .executing)
    #expect(MissionStatus.rollup(current: .planning, cards: [.canceled, .todo]) == .executing)
}

@Test func rollupAllTerminalWithDoneIsDelivering() {
    #expect(MissionStatus.rollup(current: .executing, cards: [.done]) == .delivering)
    #expect(MissionStatus.rollup(current: .executing, cards: [.canceled, .done]) == .delivering)
}

@Test func rollupAllTerminalZeroDoneIsFailed() {
    #expect(MissionStatus.rollup(current: .executing, cards: [.canceled]) == .failed)
}

@Test func rollupAcceptedReworkResumesExecutingAndFailedRemainsSticky() {
    #expect(MissionStatus.rollup(current: .accepted, cards: [.todo]) == .executing)
    #expect(MissionStatus.rollup(current: .accepted, cards: [.done]) == .accepted)
    #expect(MissionStatus.rollup(current: .failed, cards: [.done]) == .failed)
}
