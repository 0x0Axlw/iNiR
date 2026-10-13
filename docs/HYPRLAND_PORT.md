# Hyprland Port — Phase 1 (Compositor Configuration)

Status: **implemented, locally verified, not yet session-tested on a live Hyprland+iNiR
session** (this phase never switched the host compositor). Branch: `feat/hyprland-port`.

Phase 1 ports iNiR's *compositor configuration* from Niri
(`defaults/niri/config.kdl` + `config.d/`) to Hyprland's Lua config format
(`defaults/hypr/`), written strictly against the **installed Hyprland 0.56.2**
API. Shell-side QML adapters are **not** part of this phase (see
[Remaining work](#remaining-work)).

## Why Lua

Hyprland deprecated hyprlang config in 0.55; the config is now a Lua file
(`~/.config/hypr/hyprland.lua`) executed against the `hl.*` API. This port uses
that format exclusively. Verified sources for every `hl.*` call and config key:

- `/usr/share/hypr/stubs/hl.meta.lua` — official LuaLS stubs shipped with the package
- `/usr/share/hypr/hyprland.lua` — official example config shipped with the package
- The Hyprland wiki (Start, Dispatchers, Scrolling-Layout, Binds, Animations,
  Variables pages) and the `hyprland` binary itself (rule-keyword and
  expression-variable string tables)

No API name in this tree was invented; anything not directly verified is
commented out and labeled.

## File map (Niri → Hyprland)

| Niri source | Hyprland module | Content |
|---|---|---|
| `config.kdl` (top-level) | `hyprland.lua` | Entry, env vars, module loading |
| `10-input-and-cursor.kdl` | `inir/input.lua` (+ env in entry) | Keyboard, touchpad, cursor, gestures |
| `20-layout-and-overview.kdl` | `inir/general.lua`, `inir/decoration.lua` | Gaps, borders, scrolling layout, radius, shadow, opacity |
| `30-window-rules.kdl` | `inir/window_rules.lua` | Gaming, PiP, Steam toasts, xembedsniproxy |
| `40-environment.kdl` | `hyprland.lua` (`hl.env`) | XDG/Qt/Electron env, cursor theme |
| `50-startup.kdl` | `inir/autostart.lua` | sycoca rebuild, clipboard watchers |
| `60-animations.kdl` | `inir/decoration.lua` (curves/animations) | Bezier + spring conversions |
| `70-binds.kdl` | `inir/binds.lua` | All keybindings |
| `80-layer-rules.kdl` | `inir/layer_rules.lua` | Backdrop/iris layer surfaces |
| (commented `output` blocks) | `inir/monitors.lua` | Default catch-all monitor rule |
| `90-user-extra.kdl` | `~/.config/hypr/custom/overrides.lua` | User overrides (created by the user, never shipped, never overwritten) |
| — | `inir/misc.lua` | Hyprland-native settings mapped from niri behavior (dpms wake, focus_on_activate, scroll rate limit, XWayland scaling) |
| — | `inir/workspace_rules.lua` | Scaffold (niri ships no active workspace rules) |

## Key semantic decisions

- **Layout**: `general.layout = "scrolling"` — Hyprland's scrolling layout is the
  faithful counterpart of niri's scrollable tiling (column width 0.5, presets
  0.33/0.5/0.67 cycled by Mod+R, consume/expel/swapcol dispatchers).
- **Borderless**: niri draws no border and no focus ring (the shell draws its
  own highlights) → `border_size = 0`.
- **Environment**: `XDG_CURRENT_DESKTOP` is `"Hyprland"` (the session must
  advertise itself so portals pick `xdg-desktop-portal-hyprland`); every other
  variable mirrors `40-environment.kdl`, including `XDG_MENU_PREFIX "plasma-"`
  for the Dolphin/Qt "Open With" integration. Cursor theme/size moved to
  `XCURSOR_THEME`/`XCURSOR_SIZE` env (the `cursor.theme`/`cursor.size` config
  keys no longer exist in 0.56).
- **Springs**: niri's spring parameters were converted to Hyprland's spring
  model: `dampening = 2 · damping-ratio · √stiffness` (mass 1 on both sides).
  Animation speeds for springs are set near the physical settle time of the
  niri spring; duration animations use niri's ms values (`speed` is in
  deciseconds).
- **Quit**: `Mod+Shift+E` → `hl.dsp.exit()`. Niri shows a confirmation dialog;
  Hyprland quits directly (the wiki recommends replacing the dispatcher with
  `loginctl terminate-user ""` on uwsm-managed sessions — noted in the config).
