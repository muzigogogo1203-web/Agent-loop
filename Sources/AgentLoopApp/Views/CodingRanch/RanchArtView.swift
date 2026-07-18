import AppKit
import SwiftUI

enum RanchArtKind {
    case barn
    case base
}

struct RanchArtView: View {
    let kind: RanchArtKind
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    @MainActor private static var imageCache: [String: NSImage] = [:]
    @MainActor private static let resourceBundle: Bundle = {
        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("AgentLoop_AgentLoopApp.bundle"),
           let bundle = Bundle(url: resourceURL) {
            return bundle
        }
        return Bundle.module
    }()

    @ViewBuilder var body: some View {
        if let image = Self.image(named: resourceName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private var resourceName: String {
        let subject = kind == .barn ? "Barn" : "Base"
        let appearance = colorScheme == .dark ? "Night" : "Day"
        return "Ranch\(subject)\(appearance)"
    }

    @MainActor private static func image(named name: String) -> NSImage? {
        if let cachedImage = imageCache[name] {
            return cachedImage
        }
        guard let url = resourceBundle.url(
            forResource: name,
            withExtension: "jpg",
            subdirectory: "RanchArt"
        ), let image = NSImage(contentsOf: url) else {
            return nil
        }
        imageCache[name] = image
        return image
    }
}
