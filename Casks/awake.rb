cask "awake" do
  version "0.1.0"
  sha256 "9317af87719faf5857dc20eaa8692832189f2d383f2013c538525d690caa1c8d"

  url "https://github.com/MPalarya/Awake/releases/download/v#{version}/Awake.dmg"
  name "Awake"
  desc "Menu bar toggle that keeps your Mac awake, like caffeinate"
  homepage "https://github.com/MPalarya/Awake"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Awake.app"

  # Release builds are not notarized; clear quarantine so Gatekeeper doesn't block launch.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "Awake.app"], chdir: "{{appdir}}"
  end

  uninstall quit: "com.awake.app"

  zap trash: "~/Library/Preferences/com.awake.app.plist"
end