- **Screenshots**: Hyprland has no native screenshot actions; all four niri
  Print binds route to `inir region menu` (the unified snip toolbar picks
  action and scope).
- **DPMS off**: follows the wiki's mandated pattern — the `hl.dsp.dpms` call is
  wrapped in a 500 ms one-shot `hl.timer`, never bound directly.

## Documented gaps (no Hyprland equivalent)

| Niri behavior | Status |
|---|---|
| `Mod+Tab` overview | No Hyprland overview in 0.56; iNiR's overlay stays on `Mod+Space` |
| `Mod+Escape` toggle-keyboard-shortcuts-inhibit | No runtime toggle; static escape hatch commented in `inir/misc.lua` |
| `Mod+Home/End` focus first/last column, `Mod+Ctrl+Home/End` move to first/last | No dispatcher; left unbound with comments |
| `Mod+Shift+Up/Down/J/K` reorder window within column | Scrolling layout has no such message |
| `Mod+Ctrl+R` reset height, `Mod+Shift+−/+=` set height | Scrolling layout has no window-height model |
| `Mod+Shift+V` switch focus floating↔tiling | No equivalent dispatcher |
| Horizontal wheel binds (`Mod+WheelScrollLeft/Right`) | Wheel binds are vertical-only |
| `block-out-from "screen-capture"` privacy rules | Hyprland permissions authorize binaries; no per-window capture blocking |
| Niri `recent-windows` Alt+Tab preview popup | `window.cycle_next` / `focus { last = true }` cycle without previews |
| Niri `always-center-single-column`, shadow `spread`, WezTerm default-width workaround | No equivalent options (approximations noted in-file) |
| Hot-corners gestures | Not supported by Hyprland |

