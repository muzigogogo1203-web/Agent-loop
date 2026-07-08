import Testing
import Foundation
import AgentLoopCore

// M6-D12：向导默认模型收敛为 KernelDefaults 常量（原先散落 AppDatabase 两处字面量）

@Test func guideModelUsesKernelDefault() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let db = try AppDatabase(path: dir.appendingPathComponent("t.sqlite").path)

    // 默认营地路径
    try db.ensureDefaultCamp()
    let defaultCamp = try #require(try db.camps().first)
    let defaultGuide = try #require(try db.guide(campId: defaultCamp.id))
    #expect(defaultGuide.model == KernelDefaults.defaultGuideModel)

    // 新建营地路径
    let camp = try db.createCamp(name: "北岭")
    let guide = try #require(try db.guide(campId: camp.id))
    #expect(guide.model == KernelDefaults.defaultGuideModel)
}
