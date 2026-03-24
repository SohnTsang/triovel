# App Store & Play Store Compliance

Build these requirements into the app BEFORE App Store / Play Store submission.
Not needed for TestFlight beta, but the rules file should exist now so nothing gets designed in a way that makes compliance harder later.

## Account Deletion (Apple mandatory, Google mandatory)
- Must provide in-app account deletion — easy to find in Settings
- Deletion must remove the account AND all associated personal data
- If using Sign in with Apple, must call the Apple REST API to revoke user tokens on deletion
- Temporary disable/deactivation is NOT sufficient — must be full deletion
- Must also provide a web link for account deletion (Google Play requirement)
- Inform user how long deletion takes if not instant
- Inform user about impact on trip data they participated in (their posts, bills, etc.)
- After deletion: remove user from all trip_members, anonymize or delete their posts/bills per policy

## Account Deletion — Implementation Checklist
- Settings screen: "Delete Account" button, clearly visible (not buried)
- Confirmation dialog explaining what will be deleted
- Supabase: delete user record + cascade or anonymize related data
- Revoke Apple Sign-In tokens via REST API if Apple auth was used
- Web page for account deletion (can be simple — hosted on project domain)
- Handle edge case: user is only trip owner — warn about orphaned trips

## Privacy Policy (Apple mandatory, Google mandatory)
- Must have a privacy policy accessible in-app (Settings screen)
- Must have a privacy policy URL in App Store Connect and Play Console
- Must disclose: what data is collected, how it's used, who it's shared with, how to delete it
- Must include developer/company contact info
- For V1 beta: a simple privacy policy page hosted on the project domain is sufficient

## Privacy Manifest — Apple (mandatory since May 2024)
- Must include PrivacyInfo.xcprivacy file in the Xcode project
- Declare all "required reason APIs" used by the app (UserDefaults, file timestamps, etc.)
- Declare all data types collected (name, email, photos, location text, financial data)
- Third-party SDKs (Supabase, PowerSync) must include their own privacy manifests
- Xcode auto-combines all manifests into a single Privacy Report for submission
- Location APIs are NOT used in V1 core flow — do not declare them

## Data Safety Form — Google Play (mandatory)
- Complete Data Safety form in Play Console before publishing
- Declare: data collected, data shared, data encrypted in transit, deletion mechanism
- Must match what the privacy policy says
- Link to web-based account deletion page in the form

## App Store Review Prep — Apple
- Provide demo account credentials in App Review Notes
- All backend services must be live and accessible during review
- If TestFlight: demo accounts not required, but app must not crash
- Screenshots must match actual app behavior
- Do not promise features in description that aren't implemented
- Sign in with Apple: if app offers ANY social login, Apple Sign-In is required

## Build Requirements — Apple (current)
- Build with Xcode 16+ and iOS 18 SDK (can still target iOS 17 deployment)
- 64-bit only (no 32-bit support needed)
- Complete age rating questions in App Store Connect

## Photo & Camera Permissions
- Declare camera and photo library usage in Info.plist with clear purpose strings
- Purpose strings must explain WHY: "Take photos to capture trip memories" not "Camera access needed"
- Only request permissions when the user first tries to take/attach a photo — not on app launch

## Data Handling
- All data transmitted via HTTPS (Supabase handles this)
- Explain data retention in privacy policy
- User data stays local when offline — syncs only to Supabase (no third-party data sharing in V1)
- Analytics (Phase 5) must be privacy-safe — no user-identifiable data in events

## What to Build Now vs Later
NOW (design with compliance in mind):
- Settings screen with placeholder slots for: Delete Account, Privacy Policy, Terms of Service
- Permission request strings in Info.plist
- PrivacyInfo.xcprivacy file in the project

BEFORE TESTFLIGHT:
- Privacy policy page (even a simple one)
- Working Sign in with Apple + email auth
- App doesn't crash on any main flow

BEFORE APP STORE SUBMISSION:
- Full account deletion flow (in-app + web)
- Apple token revocation on deletion
- Complete PrivacyInfo.xcprivacy with all required reason APIs declared
- Complete App Store Connect metadata (screenshots, description, age rating)
- Demo account for App Review
- Privacy policy URL in App Store Connect

BEFORE GOOGLE PLAY (if ever):
- Web-based account deletion page
- Data Safety form completed in Play Console
- Privacy policy URL in Play Console
