import AppKit
import SwiftUI

enum RanchArtKind {
    case barn
    case base
    case panorama
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
                .interpolation(.none)
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
        let subject: String
        switch kind {
        case .barn:
            subject = "Barn"
        case .base:
            subject = "Pasture"
        case .panorama:
            subject = "Panorama"
        }
        let appearance = colorScheme == .dark ? "Night" : "Day"
        return "Pixel\(subject)\(appearance)"
    }

    @MainActor static func image(named name: String) -> NSImage? {
        image(named: name, withExtension: "png")
    }

    @MainActor static func spriteImage(colorName: String) -> NSImage? {
        guard let suffix = spriteSuffix(colorName: colorName) else { return nil }
        return image(named: "PixelCowSide\(suffix)", withExtension: "png")
    }

    @MainActor static func sleepSpriteImage(colorName: String) -> NSImage? {
        guard let suffix = spriteSuffix(colorName: colorName) else { return nil }
        return image(named: "PixelCowSleep\(suffix)", withExtension: "png")
    }

    private static func spriteSuffix(colorName: String) -> String? {
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
        return suffix
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

struct RanchBarnView: View {
    let cows: [(id: String, name: String, colorName: String)]
    let lockedCow: (name: String, canUnlock: Bool)?
    let maxWidth: CGFloat?
    var onSelectCow: ((String) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredCowID: String?

    private static let stallXPositions: [CGFloat] = [0.13, 0.385, 0.64, 0.895]
    private static let stallYPosition: CGFloat = 0.77

    @ViewBuilder var body: some View {
        if let image = RanchArtView.image(named: resourceName) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: maxWidth)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
                .overlay {
                    GeometryReader { proxy in
                        ZStack(alignment: .bottomTrailing) {
                            ForEach(Array(cows.prefix(4).enumerated()), id: \.element.id) { index, cow in
                                if let sprite = RanchArtView.sleepSpriteImage(colorName: cow.colorName) {
                                    occupiedCowStall(
                                        cow: cow,
                                        sprite: sprite,
                                        width: proxy.size.width,
                                        height: proxy.size.height
                                    )
                                        .position(
                                            x: proxy.size.width * Self.stallXPositions[index],
                                            y: proxy.size.height * Self.stallYPosition
                                        )
                                }
                            }

                            if cows.count < 4,
                               let lockedCow,
                               let sprite = RanchArtView.sleepSpriteImage(colorName: "amber") {
                                lockedCowStall(
                                    sprite: sprite,
                                    canUnlock: lockedCow.canUnlock,
                                    width: proxy.size.width,
                                    height: proxy.size.height
                                )
                                    .position(
                                        x: proxy.size.width * Self.stallXPositions[3],
                                        y: proxy.size.height * Self.stallYPosition
                                    )
                            }

                            if cows.count > 4 {
                                CampChip(text: "+\(cows.count - 4) 只在外放牧", color: Camp.amber)
                                    .padding(10)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomTrailing)
                    }
                }
        }
    }

    private var resourceName: String {
        colorScheme == .dark ? "PixelBarnNight" : "PixelBarnDay"
    }

    @ViewBuilder private func occupiedCowStall(
        cow: (id: String, name: String, colorName: String),
        sprite: NSImage,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        if let onSelectCow {
            Button {
                onSelectCow(cow.id)
            } label: {
                cowStallContent(
                    name: cow.name,
                    sprite: sprite,
                    width: width,
                    height: height,
                    hovering: hoveredCowID == cow.id
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredCowID = hovering ? cow.id : nil
            }
            .help("查看 \(cow.name) 的档案")
        } else {
            cowStallContent(
                name: cow.name,
                sprite: sprite,
                width: width,
                height: height,
                hovering: false
            )
        }
    }

    private func cowStallContent(
        name: String,
        sprite: NSImage,
        width: CGFloat,
        height: CGFloat,
        hovering: Bool
    ) -> some View {
        GeometryReader { proxy in
            Image(nsImage: sprite)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: width * 0.17)
                .scaleEffect(hovering && !reduceMotion ? 1.04 : 1)
                .shadow(
                    color: .black.opacity(hovering ? 0.18 : 0),
                    radius: hovering ? 7 : 0,
                    y: 2
                )
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.42)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: hovering)

            woodenPlaque(name)
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.895)
        }
        .frame(width: width * 0.22, height: height * 0.38)
        .contentShape(Rectangle())
    }

    private func lockedCowStall(
        sprite: NSImage,
        canUnlock: Bool,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Image(nsImage: sprite)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: width * 0.17)
                    .grayscale(canUnlock ? 0 : 1)
                    .opacity(canUnlock ? 1 : 0.5)

                if canUnlock {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Camp.moss, in: Circle())
                }
            }
            .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.42)

            woodenPlaque(canUnlock ? "可以领回" : "学习中")
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.895)
        }
        .frame(width: width * 0.22, height: height * 0.38)
    }

    private func woodenPlaque(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(Camp.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Camp.hay, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Camp.line, lineWidth: 1)
            )
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
                    .frame(width: height * 0.70, height: height * 0.10)
                    .offset(y: height * 0.46)
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: height)
                    // PixelCowSide sprites face left natively; flip only to face right.
                    .scaleEffect(x: flipped ? -1 : 1)
            }
            .frame(height: height)
            .accessibilityHidden(true)
        }
    }
}
