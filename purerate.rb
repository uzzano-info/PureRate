# ============================================================
# PureRate – Homebrew Cask Formula
# ============================================================
# To use locally:   brew install --cask ./purerate.rb
# To submit to tap:  Add to your tap repository
# ============================================================

cask "purerate" do
  version "3.0"
  sha256 :no_check  # Replace with actual sha256 after release

  url "https://github.com/uzzano-info/PureRate/releases/download/v#{version}/PureRate.dmg"
  name "PureRate"
  desc "Automatic sample rate switching for Apple Music on macOS"
  homepage "https://github.com/uzzano-info/PureRate"

  depends_on macos: ">= :sonoma"

  app "PureRate.app"

  zap trash: [
    "~/Library/Preferences/com.example.purerate.plist",
  ]

  caveats <<~EOS
    PureRate requires access to system logs (OSLog) to detect
    Apple Music sample rates. On first launch, you may need to
    grant accessibility or Full Disk Access permissions in
    System Settings → Privacy & Security.
  EOS
end
