// PasteboardParser — Detect and parse ss:// URLs from macOS clipboard

import Foundation
import AppKit

enum PasteboardParser {

    /// Check if the clipboard contains a ss:// URL or subscription content
    static func detectShadowsocksContent() -> String? {
        let pasteboard = NSPasteboard.general

        // Check plain text — most reliable since ss:// URLs are copied as text
        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("ss://") || trimmed.hasPrefix("{") {
                return trimmed
            }
            if trimmed.contains("ss://") {
                return trimmed
            }
        }

        return nil
    }

    /// Parse clipboard content into servers
    static func parseClipboard() throws -> [Server] {
        guard let content = detectShadowsocksContent() else {
            throw ParseError.unrecognizedFormat
        }
        return try SubscriptionParser.parse(content)
    }
}
