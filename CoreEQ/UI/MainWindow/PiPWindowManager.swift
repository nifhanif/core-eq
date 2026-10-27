import AppKit
import SwiftUI

/// Window yang boleh digeser sampai tepi bawah layar (tidak ditahan oleh batas Dock).
final class PiPWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen ?? self.screen else { return frameRect }
        var rect = frameRect
        rect.origin.y = max(rect.origin.y, screen.frame.minY)
        return rect
    }
}

@MainActor
final class PiPWindowManager: NSObject, NSWindowDelegate {
    static let shared = PiPWindowManager()

    private var window: NSWindow?
    private var host: NSHostingController<Spectrum31BarView>?
    private var analyzer: SpectrumAnalyzer?
    private let defaultSize = NSSize(width: 200, height: 30)
    private let minContentSize = NSSize(width: 160, height: 30)

    var isVisible: Bool { window != nil }

    func show(analyzer: SpectrumAnalyzer) {
        if let existingHost = host, window != nil {
            self.analyzer = analyzer
            existingHost.rootView = Spectrum31BarView(analyzer: analyzer)
            return
        }

        self.analyzer = analyzer

        let root = Spectrum31BarView(analyzer: analyzer)
        let hosting = NSHostingController(rootView: root)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        self.host = hosting

        let newWindow = PiPWindow(
            contentRect: CGRect(origin: CGPoint(x: 120, y: 120), size: defaultSize),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hosting.view
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = true
        newWindow.level = .floating
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newWindow.isMovableByWindowBackground = true
        newWindow.isMovable = true

        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true

        newWindow.contentMinSize = minContentSize
        newWindow.contentMaxSize = NSSize(width: 800, height: 400)

        newWindow.delegate = self
        self.window = newWindow

        // SpectrumAnalyzer.start is idempotent and ref-counted
        analyzer.start()

        newWindow.makeKeyAndOrderFront(nil)
    }

    func hide() {
        Task { @MainActor in
            if let analyzer = analyzer {
                analyzer.stop()
                self.analyzer = nil
            }
            host = nil
            window?.orderOut(nil)
            window = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let analyzer = analyzer {
            analyzer.stop()
            self.analyzer = nil
        }
        host = nil
        window = nil
    }

    func windowDidMiniaturize(_ notification: Notification) {
        analyzer?.start()
    }
}
