import AppKit
import SwiftUI

enum RanchArtKind {
    case barn
    case base
}

enum RanchArtLayout {
    case fit(maxWidth: CGFloat?)
}

struct RanchArtView: View {
    let kind: RanchArtKind
    let layout: RanchArtLayout

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
                .scaledToFit()
                .frame(maxWidth: layoutMaxWidth)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private var layoutMaxWidth: CGFloat? {
        switch layout {
        case .fit(let maxWidth): maxWidth
        }
    }

    private var resourceName: String {
        let subject = kind == .barn ? "Barn" : "Base"
        let appearance = colorScheme == .dark ? "Night" : "Day"
        return "Ranch\(subject)\(appearance)"
    }

    @MainActor private static func image(named name: String) -> NSImage? {
        image(named: name, withExtension: "jpg")
    }

    @MainActor static func spriteImage(colorName: String) -> NSImage? {
        let suffix: String
        switch colorName.lowercased() {
        case "purple": suffix = "Purple"
        case "teal": suffix = "Teal"
        case "coral": suffix = "Coral"
        case "pink": suffix = "Pink"
        case "blue": suffix = "Blue"
        case "green": suffix = "Green"
        case "amber": suffix = "Amber"
        default: return nil
        }
        return image(named: "RanchCow\(suffix)", withExtension: "png")
    }

    @MainActor private static func image(named name: String, withExtension fileExtension: String) -> NSImage? {
        let cacheKey = "\(name).\(fileExtension)"
        if let cachedImage = imageCache[cacheKey] {
            return cachedImage
        }
        guard let url = resourceBundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "RanchArt"
        ), let image = NSImage(contentsOf: url) else {
            return nil
        }
        imageCache[cacheKey] = image
        return image
    }
}

struct RanchCowSpriteView: View {
    let colorName: String
    let height: CGFloat
    let flipped: Bool

    @ViewBuilder var body: some View {
        if let image = RanchArtView.spriteImage(colorName: colorName) {
            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.16))
                    .frame(width: height * 0.55, height: height * 0.10)
                    .offset(y: height * 0.46)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .scaleEffect(x: flipped ? -1 : 1)
            }
            .frame(height: height)
            .accessibilityHidden(true)
        }
    }
}
