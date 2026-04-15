# Pre-Publish Checklist

Do **not** make the experience public until every item in "Blockers" is checked. The other sections are best-practice and can be done incrementally during soft-launch.

Links in **GOTCHAS** refer to `../GOTCHAS.md` point numbers in the parent `roblox/` repo.

---

## 🚨 Blockers (cannot publish without these)

### IP & legal

- [ ] **Rename the experience and NPC** — remove "Kissy Missy", "Huggy Wuggy", "Poppy Playtime", MOB Games silhouettes. New name + distinct silhouette for the hunter. Check every Toolbox asset for third-party IP. (#210)
- [ ] Audit every mesh/image/sound in `default.project.json` and `ServerStorage` — Toolbox assets from IP-heavy franchises → replace. Music only from Roblox Audio Catalog. (#210)
- [ ] Primary dev account **ID-verified** (or has made a Robux purchase after 2025-01-01). Junior game designer (<13) cannot ID-verify → publish under Sergey's account. (#211)

### Account & experience setup

- [ ] 2FA enabled on the publishing account. (prerequisite for monetization)
- [ ] Content maturity questionnaire filled in — expect "Mild Scary" given chase/prison theming. (#211, #221)
- [ ] Genre chosen deliberately — locked for 3 months. Candidates: **Survival → 1 vs All** or **Party & Casual → Childhood Game**. (#212)
- [ ] Start place decided and set on the first `Publish to Roblox` — subsequent publishes overwrite it. (#213)

### Data & GDPR

- [ ] `DataStore` implementation landed with: session locking (#113), `BindToClose` parallel save (#114), `errored=true` flag on load-fail (#117), JSON-only types (#121), GDPR RTBF template (#122, #224).
- [ ] DataStore keys contain **only** `userId` — no emails, real names, photos, birth dates. (#224)
- [ ] `DeletePlayerData(userId)` function wired and tested end-to-end before public launch. (#224)

### Monetization safety (only if any IAP exists at launch)

- [ ] `MonetizationService` has a **single** `MarketplaceService.ProcessReceipt` callback. (#232)
- [ ] `ProcessReceipt` checks `PurchaseId` in DataStore **before** granting — saves it only after successful grant. Tested with deliberate retry. (#227)
- [ ] All Pass benefits re-applied on `PlayerAdded` via `UserOwnsGamePassAsync` (wrapped in `pcall`). Browser-Store purchases must activate without relog. (#229)
- [ ] Any speed / stat boost from passes re-applied in **both** `PlayerAdded` **and** `CharacterAdded` (respawn resets `WalkSpeed`). Already handled for base speed in `PlayerService:64-77` — keep the same pattern for pass boosts. (#230)
- [ ] Subscription benefits **not** persisted in DataStore. Query `GetUserSubscriptionStatusAsync` each join, subscribe to `Players.UserSubscriptionStatusChanged` for revoke. (#231)
- [ ] All price labels populated dynamically via `MarketplaceService:GetProductInfo` — zero hard-coded Robux prices. (#235)
- [ ] Paid random items (if any): `PolicyService:GetPolicyInfoForPlayerAsync` → `ArePaidRandomItemsRestricted` hides the offer; UI shows numerical odds before prompt. (#238)
- [ ] Every `AwardBadgeAsync` server-only, in `pcall`, preceded by `GetBadgeInfoAsync().IsEnabled` check. (#218)

---

## 🟡 Recommended (do before or shortly after launch)

### Store page assets

- [ ] Icon tested at **150×150** rendering (that's the actual display size on most surfaces). Large silhouette, no small text. (#219)
- [ ] 4-5 thumbnails at 16:9 1920×1080. **Activate at least 2** for auto A/B personalization. Don't pick a "winner" manually. (#215)
- [ ] Description hook in first **160 characters** — name + genre + core feature + objective. Total limit 1000, no tag spam. (#220)
- [ ] Video thumbnails (optional): max 3/month, each rejection counts. Only real gameplay — no voice-over, music-with-lyrics, external footage, overlay ads. (#214)
- [ ] Badge images 512×512, centered — **cropped to a circle** on display. (#216)

### Badge planning

- [ ] Full badge set planned up front (first 5 free per 24h GMT, then 100 R$ each). Create in batches of 5. Suggested: First Escape, 10 Rounds Survived, Speed Demon, Coin Collector I/II/III, First Capture, Castle Explorer. (#217)

### Accessibility

- [ ] HUD text respects `PreferredTextSize` — avoid `TextScaled` on every label. Prefer `AutomaticSize` + fixed font size. (#222)
- [ ] Honor `GuiService.ReducedMotionEnabled` — swap tweens for snap/fade, disable camera shake on capture. (#223)

### Console readiness (only if publishing to Xbox/PS)

- [ ] Content maturity filled out (required on console). (#221)
- [ ] Chat window disabled on console builds. (#221)
- [ ] HUD elements kept away from screen edges (TV-safe area). (#221)

### Cross-platform input

- [ ] Mobile-only UI branching (when/if added) uses `UserInputService.PreferredInput == Enum.PreferredInput.Touch`, **not** `TouchEnabled` — laptops with touchscreens are common in the target audience. (#198)
- [ ] Input prompts ("E" vs "(A)") driven by `PreferredInput` or `LastInputTypeChanged` with filtering, not `GetLastInputType()`. (#199)
- [ ] `InputBegan` handlers always check `gameProcessedEvent`. ✓ Already done in `InputController.luau:18`. (#200)

---

## 🔵 Nice-to-have (polish, not gate)

- [ ] Haptic feedback on capture/coin pickup — `HapticEffect` with `Parent = workspace`, created once and pooled, not per-event. (#207)
- [ ] `EnableMouseLockOption = false` if any bindings use LeftShift — it clashes with shift-lock camera. (#202)
- [ ] "Welcome to the Castle" promoted pass (50-800 R$) for free-distribution pool on Buy Robux page — do **not** put Speed Boost here, those are given away free to users. (#244)
- [ ] Premium benefits cosmetic-only (no gameplay advantage / paywall). (#242)
- [ ] Immersive ads only after ≥2000 unique visitors/month and never in Chase/Prison/Treadmill zones — only lobby/shop. (#241)

---

## ❌ Do not ship with these

- [ ] `leaderstats.Coins` purely in-memory (current state) — **must** have DataStore persistence before public launch or players rage-quit after first relog.
- [ ] Hard-coded Robux prices in any UI label. (#235)
- [ ] `isVIP` / subscription flags stored in DataStore. (#231)
- [ ] Any `PromptProductPurchaseFinished`-based grant logic — **must** be `ProcessReceipt`. (#228)
- [ ] Test-mode purchases of high-price dev products (real Robux spent). Create a "Test 1 R$" product for integration tests. (#234)
- [ ] Paid Access + Private Servers both enabled — they're mutually exclusive. (#243)

---

## Release rehearsal

Before the first public publish, do a full rehearsal on a private test place:

- [ ] Soft-publish to a separate test experience, not the real one.
- [ ] Invite 2-3 external testers (not the dev team) for 30-min sessions.
- [ ] Verify: DataStore save/load works across servers, teleport doesn't duplicate coins, purchases grant exactly once, badges award exactly once.
- [ ] Studio → Test → Network → Incoming Replication Lag = **0.2s** during rehearsal — catches capture race conditions invisible on LAN. (#13)
- [ ] Screenshot set for store page taken via `Shift+P` free camera + `Ctrl+Shift+G` to hide CoreGui. (#226)

Only after this rehearsal, switch the real experience to **Public**.
