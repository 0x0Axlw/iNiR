# Validates the Arch/CachyOS Hyprland-first installer package plan.
#
# Separates two concerns the previous validator conflated:
#   1. The iNiR installer package plan (global array _arch_plan) — what iNiR
#      will install. This is the source of truth for hard pass/fail.
#   2. Packages already present on the user's system — informational only.
#      Unwanted-but-installed portals are warned about, never removed, and
#      never fail installation (other desktop integrations may need them).
#
# Required components (hyprland, xdg-desktop-portal-hyprland, a Quickshell
# provider) are satisfied if they are in the plan OR already installed.
#
# Sourced by sdata/dist-arch/install-deps.sh. Directly unit-tested by
# scripts/test-arch-package-plan.sh with a mocked pkg_installed() so no real
# system state is read or changed.

# Packages that must never be selected by the default iNiR plan.
ARCH_EXCLUDED_PACKAGES=(
  niri
  niri-focused-booster
  mission-center
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
)

# Quickshell variants that satisfy the shell requirement.
ARCH_QUICKSHELL_PROVIDERS=(
  quickshell
  quickshell-git
  quickshell-bin
  illogical-impulse-quickshell-git
)

# Portal backends the default plan is allowed to select.
ARCH_ALLOWED_PORTAL_BACKENDS=(
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-kde
)

# Unwanted portal backends: excluded from the plan, warned if installed.
ARCH_UNWANTED_PORTAL_BACKENDS=(
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
)

# Return 0 if a package is installed on the system.
# Tests override this function with a mock; never call pacman directly here.
pkg_installed() {
  pacman -Qi "$1" &>/dev/null
}

# Return 0 if $1 appears in the global plan array _arch_plan.
_plan_contains() {
  printf '%s\n' "${_arch_plan[@]}" | grep -qx "$1"
}

# Validate the installer package plan held in the global _arch_plan array.
# Returns 0 when the plan is valid, 1 when the plan itself is invalid.
# Installed-but-unwanted packages only emit a warning and never fail.
validate_arch_package_plan() {
  local rc=0
  local pkg a allowed

  # --- Excluded packages: hard fail only if the plan selects them. ---
  local excluded_found=()
  for pkg in "${ARCH_EXCLUDED_PACKAGES[@]}"; do
    if _plan_contains "$pkg"; then
      excluded_found+=("$pkg")
    fi
  done
  if [[ ${#excluded_found[@]} -gt 0 ]]; then
    log_error "Excluded packages found in install plan: ${excluded_found[*]}"
    rc=1
  else
    log_success "Excluded packages correctly absent from installer plan"
  fi

  # --- Portal backends: plan must select only allowed backends. ---
  local plan_portals=()
  for pkg in "${_arch_plan[@]}"; do
    [[ "$pkg" == xdg-desktop-portal-* ]] && plan_portals+=("$pkg")
  done
  log_info "XDG portal backends in installer plan: ${plan_portals[*]:-none}"

  for pkg in "${plan_portals[@]}"; do
    allowed=false
    for a in "${ARCH_ALLOWED_PORTAL_BACKENDS[@]}"; do
      [[ "$pkg" == "$a" ]] && { allowed=true; break; }
    done
    if ! $allowed; then
      log_error "Unwanted portal backend selected by installer plan: $pkg"
      rc=1
    fi
  done

  # --- Required components: satisfied if in plan OR already installed. ---
  if ! _plan_contains hyprland && ! pkg_installed hyprland; then
    log_error "Required component missing (not in plan, not installed): hyprland"
    rc=1
  fi
  if ! _plan_contains xdg-desktop-portal-hyprland \
      && ! pkg_installed xdg-desktop-portal-hyprland; then
    log_error "Required component missing (not in plan, not installed): xdg-desktop-portal-hyprland"
    rc=1
  fi
  # Quickshell: any compatible provider in plan OR installed counts.
  local qs_ok=false
  for pkg in "${ARCH_QUICKSHELL_PROVIDERS[@]}"; do
    if _plan_contains "$pkg" || pkg_installed "$pkg"; then
      qs_ok=true
      break
    fi
  done
  if ! $qs_ok; then
    log_error "Required component missing (no Quickshell provider in plan or installed)"
    rc=1
  fi

  # --- Diagnostic: unwanted portals already installed (warn only). ---
  # These are not selected by iNiR and are left untouched; other apps may
  # legitimately need them, so presence alone must never fail installation.
  for pkg in "${ARCH_UNWANTED_PORTAL_BACKENDS[@]}"; do
    if pkg_installed "$pkg"; then
      log_warning "$pkg is installed on this system (not selected by iNiR; left untouched)"
    fi
  done

  return $rc
}
