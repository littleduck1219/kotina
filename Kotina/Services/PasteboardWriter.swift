import AppKit

@MainActor
protocol PasteboardWriting {
    func write(_ text: String) -> Bool
}

@MainActor
struct SystemPasteboardWriter: PasteboardWriting {
    func write(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

