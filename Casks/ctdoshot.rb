cask "ctdoshot" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_DMG"
  url "https://github.com/TIPC1110/ctdoshot/releases/download/v#{version}/ctdoshot.dmg"
  name "ctdoshot"
  desc "Menu-bar screenshot tool for macOS"
  homepage "https://tipc1110.github.io/ctdoshot/"
  depends_on macos: ">= :ventura"
  app "ctdoshot.app"
end
