# Maya in a box

Creates a distrobox container for [**Maya 2027**](https://www.autodesk.com/products/maya/overview) based on [**Rocky Linux 9**](https://rockylinux.org), which is [**the only\* officially supported distribution**](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/System-Requirements-for-Autodesk-Maya-2027.html) for it (alongside [**Red Hat Enterprise Linux**](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)).

Plugins that are included in the main Maya download are installed automatically:

- **MayaUSD**
- **Bifrost**
- **Substance**
- **FlowRetopology**
- **LookdevX**

Exceptions being **Flow** and **MayaFlow** that require a hosted Flow server. The [**Arnold renderer**](#arnold-renderer) must additionally be installed separately.

Tested with success on [**Aurora Linux**](https://getaurora.dev) and [**EndeavourOS**](https://endeavouros.com) running Wayland sessions (via Xwayland). It should work even better under X11.

## TOC

- [**Reminder**](#reminder)
- [Instructions](#instructions)
  - [Prepare `.distroboxrc`](#prepare-distroboxrc)
  - [Automation script](#automation-script)
  - [Build the container](#build-the-container)
  - [Create a distrobox of the image](#create-a-distrobox-of-the-image)
  - [First-time setup](#first-time-setup)
  - [Expose `maya-run`](#expose-maya-run)
  - [Start Maya](#start-maya)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)
  - [Missing `xhost`](#missing-xhost)
  - [Program starts but never opens a browser](#program-starts-but-never-opens-a-browser)
  - [Browser login works but the "open product" button doesn't](#browser-login-works-but-the-open-product-button-doesnt)
  - [Application Home screen is blank](#application-home-screen-is-blank)
  - [Font errors](#font-errors)
  - ["WebKitWebProcess has encountered a fatal error and was closed"](#webkitwebprocess-has-encountered-a-fatal-error-and-was-closed)
  - [Some features just don't work](#some-features-just-dont-work)
- [Supplementary notes](#supplementary-notes)
  - [`.distroboxrc`](#distroboxrc)
  - [`$HOME`](#home)
  - [Arnold renderer](#arnold-renderer)
- [AI](#ai)
- [License and Copyright](#license-and-copyright)

---

## **Reminder**

The generated container will contain software that may not be redistributed freely.

## Instructions

Maya is licensed software and must be manually obtained from [**the Autodesk Maya page**](https://manage.autodesk.com/products/MAYA?version=2027&platform=LNUX64).

The downloaded tarball (full name like `Autodesk_Maya_2027_2_Update_Linux_64bit.tgz`) should be extracted to `~/maya-src/`, creating a directory structure like the following:

```text
/home/user/maya-src
├── 3rdParty
├── manifest
├── maya_2027_linux_manifest.zip
├── MayaConfig.pit
├── ODIS
├── Packages
├── Setup
├── SetupRes
├── setup.xml
└── upi_list.json
```

You must also install [`distrobox`](https://github.com/89luca89/distrobox) and [`podman`](https://podman.io). Refer to your repositories.

### Prepare [`.distroboxrc`](distroboxrc)

Add to [`~/.distroboxrc`](distroboxrc), creating it if necessary:

```bash
xhost +si:localuser:"$USER" >/dev/null 2>&1 || true

for subdir in 100dpi 75dpi; do
    dir="$HOME/.local/share/x11-fonts/$subdir"
    [ -d "$dir" ] || continue
    xset +fp "$dir" 2>/dev/null || true
done

xset fp rehash 2>/dev/null || true
```

### Automation script

Included in the repository is a [`build.sh`](build.sh) script that **automates the setup that follows**. If something doesn't work, then just follow the instructions manually as outlined below. If you figure out what went wrong, [**please file a GitHub issue**](https://github.com/zorael/maya-in-a-box/issues/new).

### Build the container

```bash
podman build \
    --security-opt label=disable \
    -v ~/maya-src:/mnt/maya-src:ro \
    -t localhost/maya-rocky9 \
    "path/to/repo/clone"
```

The `--security-opt label=disable` option is necessary to avoid SELinux issues when creating the image.

This will take *several* minutes.

### Create a distrobox of the image

```bash
distrobox create \
    --name maya \
    --image localhost/maya-rocky9 \
    --home ~/.distrobox/maya \
    --init
```

`--name` specifies the label of the container, which will be used as identifier when using the `distrobox` command-line tool (`distrobox enter maya`, etc). So don't name it "blerp".

`--init` is required to allow for **systemd** to manage the licensing daemon.

`--home` makes the user inside the distrobox have a different `$HOME`, separate from that of your host user. It is optional but recommended.

### First-time setup

```bash
distrobox enter maya -- /opt/maya-install/first-run.sh
```

### Expose [`maya-run`](maya-run)

Export the [`maya-run`](maya-run) start-up script to be available to the host system.

```bash
distrobox enter maya -- distrobox-export --bin /usr/local/bin/maya-run
```

### Start Maya

```bash
maya-run
```

Run it in a terminal the first time to catch any potential error messages.

## Uninstallation

```bash
distrobox stop maya
distrobox rm maya
podman rmi localhost/maya-rocky9
rm -rf ~/.distrobox/maya
```

## Troubleshooting

### Missing `xhost`

If the program doesn't start upon calling [`maya-run`](maya-run), giving an error about authorisation or display issues, make sure you have the `xhost` tool installed on the host.

```text
Authorization required, but no authorization protocol specified
Can't open display: :0
```

It may not be installed on Wayland-based desktop environments by default. Refer to your repositories; the package is commonly called `xhost`, `xorg-xhost` or `x11-xserver-utils`.

Once installed, stop the container with `distrobox stop maya` and then re-enter it with `distrobox enter maya` to see if that solved the problem.

Alternatively, a way that doesn't require restarting the container:

```bash
sh /run/host/home/$(id -un)/.distroboxrc
```

### Program starts but never opens a browser

Sometimes with 30-second long delays between steps, as if something is timing out.

Verify that you aren't running more than one Maya distrobox simultaneously; each distrobox runs its own licensing daemon, and multiple instances can seemingly collide. `distrobox stop` other running distroboxes before starting a new one.

### Browser login works but the "open product" button doesn't

When you click "open product" in the browser, the server returns an `adskidmgr://` *callback URL* that is meant to be passed on to and handled by the Autodesk licensing manager. If it isn't configured correctly and it doesn't resolve the URL scheme as something to be handled by the licensing manager, it may either silently do nothing, or it may pop up a list of applications to choose between; neither of which is what you wanted.

If it's seemingly doing nothing, first verify that it isn't actually working; it may be that the license was established and Maya is just taking a long time to start up in the background. Refer to the progress bar in the Maya splash window.

The workaround is otherwise to intercept the callback URL that the browser is supposed to pass onto the licensing manager, and then just call it manually in the distrobox.

As the installed browser automatically pops up (by default [**Brave**](https://brave.com)) as part of Maya's Autodesk account login procedure, hit **F12** to open the developer tools, then go to the **Networks** tab. Perform the normal login until you get to the "**Open Product**" button and finally the non-working "**Open Autodesk Identity Manager**" button (assuming it ever appears). Look for a callback URL in the network requests to show up when you click it. Again: `adskidmgr://`.

Copy that callback URL and invoke the `AdskIdentityManager` licensing manager in a terminal, passing the URL as argument. At this point Maya must still be waiting for the login to complete.

```bash
/opt/Autodesk/AdskIdentityManager/Current/AdskIdentityManager "adskidmgr://..."
```

Be sure to put the callback URL within quotes.

### Application Home screen is blank

If the Application Home screen is empty, add `--single-process` to the Maya command line (in [`maya-run`](maya-run)) to work around the issue. See [**this comment by meepzh**](https://aur.archlinux.org/packages/maya?O=80#comment-871405) on the [**Arch User Repository page for the `maya` package**](https://aur.archlinux.org/packages/maya) for more information.

### Font errors

If the program starts but you get error messages in the bottom right about fonts failing to load, then fonts from the distrobox may not have been correctly [**copied to (and imported on) the host system**](#distroboxrc).

```text
Failed trying to load font : -*-helvetica-bold-r-normal-*-11-*-*-*-*-*-iso8859-1 //
```

These fonts are copied from the container to the host system as part of the [`first-run.sh`](first-run.sh) script that should be run once after distrobox creation. It then invokes [`.distroboxrc`](distroboxrc) on the host system, so the font paths *should* be available right away. If you still see errors, verify that [`~/.distroboxrc`](distroboxrc) is in place and has the expected contents; if not, fix it, then stop the distrobox and re-enter.

```bash
distrobox stop maya
distrobox enter maya
```

### "`WebKitWebProcess` has encountered a fatal error and was closed"

This happens (at least) on Wayland but does not seem to be fatal to the Maya start-up/login process. It just happens; ignore it.

### Some features just don't work

It's impossible to know whether all the dependencies were identified and installed. Some features may not work as expected (or at all) if one or more libraries are missing. The place to start is to use `ldd` on any Maya or plugin binaries that seem relevant. If you figure out what is missing, [**please file a GitHub issue**](https://github.com/zorael/maya-in-a-box/issues/new).

## Supplementary notes

### [`.distroboxrc`](distroboxrc)

The purpose of this file is to [**add font paths on the host system**](#font-errors), "importing" fonts copied from the container. The copying is done as part of the [`first-run.sh`](first-run.sh) script. Distrobox then *sources* the file on container entry, and the wanted font paths are added. However, on the first run the fonts themselves will not have been copied yet and you get a sequencing problem.

To work around this, immediately after having copied the fonts, [`first-run.sh`](first-run.sh) *executes* [`.distroboxrc`](distroboxrc) using `sh` on the host system. This means that if your file contains anything extra, that extra something has to be safe to be run more than once. It also means that the file should try to keep to `sh` syntax and avoid features specific to other shells, like `bash`.

### `$HOME`

The `distrobox create` command given in the instructions of this `README.md` (and the one used in the [`build.sh`](build.sh) script) sets up a separate `$HOME` for the distrobox environment. This is technically entirely optional and a home can normally be safely shared between the host and the container, but sharing *may* cause problems here with the licensing handshake of the Autodesk login sequence. It also may not, so feel free to disable it.

If you can't find your files, look to `~/.distrobox/maya` on the host system. (Replace `maya` with the name of your Maya distrobox, if different.)

### Arnold renderer

The [**Arnold renderer**](https://www.autodesk.com/products/arnold/overview) is not included in the Maya 2027 tarball and so must be manually downloaded and installed, if desired. It requires accepting a separate license agreement by keyboard input, and thus cannot be pre-installed into the container image. It is available as (something like) `MtoA-5.x.y.z-linux-2027.run` on [**the Autodesk Maya page**](https://manage.autodesk.com/products/MAYA?version=2027&platform=LNUX64) after selecting to list **Extensions**. Merely download the file, set it executable `+x` and run it inside the distrobox with `sudo` permissions. Take care to download the latest version.

## AI

[**Claude**](http://claude.ai) was used to help troubleshoot getting Maya set up in the distrobox environment and to teach container-fu in general.

## License and Copyright

This project is licensed under the [**MIT License**](https://choosealicense.com/licenses/mit); see the [**LICENSE**](LICENSE) file for details.

[**Autodesk Maya**](https://www.autodesk.com/products/maya/overview) is Copyright 1997–2026 [**Autodesk, Inc**](https://autodesk.com) and is in no way affiliated with this project.
