# Manual Smoke Test

Native AppKit menu bar UI cannot be exercised by Playwright. Walk through
this 8-step checklist before every release. Capture screenshots of states
3, 5, 7 into `manual-smoke-test/screenshots/` for visual regression review.

## Prerequisites

- A real `sessionKey` cookie from a signed-in claude.ai account.
- A second, **invalid** `sessionKey` value to test the auth-error flow.

## Steps

1. **Clean Keychain state.** Run:

   ```bash
   security delete-generic-password -s com.alejtr.ClaudeMon \
       -a claude-ai-session-key 2>/dev/null || true
   ```

   Then build & launch the app from Xcode (`Cmd-R`).

2. **Settings appears for new users.** Click the menu bar bolt. Confirm the
   `SettingsView` (paste field, "How do I find my sessionKey?" disclosure)
   is shown.

3. **Successful sign-in.** Paste a known-valid `sessionKey` → click **Save**.
   Confirm the popover swaps to `UsagePanelView` and the **Current session**
   row's `fiveHour` bar shows a non-zero percentage within 5 seconds.
   Capture screenshot.

4. **Numbers match the web.** Compare the four bars (current session, weekly
   all models, weekly Sonnet, weekly Claude Design if present) to the live
   values at `https://claude.ai/settings/usage`. They must match within ±1%
   and the reset times must match within ±1 minute.

5. **Manual refresh.** Click the `arrow.clockwise` button in the footer.
   The `Updated …` label ticks to "0s ago" within ~1 second.
   Capture screenshot.

6. **Sign out.** Click **Settings…** in the footer → click **Clear** in the
   Settings view. Close + reopen the popover. Confirm `SettingsView` reappears
   on next click. Verify
   `security find-generic-password -s com.alejtr.ClaudeMon -a claude-ai-session-key`
   returns "could not be found".

7. **Bad sessionKey.** Paste a known-bad value (e.g. `sk-ant-sid01-deadbeef`).
   Confirm a yellow error banner appears with text
   `Session expired — paste a new sessionKey.`
   Capture screenshot.

8. **Network outage resilience.** Re-paste the valid key, confirm fresh data,
   then disable Wi-Fi. Wait 60s. Confirm an error banner appears at the top
   of the popover and the previous snapshot still renders below it (data is
   not blanked out). Re-enable Wi-Fi → next 60s tick → banner clears, data
   refreshes.

## Menu bar badge

- With **all** buckets `< 10%`: bare bolt icon, no overlay.
- With **any** bucket `>= 10%`: bolt + `NN%` text trailing.
- Update visible within 60 seconds of consuming usage in another tab.

## Sleep/wake

- Put the Mac to sleep (`Apple menu → Sleep`).
- Wake it. The badge refreshes within ~5 seconds of wake (driven by
  `NSWorkspace.didWakeNotification`).

## Quit

- Click **Quit** in the popover footer (or use Cmd-Q while popover is key).
  Menu bar icon disappears immediately. No leftover process in
  `ps aux | grep ClaudeMon`.
