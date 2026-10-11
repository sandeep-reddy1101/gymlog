#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/liftlog-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
swiftc -module-cache-path /tmp/liftlog-core-module-cache LiftLog/Core/*.swift Tests/LiftLogCoreTests/WorkoutLogicTests.swift Scripts/CoreChecks.swift -o "$check_dir/core-checks"
"$check_dir/core-checks"
swiftc -frontend -parse LiftLog/Core/*.swift LiftLog/Models/*.swift LiftLog/Services/*.swift LiftLog/Views/*.swift LiftLog/LiftLogApp.swift GymLogWatch/*.swift
plutil -lint LiftLog.xcodeproj/project.pbxproj LiftLog/Resources/Info.plist LiftLog/Resources/LiftLog.entitlements LiftLog/Resources/LocalOnly.entitlements GymLogWatch/Resources/Info.plist GymLogWatch/Resources/GymLogWatch.entitlements
