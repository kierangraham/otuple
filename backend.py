#!/usr/bin/env python3
"""Tuple CLI adapter for the native Omarchy bar panel."""
import argparse
import json
import os
import queue
import re
import signal
import subprocess
import sys
import threading
from urllib.parse import urlparse


def contacts_from_text(text):
    contacts = []
    for line in text.splitlines():
        match = re.fullmatch(r"\s*(\d+)\s+(.+?)\s+<([^<>]+)>\s+\[([^\]]+)\](?:\s+\((favorite)\))?\s*", line)
        if not match:
            if line.strip():
                raise ValueError("Tuple returned an unrecognized contact list.")
            continue
        uid, name, email, presence, favorite = match.groups()
        contacts.append(dict(id=uid, name=name, email=email,
                             status={"available": "online", "in call": "busy", "unavailable": "offline"}.get(presence, "offline"),
                             favorite=bool(favorite)))
    return contacts


def contacts_from_json(value):
    values = value if isinstance(value, list) else value.get("contacts", [])
    if not isinstance(values, list):
        raise ValueError("Tuple returned an invalid JSON contact list.")
    return [dict(id=str(c.get("id", c.get("user_id", ""))),
                 name=c.get("name") or c.get("full_name") or c.get("email") or "Contact",
                 email=c.get("email", ""),
                 status={"available": "online", "unavailable": "offline", "in call": "busy"}.get(c.get("status", c.get("presence", "offline")), c.get("status", c.get("presence", "offline"))),
                 favorite=bool(c.get("favorite", c.get("favorited", c.get("is_favorite", False)))))
            for c in values if isinstance(c, dict)]


def validate_link(value):
    parsed = urlparse(value)
    if parsed.scheme != "https" or parsed.hostname not in {"tuple.app", "production.tuple.app", "app.tuple.app"} or parsed.username or parsed.password:
        raise ValueError("Paste an HTTPS Tuple call link.")
    return value


class TupleCli:
    def __init__(self, binary="tuple"):
        self.binary = binary
        help_result = self.run_raw(["--help"])
        self.modern = help_result.returncode == 0 and "contacts" in help_result.stdout
        result = help_result if self.modern else self.run_raw([])
        self.version = next((line.strip() for line in result.stdout.splitlines() if "version" in line.lower() or "Interface" in line), "Tuple CLI")

    def run_raw(self, args, timeout=12):
        return subprocess.run([self.binary, *args], capture_output=True, text=True, timeout=timeout)

    def run(self, args, timeout=12):
        result = self.run_raw([*args, *(["--format", "json"] if self.modern else [])], timeout)
        if result.returncode:
            message = result.stderr.strip() or result.stdout.strip() or "Tuple command failed."
            try:
                message = json.loads(message).get("error", message)
            except (ValueError, AttributeError):
                pass
            raise RuntimeError(str(message)[:600])
        if self.modern:
            return json.loads(result.stdout) if result.stdout.strip() else {}
        return result.stdout.strip()

    def snapshot(self):
        result = self.run(["contacts", "list"] if self.modern else ["ls"])
        contacts = contacts_from_json(result) if self.modern else contacts_from_text(result)
        state = self.run(["state"]) if self.modern else {}
        settings = {}
        if not self.modern:
            for line in self.run(["settings"]).splitlines():
                parts = line.split("|", 2)
                if len(parts) == 3:
                    settings[parts[0].strip()] = parts[1].strip()
        return dict(type="snapshot", contacts=contacts, state=state, settings=settings, modern=self.modern, version=self.version)

    def action(self, action, value=""):
        simple = {
            "mute": (["call", "mute"], ["mute"]),
            "unmute": (["call", "unmute"], ["unmute"]),
            "end": (["call", "leave"], ["end"]),
            "share": (["share"], ["share"]),
            "unshare": (["unshare"], ["unshare"]),
            "login": (["login"], ["login"]),
            "logout": (["logout"], ["logout"]),
            "on": (["start"], ["on"]),
            "off": (["stop"], ["off"]),
        }
        if action in simple:
            args = simple[action][0 if self.modern else 1]
        elif action in {"call", "favorite", "unfavorite"}:
            if not value or len(value) > 256 or value.startswith("-"):
                raise ValueError("Choose a contact first.")
            if not self.modern and not value.isdigit():
                raise ValueError("Invalid Tuple user ID.")
            args = ["call", "start", value] if action == "call" and self.modern else ["contacts", action, value] if self.modern else [action, value]
        elif action == "join":
            args = ["call", "join", validate_link(value)] if self.modern else ["join", validate_link(value)]
        elif action == "new" and not self.modern:
            args = ["new"]
        elif action == "auth":
            if not value or len(value) > 4096 or value.startswith("-") or any(c.isspace() for c in value):
                raise ValueError("Paste the authorization code from Tuple.")
            args = ["auth", value]
        elif action in {"start-muted", "overlay"}:
            if value not in {"0", "1"}:
                raise ValueError("Invalid setting value.")
            args = ["set", "start-calls-muted" if action == "start-muted" else "overlay", value]
        else:
            raise ValueError("This action is unavailable in this CLI version.")
        return self.run(args, timeout=40)


DEMO_CONTACTS = [
    dict(id="1", name="Alex Morgan", email="alex@example.com", status="online", favorite=True),
    dict(id="2", name="Jamie Chen", email="jamie@example.com", status="online", favorite=True),
    dict(id="3", name="Sam Rivera", email="sam@example.com", status="busy", favorite=False),
    dict(id="4", name="Taylor Brooks", email="taylor@example.com", status="offline", favorite=False),
]


def serve(demo=False):
    tasks = queue.Queue(maxsize=8)
    output_lock = threading.Lock()

    def emit(payload):
        with output_lock:
            print(json.dumps(payload), flush=True)

    def read_commands():
        for line in sys.stdin:
            try:
                command = json.loads(line)
                if isinstance(command, dict):
                    tasks.put(command)
            except ValueError:
                emit(dict(type="error", message="Invalid app command."))
        tasks.put(None)

    def stop(*unused):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    threading.Thread(target=read_commands, daemon=True).start()
    try:
        cli = None if demo else TupleCli(os.environ.get("OTUPLE_CLI", "tuple"))
    except (OSError, subprocess.SubprocessError) as error:
        emit(dict(type="error", message=str(error)))
        return
    paused = False
    task = dict(action="refresh")
    while task is not None:
        action = task.get("action", "refresh")
        is_action = action != "refresh"
        try:
            if not (paused and action == "refresh"):
                if is_action:
                    emit(dict(type="busy", value=True))
                    result = "Demo mode: no Tuple commands were run." if demo else cli.action(action, str(task.get("value", "")))
                    emit(dict(type="result", action=action, output=result))
                    paused = action == "off"
                if not paused:
                    emit(dict(type="snapshot", contacts=DEMO_CONTACTS, state={}, settings={"overlay": "1", "start-calls-muted": "0"}, modern=False, version="Demo") if demo else cli.snapshot())
                else:
                    emit(dict(type="snapshot", contacts=[], state={}, settings={}, modern=False, version=cli.version if cli else "Demo"))
                    emit(dict(type="notice", message="Tuple is offline. Use Go online to reconnect."))
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            emit(dict(type="error", message=str(error)))
        finally:
            if is_action:
                emit(dict(type="busy", value=False))
        try:
            task = tasks.get(timeout=10)
        except queue.Empty:
            task = dict(action="refresh")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo", action="store_true")
    serve(parser.parse_args().demo)