Notable additions (Hyprland-native, labeled in-file): 3-finger workspace swipe
(niri has no touchpad workspace navigation), `scroll_event_delay = 150`
(port of niri's per-bind wheel `cooldown-ms`).

## Validation performed

1. `luac -p` on all 11 Lua files — clean.
2. `Hyprland --verify-config -c defaults/hypr/hyprland.lua` (installed 0.56.2
   binary) → **`config ok`**. Mutation-tested: the checker was proven to catch
   unknown config keys (`cursor.theme`), unknown keysyms, invalid dispatcher
   directions, and missing `require()`d modules; it does *not* validate
   layout-message strings or window-rule property names, which were instead
   verified against the wiki and the binary's rule-keyword tables.
3. `scripts/test-local-distribution.sh` gained a static `hyprland lua config`
   step (require-path invariant + `luac` + `--verify-config` when the binary
   exists; skips with a printed reason otherwise). The step is mutation-tested
   (missing module, commented requires, syntax error all fail).
4. `make test-local`: all steps pass except the **pre-existing** terminal
   palette failure (materialyoucolor venv bug — reproduces on the unmodified
   baseline; unrelated to this port).
5. `scripts/check-distro-parity.py origin/main HEAD` → pass (`origin/prerelease`
   does not exist on this fork's remote; `origin/main` used as base).
6. Niri trees: `git diff defaults/niri dots/.config/niri` shows only the
   pre-existing Dolphin migration — this port did not modify Niri config.

## Installation

`sdata/subcmd-install/3.files.sh` installs `defaults/hypr` → `~/.config/hypr`
**only when the `Hyprland` binary is present** and only when no Hyprland config
exists yet (a user's own `~/.config/hypr` — including legacy hyprlang setups
without `hyprland.lua` — is never synced over or deleted). On updates the
existing config is preserved, matching the Niri contract. The Qt platform
theme line is reconciled with plasma-integration detection exactly like the
Niri block. New option: `--skip-hypr`.

## Session startup (shell auto-init)

The single authoritative iNiR launch path under Hyprland:

1. `defaults/hypr/inir/autostart.lua` registers a `hyprland.start` bootstrap
   that publishes the full session environment — `WAYLAND_DISPLAY`,
   `XDG_SESSION_TYPE`, `XDG_CURRENT_DESKTOP`, `DISPLAY`,
   `HYPRLAND_INSTANCE_SIGNATURE`, `XDG_MENU_PREFIX` — into the systemd user
   manager **and** the D-Bus activation environment
   (`dbus-update-activation-environment --systemd`, with a
   `systemctl --user import-environment` fallback), then clears any
   failed/rate-limited state and starts `inir-hyprland.service`.
2. `assets/systemd/inir-hyprland.service` is deployed by
   `3.files.sh` with the launcher path resolved. Guards make every start
   context outside the bootstrap safe:
   - `ConditionEnvironment=HYPRLAND_INSTANCE_SIGNATURE` — skipped cleanly
     under other compositors/TTYs (no error, no crash loop).
   - `ExecStartPre` fails fast with an actionable diagnostic when
     `WAYLAND_DISPLAY` is missing or the Wayland socket does not exist —
     instead of Quickshell's `Failed to create wl_display` FATAL crash.
3. There are deliberately **no** wants links for this unit:
   `graphical-session.target` has `RefuseManualStart=yes` and is never
   active on a plain (non-UWSM) Hyprland session, so wiring could never
   launch the shell — and under another compositor with a stale
   `HYPRLAND_INSTANCE_SIGNATURE` it could start a duplicate. The bootstrap
   runs only inside Hyprland and systemd guarantees a single service
   instance, so config reloads and repeated logins cannot spawn duplicate
   shells. Logout ends the compositor; the service then fails its guard
   (bounded by the existing 3-in-30s rate limit) and the next login's
   bootstrap starts it fresh.

Regression coverage: `scripts/test-hyprland-session-startup.sh` (30 checks —
bootstrap contract, mocked end-to-end ordering, real `ExecStartPre` guard
behavior, installer deployment, stale-link cleanup), wired into
`scripts/test-local-distribution.sh` as the "hyprland session startup" step,
plus the suite-wide "qmldir singleton registration consistency" invariant.

**Update-path delivery for existing installs**: `./setup update` never ran
the Hyprland installer stage, and the installer's preserve-gate kept any
pre-existing `~/.config/hypr` untouched — so existing installs never
received the bootstrap. Two mechanisms close this: (1) `3.files.sh`
reconciles a tree that carries `.inir-manifest` (iNiR-owned) instead of
blanket-preserving it, and the manifest is generated *after* the `--delete`
sync (it was previously deleted by the sync itself, so fresh installs
silently ended up without one); (2) migration `045-hyprland-session-bootstrap`
performs the same reconcile during `./setup update`. User-owned Hyprland
configs (no manifest) are never overwritten.

## Remaining work (next phases)

- **Shell adapters**: `services/HyprlandService.qml` equivalents of
  `NiriService` (window/workspace IPC via `hyprctl -j`), keybind ingestion
  (display is ported via `hyprland-config.py get-binds`; the keybind
  *editor* — writing Lua bind lines — is still Niri-only), overview/window
  chips, and the remaining Settings UI toggles that today write niri config.
- **Settings: ported on Hyprland** (this phase): the compositor blur toggle
  with strength/grain/vibrancy (runtime `hyprctl eval hl.config(...)` +
  generated `custom/settings.lua` persistence, both verified on 0.56.2),
  keybind display/cheatsheet from active binds, and compositor-aware row
  gating in the iRiS settings (unported Niri sections are hidden rather
  than silently writing niri config).
- **Settings: still Niri-only** (hidden on Hyprland with truthful gating):
  the layout/borders/shape/input/animation-preset editors (the ii-family
  Compositor page, the Monitors layout editor, Autostart, the Alt-Tab
  source picker). Each needs a Hyprland settings backend writing the
  corresponding Lua config sections.
- **Runtime blur**: DONE for the global blur —
  `scripts/hyprland-config.py set blur …` writes `decoration.blur.*`
  (runtime eval + persistent `custom/settings.lua`). The niri
  `background-effect` *window-rule* semantics (xray, border-behind, per-app
  opacity) have no direct Hyprland equivalent and remain Niri-only;
  `inir/layer_rules.lua` layer blur stays commented pending that adapter.
- **`inir service enable` CLI** is still Niri-scoped
  (`detect_compositor_service` in `scripts/inir` returns only
  `niri.service`); under Hyprland the install flow wires everything and the
  bootstrap owns startup, so the CLI is not on the auto-init path.
- **Live session test** on a real Hyprland session (bindings dispatchers,
  scrolling layout messages, Steam toast anchoring, layer stacking).

## User extension point

Personal overrides go into `~/.config/hypr/custom/overrides.lua` (loaded via
`pcall(require, ...)` — a missing file is fine, and iNiR updates never touch
that directory). This is the Hyprland counterpart of niri's
`90-user-extra.kdl`.
