class ShadowsocksMacos < Formula
  desc "Shadowsocks client for macOS with Apple Silicon optimization"
  homepage "https://github.com/YOUR_USERNAME/shadowsocks-macos"
  url "https://github.com/YOUR_USERNAME/shadowsocks-macos/releases/download/v1.0.0/Shadowsocks.dmg"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  version "1.0.0"

  depends_on :macos => :ventura

  def install
    # Install the .app to /Applications via cask
    # This formula is actually a cask — use the cask version below
  end
end

# Cask version (preferred for macOS .app distribution)
# Save as: shadowsocks-macos.rb in homebrew-cask repository
# Or use: brew tap YOUR_USERNAME/shadowsocks-macos
# And: brew install --cask shadowsocks-macos

class ShadowsocksMacosCask < Cask
  desc "Shadowsocks client for macOS with Apple Silicon optimization"
  homepage "https://github.com/YOUR_USERNAME/shadowsocks-macos"
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/YOUR_USERNAME/shadowsocks-macos/releases/download/v1.0.0/Shadowsocks.dmg"

  depends_on macos: ">= :ventura"

  app "Shadowsocks.app"

  zap trash: [
    "~/Library/Application Support/Shadowsocks",
    "~/Library/Caches/com.shadowsocks.macos",
    "~/Library/Preferences/com.shadowsocks.macos.plist",
  ]

  caveats <<~EOS
    Shadowsocks runs as a status bar app (no Dock icon).
    Look for the shield icon in your menu bar after launching.

    To enable auto-start: open Settings → General → "Launch at Login"
  EOS
end
