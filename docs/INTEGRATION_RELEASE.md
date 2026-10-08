# Mobile integration and release preparation

Prepared 9 October 2026, Pacific/Auckland under approved Step 13. Preparation is complete; physical acceptance and integration remain pending. No merge, retarget, protection, retirement, tag, release or signing/account change is authorized here.

## Candidate and dependency order

Current review source `a92b9b0cb40e6d6b8a4a40fe47fc23a6aa0378c0` (draft #7) passed [native run 37766716383](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37766716383), Simulator build 64: 48 unit + two UI smoke tests on each iPhone SE 3/16 Pro Max, Xcode 16.4/iOS 18.5. Screenshot export and unsigned device job were skipped. It does not identify a physical install. Last recorded physical candidate remains build 59/source `db007a3390c8a2ff25e511f615d4e5ff0b8f713c`, to be reverified before upgrade. Protocol 2, desktop schema 5 and mobile schema 2 remain distinct.

Main at preparation is `147668d90963e1709b68403ad12769f6d14b418b`. Oldest-first order is **#1 → #2 → #3 → #7 → Step 13 documentation draft**.

| PR | Head at preparation | Current base |
|---|---|---|
| #1 | `07bfef95f4844e370a784ad133b236bbc6e0bf6a` | `main` |
| #2 | `3be794b866403ba2900175f153ee541dff01fcfb` | `feat/iphone-companion-m1` |
| #3 | `92126742d30c036123d9fe2362beafc3e4629849` | `feat/iphone-full-interface` |
| #7 | `a92b9b0cb40e6d6b8a4a40fe47fc23a6aa0378c0` | `ui/minimal-chat-sync-status` |

After separate acceptance/integration approval, review/merge the oldest PR into main, then retarget its next child to main only after the parent lands; recheck ancestry, diff, reviews and exact-head checks before each merge. Proposed ordinary merge commits retain ancestry. An owner-selected squash/rebase requires descendant adjustment and fresh validation. Record main after each operation and validate the final pair. Desktop's private preparation packet holds its corresponding order; public mobile docs contain no private desktop source or personal data.

## Device and evidence gates

Execute [PHYSICAL-ACCEPTANCE](PHYSICAL-ACCEPTANCE.md) one row at a time and fill [the handoff manifest](validation/2026-10-09-handoff.json). Build a changed physical candidate only through a separately authorized owner workflow; record actual source/build/signed payload hash and unchanged bundle identity. Upgrade over the installed app without uninstalling, verify SQLite/outbox/Keychain retention, pair the exact reviewed desktop and rerun offline/conflict/Calendar/Files/reminders/accessibility/battery/signing checks. iOS 17+ deployment is not a minimum-runtime pass. Current selected non-model milestone is not full visual/product acceptance.

Curated native result/excerpts are committed under `docs/validation/2026-10-09-handoff/`. Latest binary result bundles expire 22 October 2026 UTC; compact manifests 6 January 2027 UTC. Build-59 unsigned payload expires 21 October 2026 15:53:24 UTC. Binary inventory is not a downloaded/reviewed archive. Retain required source-matched results and sanitized captures before expiry (compact 90 days/full 14 days); never publish record bodies, credentials, QR text or signing material. Original captures and changed-candidate visual review remain pending.

## Owner decisions and future protection

Owner must record exact license/distribution terms, accepted milestone/deferred features, tested/supported platform limits, support contact/expectations and private security-reporting channel. Repository metadata has no recognized license; no terms are selected by preparation. Follow [SECURITY](../SECURITY.md); verify private reporting availability before advertising it. Record exact paired acceptance and separate integration, protection, publication and signing approvals.

The existing `docs/maintenance/main-protection.json` is an unapplied proposal unless independently verified. Required proposed job contexts are `simulator (small)` and `simulator (large)`; verify actual successful checks on the selected head. Owner/admin verifies existing rules and approves up-to-date checks, PR/conversation requirements, no force/deletion and bypass treatment. Zero required approvals does not enforce human review; reviewer policy remains an owner decision. [GitHub documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) permits protected branches in public repositories on Free; desktop's private eligibility/admin access must be separately verified. No settings are changed here.

After integration, run full native/generator/contract gates on actual resulting main, record build/hash/toolchain and redo affected physical checks against the exact paired desktop. Tags/releases must point to the owner-approved tested pair and carry explicit support limits. Rollback must preserve backups/outbox; reverting Git does not reverse database migrations. Test supported restore in isolation before any active-store recovery or downgrade.

Readiness remains blocked by desktop hosted CI, native Fedora, changed-source physical phone and evidence review, plus owner decisions. Mobile #4 remains open. Preparation alone cannot accept these gates.
