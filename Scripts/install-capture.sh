#!/usr/bin/env bash
# Copy the GradleLens init script into $GRADLE_USER_HOME/init.d (default ~/.gradle/init.d).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/Sources/GradleLensCore/Resources/gradlelens.init.gradle.kts"
DEST_DIR="${GRADLE_USER_HOME:-$HOME/.gradle}/init.d"
DEST="$DEST_DIR/gradlelens.init.gradle.kts"
if [[ ! -f "$SRC" ]]; then
    echo "ERROR: missing $SRC" >&2
    exit 1
fi
mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST"
echo "Installed $DEST"
echo "New Gradle builds will write JSON under build/reports/gradlelens/ (offline, local only)."
