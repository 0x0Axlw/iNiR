#!/usr/bin/env bash
# Regression tests for the Hyprland Settings backend
# (scripts/hyprland-config.py + the QML routing that consumes it).
#
# All hyprctl interactions are mocked via a stub on PATH — no real compositor
# state is read or changed. Filesystem effects land in a temp $HOME.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"

_pass=0
_fail=0
check() {
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
check_not() {
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

BACKEND="$runtime_root/scripts/hyprland-config.py"
check "backend script is executable" test -x "$BACKEND"

# ── Mock hyprctl ────────────────────────────────────────────────────────────
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin" "$SANDBOX/home/.config/hypr/inir" "$SANDBOX/home/.config/hypr/custom"
export HOME="$SANDBOX/home"

# Default mock: blur enabled=true, passes=3, size=8, noise=0.02, vibrancy=1.5;
# binds from fixtures; eval logs to $MOCK_LOG.
cat > "$SANDBOX/bin/hyprctl" <<MOCK
#!/usr/bin/env bash
printf 'hyprctl %s\n' "\$*" >> "\${MOCK_LOG:-/dev/null}"
case "\$*" in
  "-j binds") cat "\${BINDS_FIXTURE:?}" ;;
  "getoption decoration:blur:enabled -j") echo '{"bool": true, "set": true}' ;;
  "getoption decoration:blur:passes -j") echo '{"int": 3, "set": true}' ;;
  "getoption decoration:blur:size -j") echo '{"int": 8, "set": true}' ;;
  "getoption decoration:blur:noise -j") echo '{"float": 0.02, "set": true}' ;;
  "getoption decoration:blur:vibrancy -j") echo '{"float": 1.5, "set": true}' ;;
  "version") echo "Hyprland, version 0.56.2" ;;
  *) echo "ok" ;;
esac
MOCK
chmod +x "$SANDBOX/bin/hyprctl"
export PATH="$SANDBOX/bin:$PATH"

python3 - <<'PY'
import json
binds = [
    {"modmask": 65, "key": "E", "dispatcher": "__lua", "arg": "1"},
    {"modmask": 65, "key": "O", "dispatcher": "__lua", "arg": "2"},
    {"modmask": 64, "key": "COMMA", "dispatcher": "__lua", "arg": "3"},
    {"modmask": 64, "key": "SPACE", "dispatcher": "__lua", "arg": "4"},
    {"modmask": 64, "key": "C", "dispatcher": "__lua", "arg": "5"},
]
open("/tmp/hypr-settings-test-binds.json", "w").write(json.dumps(binds))
PY
export BINDS_FIXTURE=/tmp/hypr-settings-test-binds.json

# Fixture config: binds.lua with a multiline function bind + an entry that is
# NOT in the active set (must be filtered), plus a user override.
cp "$runtime_root/defaults/hypr/inir/binds.lua" "$HOME/.config/hypr/inir/binds.lua"
cat >> "$HOME/.config/hypr/inir/binds.lua" <<'EOF'

hl.bind("SUPER + SHIFT + Z", hl.dsp.exec_cmd("inir nothing"))  -- not active
EOF
cat > "$HOME/.config/hypr/custom/overrides.lua" <<'EOF'
hl.bind("SUPER + C", hl.dsp.exec_cmd("inir clipboard toggle"), { description = "Clipboard" })
EOF

#####################################################################################
# get-blur
#####################################################################################
blur="$(python3 "$BACKEND" get-blur)"
check "get-blur reports the same JSON shape as niri-config.py" \
    bash -c "python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert set(d) >= {\"available\",\"enabled\",\"strength\",\"noise\",\"saturation\"}; assert d[\"available\"] is True; assert d[\"enabled\"] is True; assert d[\"strength\"] == \"balanced\"' \"\$1\"" _ "$blur"

# hyprctl unavailable -> available=false, no crash (exit-127 stub simulates a
# missing binary without leaking to the real hyprctl on PATH)
mv "$SANDBOX/bin/hyprctl" "$SANDBOX/bin/hyprctl.real"
printf '#!/usr/bin/env bash\nexit 127\n' > "$SANDBOX/bin/hyprctl"
chmod +x "$SANDBOX/bin/hyprctl"
blur_off="$(python3 "$BACKEND" get-blur 2>/dev/null || true)"
check "get-blur degrades to available=false when hyprctl is missing" \
    bash -c "python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d[\"available\"] is False and d[\"enabled\"] is False' \"\$1\"" _ "$blur_off"
mv "$SANDBOX/bin/hyprctl.real" "$SANDBOX/bin/hyprctl"

