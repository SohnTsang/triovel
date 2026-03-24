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
