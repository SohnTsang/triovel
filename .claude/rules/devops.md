---
description: DevOps and release engineering rules for iOS entitlements, TestFlight, and infrastructure
globs: "**/*.entitlements,**/Info.plist,**/*.xcconfig,**/Fastfile,**/Matchfile,**/*.yml,**/Podfile,**/Package.swift"
---

# DevOps & Release Engineering

## iOS Entitlements & Background Tasks
- Configure .entitlements for offline capabilities
- Set Background Modes in Info.plist for URLSession background transfers
- Ensure media uploads continue when app is suspended or backgrounded

## Supabase Environments
- Maintain strict separation: Dev / Staging / Prod
- Never use production credentials in development builds
- Manage PowerSync integration keys per environment
- Automate JWT auth handshake between Supabase Auth and PowerSync

## App Store Readiness
- Set up automated TestFlight deployments (Fastlane or Xcode Cloud)
- Document all Apple Privacy Manifests accurately
- Location APIs are NOT required in V1 core creation flow — do not declare them
- Declare only: network access, photo library, camera, background fetch

## Cost Controls (Infrastructure)
- Configure Supabase Storage bucket rules to enforce upload size limits
- Set database-level constraints for video duration cap (60s max)
- Validate client-side compression occurred before accepting uploads
- Monitor storage GB and egress per trip in Supabase dashboard

## Build Configuration
- Use xcconfig files for environment-specific settings (API URLs, keys)
- Separate Debug/Release/Staging schemes
- Pin dependency versions explicitly in Package.swift

## Xcode Project Settings
- Bundle Identifier: com.triovel.app
- Display Name: Triovel
- Deployment Target: iOS 17.0
- Device Orientation: iPhone = portrait only, iPad = all orientations
- Status Bar: default (light/dark auto)
- Supported Destinations: iPhone + iPad (universal app)

## App Icon
- Provide a single 1024x1024 PNG (no transparency, no alpha channel)
- Xcode 15+ auto-generates all sizes from the single asset
- Place in Assets.xcassets -> AppIcon
- Design: keep it simple, recognizable at small sizes, no text

## Launch Screen
- Use a simple LaunchScreen storyboard (not SwiftUI) — Apple requires it
- Match the app's background color (use system background for light/dark)
- Center the app logo or a minimal icon — no text, no loading indicators
- Keep it identical to the app's initial loaded state to feel instant
- Set UILaunchStoryboardName in Info.plist

## Accent Color
- Set a global AccentColor in Assets.xcassets — applies to all tint colors, buttons, links
- Use a calm, trustworthy color that works in both light and dark mode
