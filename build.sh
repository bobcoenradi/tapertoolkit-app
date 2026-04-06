#!/bin/bash
set -e

FLUTTER_VERSION="3.41.5"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

echo ">>> Downloading Flutter ${FLUTTER_VERSION}..."
wget -q "${FLUTTER_URL}" -O flutter.tar.xz

echo ">>> Extracting Flutter SDK..."
tar xf flutter.tar.xz
rm flutter.tar.xz

export PATH="$PATH:$(pwd)/flutter/bin"

echo ">>> Configuring Flutter..."
flutter config --enable-web --no-analytics
flutter --version

echo ">>> Installing dependencies..."
flutter pub get

echo ">>> Building Flutter web (release)..."
flutter build web --release --base-href /

echo ">>> Build complete. Output in build/web"
