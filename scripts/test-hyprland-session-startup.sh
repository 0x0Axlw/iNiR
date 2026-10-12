#!/usr/bin/env bash
# Regression tests for the iNiR Hyprland auto-startup path.
#
# Reproduces the original failure mode: Quickshell launched without a
# published Wayland session environment ("Failed to create wl_display /
# no Qt platform plugin could be initialized"). The root cause was that
# plain Hyprland sessions never activate graphical-session.target and the
# hyprland.start bootstrap published only XDG_MENU_PREFIX, so the systemd
# user manager / D-Bus activation environment had no WAYLAND_DISPLAY.
#
# All external effects are mocked: systemctl and
# dbus-update-activation-environment are stubbed in a sandbox PATH. No real
# session state, packages, or services are touched.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"

hypr_config="$runtime_root/defaults/hypr/inir/autostart.lua"
hypr_unit="$runtime_root/assets/systemd/inir-hyprland.service"
niri_unit="$runtime_root/assets/systemd/inir.service"
setup_script="$runtime_root/setup"
files_installer="$runtime_root/sdata/subcmd-install/3.files.sh"

_pass=0
_fail=0
check() { # <description> <command...>
    local desc="$1"
    shift
    if "$@"; then
        _pass=$((_pass + 1))
        printf 'PASS: %s\n' "$desc"
    else
        _fail=$((_fail + 1))
        printf 'FAIL: %s\n' "$desc"
    fi
}
check_not() { # <description> <command...> — passes when the command fails
    local desc="$1"
    shift
    if "$@"; then
        _fail=$((_fail + 1))
        printf 'FAIL: %s\n' "$desc"
    else
        _pass=$((_pass + 1))
        printf 'PASS: %s\n' "$desc"
    fi
}

#####################################################################################
# Extract the production bootstrap command (single source of truth).
#####################################################################################
bootstrap="$(grep -F 'dbus-update-activation-environment' "$hypr_config" | head -1 \
    | sed -e 's/^.*hl.exec_cmd("//' -e 's/")$//')"
check "bootstrap command is present in autostart.lua" test -n "$bootstrap"

#####################################################################################
# Static contract: bootstrap publishes the session environment and starts the
# service through systemd — the single authoritative launch path.
#####################################################################################
check "bootstrap updates the D-Bus + systemd activation environment" \
    grep -qF 'dbus-update-activation-environment --systemd' <<<"$bootstrap"
check "bootstrap publishes WAYLAND_DISPLAY" grep -qwF 'WAYLAND_DISPLAY' <<<"$bootstrap"
check "bootstrap publishes XDG_SESSION_TYPE" grep -qwF 'XDG_SESSION_TYPE' <<<"$bootstrap"
check "bootstrap publishes XDG_CURRENT_DESKTOP" grep -qwF 'XDG_CURRENT_DESKTOP' <<<"$bootstrap"
check "bootstrap publishes HYPRLAND_INSTANCE_SIGNATURE" grep -qwF 'HYPRLAND_INSTANCE_SIGNATURE' <<<"$bootstrap"
check "bootstrap has a systemctl import-environment fallback" \
    grep -qF 'systemctl --user import-environment' <<<"$bootstrap"
check "bootstrap clears a failed/rate-limited state before starting" \
    grep -qF 'systemctl --user reset-failed inir-hyprland.service' <<<"$bootstrap"
check "bootstrap starts inir-hyprland.service (exactly once)" \
    bash -c "[[ \$(grep -oF 'systemctl --user start inir-hyprland.service' <<<\"\$1\" | wc -l) -eq 1 ]]" _ "$bootstrap"
check_not "bootstrap never starts graphical-session.target (RefuseManualStart=yes)" \
    grep -qF 'start graphical-session.target' <<<"$bootstrap"
check_not "autostart.lua does not spawn the shell directly (no duplicate launch)" \
    grep -Eq 'hl\.exec_cmd\("(qs |quickshell|inir run)' "$hypr_config"

#####################################################################################
# Static contract: unit guards — every start context outside the bootstrap
# fails fast with a clear diagnostic instead of a Wayland FATAL crash.
#####################################################################################
check "unit requires a Hyprland session (ConditionEnvironment)" \
    grep -qF 'ConditionEnvironment=HYPRLAND_INSTANCE_SIGNATURE' "$hypr_unit"
check "unit has an ExecStartPre Wayland environment guard" \
    grep -qF 'ExecStartPre=' "$hypr_unit" && grep -Fq 'WAYLAND_DISPLAY' "$hypr_unit"
hypr_unit_grep_niri() { ! grep -qi 'niri' "$hypr_unit"; }
check "unit has no Niri-specific coupling (Requisite/PartOf niri)" hypr_unit_grep_niri
niri_unit_still_wired() { grep -qF 'Requisite=niri.service' "$niri_unit"; }
check "Niri inir.service keeps its niri.service coupling (unchanged)" niri_unit_still_wired

#####################################################################################
# Static contract: installer actually deploys the unit and the wiring function
# cleans stale wants links instead of creating dead ones.
#####################################################################################
check "3.files.sh copies the unit into the user systemd directory" \
    grep -qF 'cp -f "$hypr_tmp" "$hypr_service_target"' "$files_installer"
check "3.files.sh resolves the launcher path in the deployed unit" \
    grep -qF 'ExecStart=' "$files_installer" && grep -Fq 'hypr_launcher' "$files_installer"
check "3.files.sh reloads the user manager after deploying the unit" \
    grep -qF 'systemctl --user daemon-reload' "$files_installer"
