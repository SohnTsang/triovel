---
description: Localization rules for multi-language support across all UI strings
globs: "**/*.strings,**/*Localizable*,**/*Localization*,**/Strings/**,**/*View.swift,**/Resources/**"
---

# Localization

## Supported Languages
- English (en) — base language
- Japanese (ja)
- Chinese Traditional (zh-Hant) — for Hong Kong, Taiwan
- Chinese Simplified (zh-Hans) — for mainland China

## Detection
- Use device language setting automatically — no in-app language picker in V1
- SwiftUI handles this natively via Bundle localization
- Fall back to English if device language is not one of the supported four

## Implementation
- Use String Catalogs (.xcstrings) — Xcode 15+ standard, replaces .strings files
- Every user-facing string must use LocalizedStringKey or String(localized:)
- Never hardcode UI text directly in views — always use localization keys
- Use Xcode's export/import for localization workflow

## String Key Naming Convention
- Use dot-separated, descriptive keys: home.empty.title, trip.setup.title.placeholder
- Group by feature: home.*, trip.*, timeline.*, block.*, post.*, bill.*, summary.*, settings.*, auth.*
- Actions: common.save, common.cancel, common.delete, common.retry
- States: state.syncing, state.failed, state.pending

## Translation Quality Rules
- Translations must be natural, native-speaker grade — not literal machine translation
- Japanese: use polite form (です/ます) for UI labels, casual for placeholder hints
- Chinese Traditional: use Hong Kong/Taiwan conventions (繁體), not converted from Simplified
- Chinese Simplified: use mainland conventions (简体), natural phrasing
- Keep translations concise — Japanese and Chinese are often shorter than English, but some phrases expand
- Test that all translations fit in the UI without truncation on iPhone SE

## Tone Per Language
- English: calm, friendly, concise — "No shared expenses yet"
- Japanese: polite but warm — "共有の支出はまだありません"
- Chinese Traditional: clear, professional — "尚無共享支出"
- Chinese Simplified: clear, professional — "暂无共享支出"

## Strings That Must NEVER Be Translated
- Currency codes (JPY, AUD, USD)
- App name "Triovel"
- Technical identifiers, API keys, URLs

## Pluralization
- Use String Catalog plural rules — English needs singular/plural, Japanese and Chinese do not pluralize
- Example: "1 member" vs "3 members" in English, always "1 名成員" / "3 名成員" in Chinese

## Date and Number Formatting
- Use Foundation formatters (Date.FormatStyle, NumberFormatter) — they auto-localize
- Never manually format dates or numbers with hardcoded patterns
- Currency display follows device locale — Locale.current handles this

## Right-to-Left
- Not needed for V1 languages (en, ja, zh) — all are LTR
- But still use .leading/.trailing instead of .left/.right for future-proofing
