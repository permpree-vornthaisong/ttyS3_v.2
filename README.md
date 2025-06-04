Real name Project = unittest

adb install -r build\app\outputs\flutter-apk\app-release.apk
# ติดตั้ง Homebrew ก่อน (ถ้ายังไม่มี)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ติดตั้ง ADB
brew install android-platform-tools