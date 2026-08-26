#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIVE_HYPR = Path("/home/cole/.config/hypr/hyprland.lua")
DOTFILES_HYPR = Path("/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua")

EXPECTED_BINDINGS = (
    'hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs -p /home/cole/Projects/titonium ipc call spotlight clipboard"))',
    'hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("qs -p /home/cole/Projects/titonium ipc call spotlight toggle"))',
)


def main() -> int:
    errors: list[str] = []

    for path in (LIVE_HYPR, DOTFILES_HYPR):
        if not path.is_file():
            errors.append(f"missing protected Hyprland config: {path}")
            continue
        source = path.read_text(encoding="utf-8")
        for binding in EXPECTED_BINDINGS:
            if source.count(binding) != 1:
                errors.append(f"{path}: expected exactly one protected binding: {binding}")

    acceptance = ROOT / "scripts/protected_acceptance.sh"
    if not acceptance.is_file():
        errors.append("missing scripts/protected_acceptance.sh")

    if errors:
        print("FAIL protected contract")
        print("\n".join(errors))
        return 1

    print("PASS protected contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
