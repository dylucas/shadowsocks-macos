# Shadowsocks macOS Client — Xcode Project
#
# This is a reference Xcode project file. Due to environment limitations,
# the actual .xcodeproj will need to be generated on your macOS machine.
# Use the following steps to create the project:
#
# 1. Open Xcode → File → New → Project → macOS → App
# 2. Product Name: Shadowsocks
# 3. Interface: SwiftUI
# 4. Language: Swift
# 5. Minimum macOS: 13.0
# 6. Uncheck "Use Core Data" and "Include Tests"
# 7. Save to this directory
# 8. Delete the auto-generated ContentView.swift
# 9. Add all source files from this repo to the project
# 10. In Build Settings → Info.plist → set to Resources/Info.plist
# 11. In Build Settings → Other Linker Flags → add -ObjC
# 12. Add sslocal binary to Resources (drag into project)
# 13. In Target → General → Frameworks → no additional frameworks needed
# 14. In Target → Signing → set your Developer ID
#
# Key configurations:
# - LSUIElement = YES (Info.plist, no Dock icon)
# - Minimum deployment target: macOS 13.0
# - Architecture: arm64 (primary) + x86_64 (secondary for Intel)
#
# Alternatively, use `xcodegen` to generate from this spec:
# Install: brew install xcodegen
# Run: xcodegen generate
