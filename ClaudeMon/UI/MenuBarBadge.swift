import AppKit

enum MenuBarBadge {
    static let showThreshold = 10  // hide tiny percentages to keep menu bar quiet

    /// Compose a menu-bar template image showing the bolt symbol plus, when
    /// the percentage is non-trivial, two stacked lines: "NN%" over a compact
    /// time-until-reset like "26m" / "2h" / "2h 30m".
    static func compose(percent: Int?, resetsAt: Date?, now: Date = Date()) -> NSImage {
        let bolt = NSImage(systemSymbolName: "bolt.fill",
                           accessibilityDescription: "Claude usage")!
        bolt.isTemplate = true
        guard let percent, percent >= showThreshold else { return bolt }

        let topText = "\(percent)%"
        let bottomText = resetsAt.map { compactRemaining(from: now, to: $0) } ?? ""

        // Menu-bar height on macOS is ~22pt. Two stacked 9pt lines fit comfortably.
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,  // template — system retints to match menu bar
        ]

        let topSize = (topText as NSString).size(withAttributes: attrs)
        let bottomSize = (bottomText as NSString).size(withAttributes: attrs)
        let textColumnWidth = max(topSize.width, bottomSize.width)
        let textColumnHeight = topSize.height + bottomSize.height
        let gap: CGFloat = 4
        let totalWidth = bolt.size.width + gap + textColumnWidth
        let totalHeight = max(bolt.size.height, textColumnHeight)

        let composed = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        composed.lockFocus()
        // Bolt vertically centered.
        let boltY = (totalHeight - bolt.size.height) / 2
        bolt.draw(in: NSRect(x: 0, y: boltY,
                             width: bolt.size.width, height: bolt.size.height))
        // Text column: top line above, bottom line below; centered as a block.
        let textBlockY = (totalHeight - textColumnHeight) / 2
        let textX = bolt.size.width + gap
        if !bottomText.isEmpty {
            (bottomText as NSString).draw(
                at: NSPoint(x: textX, y: textBlockY),
                withAttributes: attrs
            )
            (topText as NSString).draw(
                at: NSPoint(x: textX, y: textBlockY + bottomSize.height),
                withAttributes: attrs
            )
        } else {
            // No reset time available — center a single line.
            (topText as NSString).draw(
                at: NSPoint(x: textX, y: (totalHeight - topSize.height) / 2),
                withAttributes: attrs
            )
        }
        composed.unlockFocus()
        composed.isTemplate = true
        return composed
    }

    static func compactRemaining(from now: Date, to reset: Date) -> String {
        let secs = Int(reset.timeIntervalSince(now))
        guard secs > 0 else { return "now" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m" }
        let hrs = mins / 60
        let remMins = mins % 60
        if remMins == 0 { return "\(hrs)h" }
        // Drop the minutes once we're past 10h to save horizontal space.
        if hrs >= 10 { return "\(hrs)h" }
        return "\(hrs)h\(remMins)m"
    }
}