service_wiring_function="$(sed -n '/^ensure_user_inir_service_enabled() {/,/^}/p' "$setup_script")"
check "ensure_user_inir_service_enabled removes stale inir-hyprland wants links" \
    grep -qF 'link="$wants_dir/inir-hyprland.service"' <<<"$service_wiring_function"
wiring_no_target_wants() { ! grep -qF 'graphical-session.target.wants' <<<"$service_wiring_function"; }
check "wiring no longer creates graphical-session.target.wants links" wiring_no_target_wants

#####################################################################################
# Functional: run the REAL bootstrap command with mocked systemctl and
# dbus-update-activation-environment. Assert ordering — the environment
# publication MUST happen before the service start, or the service inherits
# the env-less context that produced the original wl_display crash.
#####################################################################################
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/runtime"
export MOCK_LOG="$sandbox/mock.log"
: > "$MOCK_LOG"

cat > "$sandbox/bin/dbus-update-activation-environment" <<'MOCK'
#!/usr/bin/env bash
printf 'dbus-update %s\n' "$*" >> "$MOCK_LOG"
MOCK
cat > "$sandbox/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$MOCK_LOG"
case "$1 $2" in
    "--user reset-failed") exit 0 ;;
    "--user start") [[ -n "${MOCK_START_FAILS:-}" ]] && exit 1 || exit 0 ;;
    *) exit 0 ;;
esac
MOCK
chmod +x "$sandbox/bin/dbus-update-activation-environment" "$sandbox/bin/systemctl"

export PATH="$sandbox/bin:$PATH"
export XDG_RUNTIME_DIR="$sandbox/runtime"
export WAYLAND_DISPLAY=wayland-1
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland
export HYPRLAND_INSTANCE_SIGNATURE=regression-test-signature
export DISPLAY=:0

sh -c "$bootstrap"
check "bootstrap completes successfully under a valid session environment" test -s "$MOCK_LOG"

dbus_line="$(grep -m1 '^dbus-update' "$MOCK_LOG" || true)"
check "mocked dbus-update-activation-environment received --systemd and the session vars" \
    bash -c 'test -n "$1" && grep -qF -- "--systemd" <<<"$1" && grep -qwF "WAYLAND_DISPLAY" <<<"$1" && grep -qwF "HYPRLAND_INSTANCE_SIGNATURE" <<<"$1"' _ "$dbus_line"

dbus_order="$(grep -nm1 '^dbus-update' "$MOCK_LOG" | cut -d: -f1)"
start_order="$(grep -nm1 'systemctl --user start inir-hyprland.service' "$MOCK_LOG" | cut -d: -f1)"
check "environment publication happens BEFORE the service start (no env-less launch)" \
    bash -c 'test -n "$1" && test -n "$2" && (( "$1" < "$2" ))' _ "$dbus_order" "$start_order"
check "bootstrap cleared any failed/rate-limited state before starting" \
    grep -qF 'systemctl --user reset-failed inir-hyprland.service' "$MOCK_LOG"
check_not "bootstrap did not touch graphical-session.target" \
    grep -qF 'graphical-session.target' "$MOCK_LOG"

# Graceful degradation: unit missing/unstartable must not abort the bootstrap
# (env publication still happened; start failure surfaces in the journal).
: > "$MOCK_LOG"
if MOCK_START_FAILS=1 sh -c "$bootstrap"; then
    bootstrap_rc=0
else
    bootstrap_rc=1
fi
check "bootstrap stays graceful when the service unit is missing" \
    test "$bootstrap_rc" -eq 0 && grep -q '^dbus-update' "$MOCK_LOG"

#####################################################################################
# Functional: the REAL ExecStartPre guard from the unit. A missing/invalid
# Wayland environment must produce a clear, controlled failure (non-zero exit
# with an actionable message) — never a doomed Quickshell launch.
#####################################################################################
guard="$(grep '^ExecStartPre=' "$hypr_unit" | head -1 | sed 's/^ExecStartPre=//')"
check "ExecStartPre guard extracted from the production unit" test -n "$guard"

# A real (empty) AF_UNIX socket so test -S can pass for the valid case.
python3 - "$XDG_RUNTIME_DIR/wayland-1" <<'PY'
import socket
import sys

sock = socket.socket(socket.AF_UNIX)
sock.bind(sys.argv[1])
PY

guard_msg="$(unset WAYLAND_DISPLAY; bash -c "$guard" 2>&1)" && guard_rc=0 || guard_rc=$?
check "missing WAYLAND_DISPLAY fails the guard with a diagnostic" \
    bash -c '[[ "$1" -ne 0 && "$2" == *"WAYLAND_DISPLAY is not set"* ]]' _ "$guard_rc" "$guard_msg"

guard_msg="$(WAYLAND_DISPLAY=wayland-9 bash -c "$guard" 2>&1)" && guard_rc=0 || guard_rc=$?
check "nonexistent Wayland socket fails the guard with a diagnostic" \
    bash -c '[[ "$1" -ne 0 && "$2" == *"does not exist"* ]]' _ "$guard_rc" "$guard_msg"

bash -c "$guard" >/dev/null 2>&1
check "valid session environment (WAYLAND_DISPLAY + real socket) passes the guard" test $? -eq 0

#####################################################################################
# Summary
#####################################################################################
printf '\nHyprland session startup: %d passed, %d failed\n' "$_pass" "$_fail"
[[ "$_fail" -eq 0 ]]
