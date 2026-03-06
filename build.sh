#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up Flutter..."

# Clone flutter if it doesn't exist
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter repository..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

export PATH="$PATH:`pwd`/flutter/bin"

echo "Running Flutter Config..."
flutter config --enable-web

echo "Running Flutter doctor..."
flutter doctor

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web application (Forcing HTML Renderer)..."
flutter build web --web-renderer html --release

echo "Build complete!"
