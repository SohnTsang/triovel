---
description: End-to-end user flow rules covering every state a user can encounter — success, waiting, error, edge case
globs: "**/*View.swift,**/*ViewModel.swift,**/*Service.swift,**/*Repository.swift"
---

# User Flows — Every State Must Be Handled

## Core Principle
Every user action has 4 possible outcomes. ALL FOUR must be designed:
1. Success — what does the user see when it works?
2. Loading — what does the user see while waiting?
3. Error — what does the user see when it fails?
4. Edge case — what happens in unusual but real situations?

If any screen is missing one of these states, it is incomplete. Do not ship it.

## Auth Flows

### Sign Up (Email)
- User taps Sign Up -> show spinner on button
- Success -> show confirmation screen: "Check your email to verify your account" with an illustration or icon, the email address displayed, and a "Resend email" button
- User should NOT land on Home until email is verified
- Error (email taken) -> inline message: "An account with this email already exists"
- Error (weak password) -> inline message with requirements
- Error (network) -> inline message: "Connection failed. Please try again."

### Email Verification Callback
- App must register a custom URL scheme (triovel://) to handle the redirect
- After user taps email link -> app opens, verifies token, navigates to Home
- If link expired -> show "Verification link expired" with Resend button
- If already verified -> silently navigate to Home

### Sign In (Email)
- Success -> navigate to Home
- Error (wrong credentials) -> "Incorrect email or password"
- Error (unverified email) -> "Please verify your email first" with Resend option
- Error (network) -> "Connection failed. Please try again."

### Sign In with Apple
- Success -> navigate to Home
- Cancelled by user -> do nothing, stay on auth screen
- Error -> "Sign in failed. Please try again."

### Sign Out
- Confirmation dialog: "Are you sure you want to sign out?"
- Success -> navigate to Auth screen, clear local state
- Error -> "Couldn't sign out. Please try again."

### Session Restore (App Launch)
- Valid session -> navigate to Home (skip auth)
- Expired session -> silently refresh token, then Home
- Refresh fails -> navigate to Auth screen (don't show error, just require re-login)
- No session -> navigate to Auth screen

## Trip Flows

### Create Trip
- Loading -> spinner on Create button, button disabled
- Success -> navigate into new trip timeline
- Error -> inline message, button re-enables

### Join Trip
- Invalid code -> "No trip found with this invite code"
- Already a member -> "You're already in this trip" and navigate to it
- Success -> navigate into trip timeline

### Share Invite
- Copy to clipboard -> brief toast "Invite code copied"

## Block Flows

### Create Block (Add Moment)
- Loading -> spinner on Save button
- Success -> navigate into Block Detail
- Error -> inline message, stay on sheet

### Edit Block Header
- Not authorized -> edit button hidden (not shown then rejected)
- Success -> optimistic UI, update locally first
- Error -> revert local change, show inline error

## Post Flows

### Send Post
- Loading -> spinner on send button, disable input
- Success -> post appears in stream immediately (optimistic)
- Error -> show failed state on the post with retry
- Composer resets to Shared after send

### Delete Post
- Confirmation: "Delete this post?"
- Success -> remove from stream with animation
- Error -> "Couldn't delete. Please try again."

## Bill Flows (Phase 4)

### Add Bill
- Default all members checked
- Amount field: only numbers, auto-format with currency symbol
- Success -> bill appears in block stream
- Error -> inline message

### Record Payment
- Success -> summary updates immediately
- Error -> inline message

## Universal Rules

### Network Errors
- Never show technical error messages (HTTP 500, timeout, etc.)
- Always translate to human language: "Something went wrong. Please try again."
- Add a retry mechanism for every failed network action
- If offline: queue the action and show "Saved. Will sync when online."

### Empty Inputs
- Disable submit buttons when required fields are empty
- Never let users submit and then show "field required" — prevent it upfront
- Show character limits only when approaching the limit, not always

### Destructive Actions
- Always require confirmation (dialog or swipe-to-confirm)
- Never auto-confirm destructive actions
- Use red text for destructive labels, never red filled buttons

### Navigation After Actions
- Create something -> navigate INTO it (not back to list)
- Delete something -> navigate BACK to parent (not stay on deleted item)
- Edit something -> stay on current screen, show update
- Sign out -> go to Auth (not Home)

### Toasts and Feedback
- Use brief non-blocking toasts for: copied to clipboard, saved, sent
- Toasts auto-dismiss after 2 seconds
- Never use toasts for errors — errors must persist until acknowledged or resolved

### Deep Links and URL Schemes
- Register triovel:// URL scheme in Info.plist for auth callbacks
- Handle: triovel://auth-callback (email verification, password reset)
- Handle: triovel://trip/{invite_code} (join trip via shared link)
- Gracefully handle malformed deep links — navigate to Home, don't crash
