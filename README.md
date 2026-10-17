# Otuple

Otuple puts Tuple in the Omarchy bar. It is for people who pair on [Tuple](https://tuple.app) from an Omarchy desktop. A bar button opens a panel where you can find a contact, start or join a call, and use the call controls. It drives the official Tuple Linux CLI.

[![Otuple: searching contacts and opening favorites from the Omarchy bar](docs/preview.webp)](https://kierangraham.com/media/promo/otuple.mp4)

[Watch the film (25 s, with sound)](https://kierangraham.com/media/promo/otuple.mp4)

## Requirements

- **Omarchy**, with its shell plugin support.
- **The Tuple Linux CLI.** Install it with [Tuple's Linux installer](https://tuple.app/linux/), so that `tuple` is on your `PATH`. Tuple ships it for x86_64 and ARM64. Otuple never downloads or upgrades Tuple.
- **Python 3.** Install it with `sudo pacman -S --needed python`.

## Install

**Install the plugin.** This one command adds the bar widget:

```sh
omarchy plugin add https://github.com/kierangraham/otuple --enable
```

Omarchy clones the repository into `~/.config/omarchy/plugins/kierangraham.otuple` and adds the button to the right side of the bar.

**Optionally, install the `otuple` launcher.** It adds an `otuple` command, icons, and a desktop entry, so you can open the panel from the app launcher or a key binding. The plugin works without it. Choose one of these, in order of preference:

1. **Arch package.** It installs to `/usr`:

   ```sh
   git clone https://github.com/kierangraham/otuple
   cd otuple/packaging/arch
   makepkg -si
   ```

2. **`make install`.** From a clone of this repository, it installs to `~/.local`:

   ```sh
   make install
   ```

The package and `make install` only install the launcher. Omarchy manages the plugin folder, so the bar widget always comes from `omarchy plugin add`.

## Update

```sh
omarchy plugin update kierangraham.otuple
```

To update the launcher, rebuild the package or run `make install` again from an updated clone.

## Uninstall

```sh
omarchy plugin remove kierangraham.otuple
```

To remove the launcher, run `sudo pacman -R otuple` if you installed the package, or `make uninstall` if you used `make install`.

## Usage

**Click the bar button to open or close the panel.** Escape or a click outside closes it. The panel has two tabs, **People** and **Favorites**.

![Otuple panel with contacts and call controls](docs/otuple-panel.webp)

| Key | Action |
| --- | --- |
| Ctrl+F | Focus search |
| Enter, in search | Call the first available match |
| Ctrl+R | Refresh contacts |
| Ctrl+, | Open preferences |
| Escape | Close the panel |

**What you can do from the panel:**

- **Call a contact** with the phone button, or star them to add them to **Favorites**.
- **Join a call** by pasting a Tuple call link and pressing **Join**.
- **Start a call with my link** to begin a call on your personal link.
- **Use the call controls**: **Mute**, **Unmute**, **Share**, **Stop share** and **Leave**.
- **Sign in** under **Account & sign-in**, by pasting the authorization code from Tuple's website.
- **Go offline** to stop Tuple and pause refreshing. **Go online** starts it again. The bar button stays visible either way.

**Contacts and preferences refresh every ten seconds.** If a Tuple command fails, the panel shows its error. Incoming-call prompts and shared-screen windows still come from Tuple itself.

**With the launcher installed**, `otuple` opens the panel and `otuple --background` switches it to live contacts without opening it. Without the launcher, open the panel with `omarchy-shell shell summon kierangraham.otuple`.

### What it can and cannot show

**Otuple does not claim a call or microphone state it cannot read.** The current Tuple Linux CLI has no JSON output and does not report live call state. So Mute and Unmute are separate buttons, as are Share and Stop share, and none of them shows a current state.

Tuple's [CLI reference](https://docs.tuple.app/cli/commands), labelled macOS, describes a newer interface with JSON output and a `state` command. Otuple switches to that interface if the installed `tuple --help` lists it. Mocked tests cover this path, but no Linux release with that interface has been tested yet.

## Demo mode

**Demo mode shows four sample contacts and never runs Tuple.**

```sh
otuple --demo
```

Without the launcher, run `omarchy-shell otuple setDemo true`. Run `otuple`, or `omarchy-shell otuple setDemo false`, to return to live contacts.

## Configuration

| Setting | Where | Effect |
| --- | --- | --- |
| Bar position | `omarchy plugin enable kierangraham.otuple --section right --before omarchy.tray` | Moves the button, here to just before the tray. |
| Start calls muted | Panel preferences | Tuple's own setting. Otuple changes it through the CLI. |
| Screen annotation overlay | Panel preferences | Tuple's own setting. Otuple changes it through the CLI. |
| `OTUPLE_CLI` | The Omarchy shell's environment | Path to a different `tuple` binary. Default: `tuple`. |

![Otuple preferences](docs/otuple-preferences.webp)

**Otuple stores no account data.** Tuple keeps your credentials and settings. Otuple passes an authorization code only to `tuple auth`.

## Development

The plugin has two parts:

- **QML in `qml/`.** `Service.qml` runs one backend for every monitor. `Widget.qml` is the bar button and panel.
- **`backend.py`.** It runs `tuple` commands without a shell and sends JSON Lines back to the service on standard output.

Run the checks:

```sh
make check
```

`make check` runs these:

- the backend tests
- a syntax check of the launcher and the PKGBUILD
- QML lint against the installed Omarchy shell
- `omarchy plugin validate`
- `desktop-file-validate` on the desktop entry

The tests never place calls or change Tuple preferences.

To try local changes in the bar, add your clone as the plugin. If Otuple is already installed, remove it first with `omarchy plugin remove kierangraham.otuple`.

```sh
omarchy plugin add "$PWD" --enable
```

`omarchy plugin add` copies your last commit, so commit changes before you add the clone. Run `omarchy plugin update kierangraham.otuple` after each new commit.

`make install` and `make uninstall` honour `PREFIX` (default `~/.local`) and `DESTDIR`.

## Licence

MIT. See [LICENSE](LICENSE).

---

[kierangraham.com](https://kierangraham.com)