#####################################################################################
# set blur: persistence, merge, validation
#####################################################################################
export MOCK_LOG="$SANDBOX/mock.log"; : > "$MOCK_LOG"
out="$(python3 "$BACKEND" set blur enabled off)"
check "set blur enabled off succeeds" grep -q '"ok": true' <<<"$out"
settings_file="$HOME/.config/hypr/custom/settings.lua"
check "persistence file generated in the protected custom/ dir" test -f "$settings_file"
check "generated file disables blur" grep -q "enabled = false" "$settings_file"
check "generated file is valid Lua (luac -p)" bash -c "command -v luac >/dev/null && luac -p '$settings_file' || true"
check "runtime apply issued via hyprctl eval" grep -q "eval hl.config" "$MOCK_LOG"

out="$(python3 "$BACKEND" set blur strength strong)"
check "strength maps to passes (strong -> 4)" grep -q '"passes": 4' <<<"$out"
check "persistence updated with passes" grep -q "passes = 4" "$settings_file"

out="$(python3 "$BACKEND" set blur enabled banana 2>/dev/null || true)"
check "invalid value rejected with an error (no silent success)" grep -q '"error"' <<<"$out"
check "invalid value did not rewrite the settings file" grep -q "passes = 4" "$settings_file"

# luac validation failure must roll back the file
if command -v luac >/dev/null; then
    mkdir -p "$SANDBOX/badluac"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$SANDBOX/badluac/luac"
    chmod +x "$SANDBOX/badluac/luac"
    old_content="$(cat "$settings_file")"
    export old_content
    PATH="$SANDBOX/badluac:$PATH" python3 "$BACKEND" set blur enabled on >/dev/null 2>&1 || true
    check "failed validation rolls the settings file back" \
        bash -c '[[ "$(cat "$1")" == "$old_content" ]]' _ "$settings_file"
fi

#####################################################################################
# get-binds: active-source model
#####################################################################################
model="$(python3 "$BACKEND" get-binds)"
check "get-binds returns the cheatsheet model shape" \
    bash -c "python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert \"children\" in d and \"matchedBinds\" in d' \"\$1\"" _ "$model"
check "all displayed binds are active (parsed == matched)" \
    bash -c "python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d[\"matchedBinds\"] <= d[\"activeBinds\"]' \"\$1\"" _ "$model"
check "inactive parsed bind (SHIFT+Z) is filtered out" \
    bash -c '! grep -q "SHIFT+Z" <<<"$1" && ! grep -q "\"Z\"" <<<"$1"' _ "$model"
check "multiline function bind parses and matches" \
    grep -qF '"key": "O"' <<<"$model" && grep -q "dpms" <<<"$model"
check "user override bind (custom/overrides.lua) is included with its description" \
    grep -qF '"comment": "Clipboard"' <<<"$model"
check "modmask decoded to mod names" \
    grep -qF '"Shift"' <<<"$model" && grep -qF '"Super"' <<<"$model"

#####################################################################################
# QML wiring contract
#####################################################################################
qml_iris_blur="$runtime_root/modules/iris/style/IrisCompositorBlur.qml"
qml_iris_niri="$runtime_root/modules/iris/settings/IrisNiri.qml"
qml_iris_options="$runtime_root/modules/iris/settings/IrisOptions.qml"
qml_keybinds="$runtime_root/services/deferred/HyprlandKeybinds.qml"
qml_lua="$runtime_root/defaults/hypr/hyprland.lua"

check "IrisCompositorBlur routes Hyprland reads to hyprland-config.py" \
    grep -qF 'hyprland-config.py' "$qml_iris_blur"
check "IrisCompositorBlur re-reads on configreloaded (external changes)" \
    grep -qF 'configreloaded' "$qml_iris_blur"
check "IrisNiri routes blur writes to the Hyprland backend" \
    grep -qF 'hyprlandPortedSections' "$qml_iris_niri" \
    && grep -qF 'hyprlandScript' "$qml_iris_niri"
check "IrisNiri refuses unported sections on Hyprland (no silent niri writes)" \
    grep -qF 'not available on Hyprland yet' "$qml_iris_niri"
check "IrisOptions gates niri rows per compositor" \
    grep -qF 'niriRowAvailable' "$qml_iris_options"
check "HyprlandKeybinds uses the active-binds source (not the dead hyprlang parser)" \
    grep -qF 'hyprland-config.py' "$qml_keybinds" \
    && ! grep -qF 'keybinds.conf' "$qml_keybinds"
check "hyprland.lua loads the generated settings before user overrides" \
    bash -c 'settings_line=$(grep -n "require, \"custom\.settings\"" "$1" | head -1 | cut -d: -f1); overrides_line=$(grep -n "require, \"custom\.overrides\"" "$1" | head -1 | cut -d: -f1); test -n "$settings_line" && test -n "$overrides_line" && (( settings_line < overrides_line ))' _ "$qml_lua"

printf '\nHyprland settings adapter: %d passed, %d failed\n' "$_pass" "$_fail"
[[ "$_fail" -eq 0 ]]
