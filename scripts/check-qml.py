#!/usr/bin/env python3
"""Resolve the installed Omarchy QML modules without modifying them."""
from pathlib import Path
import json
import re
import subprocess
import tempfile

shell = Path("/usr/share/omarchy/shell")


def inline_members(file, group):
    source = file.read_text()
    match = re.search(r"property QtObject " + group + r": QtObject\s*\{", source)
    if not match:
        raise RuntimeError(f"Missing Omarchy token group: {group}")
    start = match.end()
    end = source.index("\n  }", start)
    return set(re.findall(r"property\s+\w+\s+(\w+)\s*:", source[start:end]))


# Omarchy declares these inline objects as QtObject; qmllint cannot infer
# their members. Check each referenced member against the real QML source.
groups = {
    "Style.font": inline_members(shell / "Commons/Style.qml", "font"),
    "Style.spacing": inline_members(shell / "Commons/Style.qml", "spacing"),
    "Color.popups": inline_members(shell / "Commons/Color.qml", "popups"),
}
with tempfile.TemporaryDirectory(prefix="otuple-qml-") as folder:
    (Path(folder) / "qs").symlink_to(shell, target_is_directory=True)
    report = Path(folder) / "report.json"
    result = subprocess.run(["/usr/lib/qt6/bin/qmllint", "-I", folder, "--json", str(report), *map(str, sorted(Path("qml").glob("*.qml")))], capture_output=True, text=True)
    problems = []
    checked = 0
    for file in json.loads(report.read_text())["files"]:
        lines = Path(file["filename"]).read_text().splitlines()
        for warning in file["warnings"]:
            line = lines[warning["line"] - 1]
            member = re.fullmatch(r'Member "(\w+)" not found on type "QObject"', warning["message"])
            valid_dynamic = False
            if warning["id"] == "missing-property" and member:
                name = member[1]
                valid_dynamic = any(name in members and group + "." + name in line for group, members in groups.items())
                if name == "shell" and "bar?.shell?" in line:
                    valid_dynamic = "property var shell:" in (shell / "Ui/PluginBarApi.qml").read_text()
            if valid_dynamic:
                checked += 1
            elif warning["type"] != "info":
                problems.append(f'{file["filename"]}:{warning["line"]}: {warning["message"]}')
    if problems:
        raise SystemExit("\n".join(problems))
    if result.returncode not in {0, 255}:
        raise SystemExit(result.stderr)
    print(f"QML passed; {checked} dynamic Omarchy token references verified against installed components.")
