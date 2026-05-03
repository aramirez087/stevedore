import AppKit
import Core
import QuickLookUI

@MainActor
public final class QuickLookPanelController: NSObject {
    private var previewItems: [NSURL] = []

    override public init() {
        super.init()
    }

    /// Open the panel showing `urls`. If already visible, reloads.
    public func show(urls: [URL]) {
        self.previewItems = urls.map { $0 as NSURL }
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.updateController()
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Toggle panel visibility. First call shows, second call hides.
    public func toggle(urls: [URL]) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            self.show(urls: urls)
        }
    }

    /// Close the panel if visible.
    public func close() {
        QLPreviewPanel.shared()?.orderOut(nil)
    }
}

extension QuickLookPanelController: QLPreviewPanelDataSource {
    public nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        // AppKit always calls this on the main thread; MainActor.assumeIsolated is safe.
        MainActor.assumeIsolated { self.previewItems.count }
    }

    public nonisolated func previewPanel(
        _ panel: QLPreviewPanel!,
        previewItemAt index: Int
    ) -> any QLPreviewItem {
        MainActor.assumeIsolated { self.previewItems[index] }
    }
}

extension QuickLookPanelController: QLPreviewPanelDelegate {
    public nonisolated func previewPanel(
        _ panel: QLPreviewPanel!,
        sourceFrameOnScreenFor item: any QLPreviewItem
    ) -> NSRect {
        .zero
    }
}
