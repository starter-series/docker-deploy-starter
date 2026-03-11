#!/bin/bash
set -e

VERSION=$(cat VERSION)
IFS='.' read -r major minor patch <<< "$VERSION"

case "${1:-patch}" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  *) echo "Usage: $0 [major|minor|patch]"; exit 1 ;;
esac

NEW="$major.$minor.$patch"
echo "$NEW" > VERSION
echo "Bumped version: $VERSION → $NEW"
