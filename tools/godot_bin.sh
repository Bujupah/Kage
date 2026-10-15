#!/usr/bin/env bash
# Prints the Godot binary to use. Set GODOT to override.
echo "${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
