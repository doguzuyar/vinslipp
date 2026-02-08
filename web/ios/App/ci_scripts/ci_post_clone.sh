#!/bin/bash
set -e

# Xcode Cloud post-clone script
# Installs Node.js, npm dependencies, and runs Capacitor sync
# to generate files needed by the Xcode build (public/, capacitor.config.json, config.xml)

echo "=== Installing Node.js ==="
brew install node

echo "=== Installing npm dependencies ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/web"
npm ci

echo "=== Building web assets for Capacitor ==="
BUILD_TARGET=capacitor npx next build

echo "=== Syncing Capacitor ==="
npx cap sync ios

echo "=== Done ==="
