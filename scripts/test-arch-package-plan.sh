#!/usr/bin/env bash
# Regression tests for the Arch/CachyOS Hyprland-first installer package
# plan validation (sdata/dist-arch/package-plan-validation.sh).
#
# These tests run in an isolated fixture: pkg_installed() is overridden with a
# mock backed by an in-memory associative array, so NO real system state is
# read and NO package is installed or removed. The real pacman is never
# invoked.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"

# --- Stubs for the logging helpers the validation function calls. ---
# Captured into variables so tests can assert on messages if needed.
_log_output=""
log_error()   { _log_output+="ERROR: $*\n"; }
log_success() { _log_output+="OK: $*\n"; }
log_warning() { _log_output+="WARN: $*\n"; }
log_info()    { _log_output+="INFO: $*\n"; }

# --- Source the unit under test. ---
# shellcheck source=../sdata/dist-arch/package-plan-validation.sh
source "$runtime_root/sdata/dist-arch/package-plan-validation.sh"

# --- Mock the package database. ---
# pkg_installed() is redefined to read from this associative array instead of
# calling pacman. This is the ONLY isolation point; the validation logic under
# test is the real production code.
declare -A MOCK_INSTALLED=()
pkg_installed() { [[ -n "${MOCK_INSTALLED[$1]:+_}" ]]; }

# reset_fixture clears all mocks and the plan array between scenarios.
reset_fixture() {
  MOCK_INSTALLED=()
  _arch_plan=()
  _log_output=""
}

_pass=0
_fail=0

# assert_exit <expected_rc> <description> — runs validate_arch_package_plan and
# compares its return code to the expectation.
assert_exit() {
  local expected="$1" desc="$2" actual
  if validate_arch_package_plan >/dev/null 2>&1; then
    actual=0
  else
    actual=$?
  fi
  if [[ "$actual" -eq "$expected" ]]; then
    _pass=$((_pass + 1))
    printf 'PASS: %s\n' "$desc"
  else
    _fail=$((_fail + 1))
    printf 'FAIL: %s (expected rc=%s, got rc=%s)\n' "$desc" "$expected" "$actual"
    [[ -n "$_log_output" ]] && printf '%s' "$_log_output"
  fi
}

# assert_log_contains <needle> <description> — asserts the last run logged a
# line containing <needle>.
assert_log_contains() {
  local needle="$1" desc="$2"
  if printf '%b' "$_log_output" | grep -qF "$needle"; then
    _pass=$((_pass + 1))
    printf 'PASS: %s\n' "$desc"
  else
    _fail=$((_fail + 1))
    printf 'FAIL: %s (log missing %q)\n' "$desc" "$needle"
  fi
}

#####################################################################################
# Scenario 1: Required packages already installed, absent from pending list.
# hyprland + portal-hyprland are installed; plan only carries quickshell.
#####################################################################################
reset_fixture
MOCK_INSTALLED[hyprland]=1
MOCK_INSTALLED[xdg-desktop-portal-hyprland]=1
_arch_plan=(quickshell)
assert_exit 0 "required packages installed (not in pending plan) pass"
assert_log_contains "Excluded packages correctly absent" \
  "excluded-package check passes on a clean plan"

#####################################################################################
# Scenario 2: Required packages absent from system, present in the plan.
#####################################################################################
reset_fixture
MOCK_INSTALLED=()
_arch_plan=(quickshell hyprland xdg-desktop-portal xdg-desktop-portal-hyprland)
assert_exit 0 "required packages absent but present in plan pass"

#####################################################################################
# Scenario 3: Custom illogical-impulse-quickshell-git satisfies Quickshell.
# No official quickshell in plan; the custom package is installed.
#####################################################################################
reset_fixture
MOCK_INSTALLED[illogical-impulse-quickshell-git]=1
MOCK_INSTALLED[hyprland]=1
MOCK_INSTALLED[xdg-desktop-portal-hyprland]=1
_arch_plan=()
assert_exit 0 "custom illogical-impulse-quickshell-git satisfies Quickshell"

# Also verify quickshell-git and quickshell-bin providers are accepted.
reset_fixture
MOCK_INSTALLED[quickshell-git]=1
MOCK_INSTALLED[hyprland]=1
MOCK_INSTALLED[xdg-desktop-portal-hyprland]=1
_arch_plan=()
assert_exit 0 "quickshell-git provider is accepted"

