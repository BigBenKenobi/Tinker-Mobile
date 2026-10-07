> Historical implementation/validation narrative. For current source, results and
> remaining gates, see [STATUS.md](STATUS.md). Statements below apply to their
> original recorded commits and have not been promoted to fresh acceptance.

# Minimal home layout — review branch

Base: feat/iphone-full-interface at df08ee311e1fd8b0726a3259f832b558d22136c1.

Implemented: header-free home, large centered Tinker, small Chat/Agent controls above the composer, integrated send arrow, removal of introductory and footer copy, cloud status shortcut to Companion. Controls preserve 44-point touch regions and process-local drafts.

Cloud states: checkmark only after successful sync with no pending edits/conflicts and a reachable paired connection; clock during sync or while edits await sync; exclamation for failures/conflicts or unavailable pairing/network. The cloud represents existing desktop companion synchronization, not an internet cloud service.

Not implemented: sending, conversation display, title transition after a successful send, loaded-model shorthand. The existing app has no message transport, conversation persistence or loaded-model API. Send remains disabled with an accessibility explanation; no fake messages or model names are introduced.

Verification: tree-sitter Swift 0.7.4 / tree-sitter 0.26.0 parsed the five changed Swift files with zero grammar errors (Linux; syntax only, not type-checking or an iOS build); source reviewed; existing navigation UI tests updated for header-free home. Xcode/Simulator and physical iPhone validation have not run. No Actions run was requested. Existing workflow supports manual device IPA builds for SideStore; run it on this branch after agreeing Actions usage.

Acceptance: inspect portrait/landscape and keyboard layout on iPhone, confirm draft retention across navigation, check Chat/Agent selection, verify each cloud state against real sync outcomes. Keep branch unmerged pending acceptance.
