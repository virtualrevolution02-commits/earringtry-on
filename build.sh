#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Cloning Flutter repository..."
git clone https://github.com/flutter/flutter.git -b stable

echo "Adding Flutter to PATH..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Running Flutter doctor..."
flutter doctor

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web application..."
flutter build web --release

echo "Build complete!"