reset_fixture
MOCK_INSTALLED[quickshell-bin]=1
MOCK_INSTALLED[hyprland]=1
MOCK_INSTALLED[xdg-desktop-portal-hyprland]=1
_arch_plan=()
assert_exit 0 "quickshell-bin provider is accepted"

#####################################################################################
# Scenario 4: Genuinely missing required component must still fail.
# Nothing installed, nothing in plan -> hyprland + portal-hyprland + quickshell
# are all missing.
#####################################################################################
reset_fixture
MOCK_INSTALLED=()
_arch_plan=(some-unrelated-pkg)
assert_exit 1 "missing hyprland/portal/quickshell still fails"
assert_log_contains "Required component missing" \
  "missing required component is reported"

# Missing ONLY quickshell (hyprland + portal present) must still fail.
reset_fixture
MOCK_INSTALLED[hyprland]=1
MOCK_INSTALLED[xdg-desktop-portal-hyprland]=1
_arch_plan=()
assert_exit 1 "missing Quickshell (no provider anywhere) still fails"

#####################################################################################
# Scenario 5: Default plan retains Hyprland + KDE portals and excludes unwanted.
#####################################################################################
reset_fixture
_arch_plan=(
  quickshell
  hyprland
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-kde
)
assert_exit 0 "default Hyprland/KDE portal plan is valid"
assert_log_contains "xdg-desktop-portal-hyprland xdg-desktop-portal-kde" \
  "plan reports the Hyprland + KDE portal backends"

#####################################################################################
# Scenario 6: GTK portal absent from plan PASSES even if installed locally.
# This is the regression that previously aborted installation. The GTK portal
# is installed on the system but is NOT in the iNiR plan -> warn only, no fail.
#####################################################################################
reset_fixture
MOCK_INSTALLED[xdg-desktop-portal-gtk]=1
MOCK_INSTALLED[hyprland]=1
MOCK_INSTALLED[xdg-desktop-portal-hyprland]=1
_arch_plan=(quickshell xdg-desktop-portal-hyprland xdg-desktop-portal-kde)
assert_exit 0 "GTK portal installed locally but absent from plan PASSES"
assert_log_contains "xdg-desktop-portal-gtk is installed on this system" \
  "installed GTK portal emits a warning"

#####################################################################################
# Scenario 7: GTK portal PRESENT in the installer plan FAILS validation.
#####################################################################################
reset_fixture
MOCK_INSTALLED=()
_arch_plan=(
  quickshell
  hyprland
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
)
assert_exit 1 "GTK portal present in installer plan FAILS"
assert_log_contains "Unwanted portal backend selected by installer plan: xdg-desktop-portal-gtk" \
  "plan-selected GTK portal is reported"

#####################################################################################
# Scenario 8: GNOME portal remains excluded from the installer plan.
#####################################################################################
reset_fixture
MOCK_INSTALLED=()
_arch_plan=(
  quickshell
  hyprland
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gnome
)
assert_exit 1 "GNOME portal present in installer plan FAILS"

# GNOME portal installed locally but not in the plan -> warn only, no fail.
reset_fixture
MOCK_INSTALLED[xdg-desktop-portal-gnome]=1
MOCK_INSTALLED[hyprland]=1
MOCK_INSTALLED[xdg-desktop-portal-hyprland]=1
_arch_plan=(quickshell xdg-desktop-portal-hyprland xdg-desktop-portal-kde)
assert_exit 0 "GNOME portal installed locally but absent from plan PASSES"

#####################################################################################
# Scenario 9: Excluded packages (niri, niri-focused-booster, mission-center)
# must be absent from the plan.
#####################################################################################
reset_fixture
_arch_plan=(quickshell hyprland niri xdg-desktop-portal-hyprland)
assert_exit 1 "niri present in installer plan FAILS"
assert_log_contains "Excluded packages found in install plan: niri" \
  "niri exclusion is reported"

reset_fixture
_arch_plan=(quickshell hyprland mission-center xdg-desktop-portal-hyprland)
assert_exit 1 "mission-center present in installer plan FAILS"

reset_fixture
_arch_plan=(quickshell hyprland niri-focused-booster xdg-desktop-portal-hyprland)
assert_exit 1 "niri-focused-booster present in installer plan FAILS"

#####################################################################################
# Summary
#####################################################################################
printf '\nArch package-plan validation: %d passed, %d failed\n' "$_pass" "$_fail"
[[ "$_fail" -eq 0 ]]
