# Maya 2027 in a box

Creates a distrobox container for [**Maya 2027**](https://www.autodesk.com/products/maya/overview) based on [**Rocky Linux 9**](https://rockylinux.org), which is the supported base for Maya 2027.

Plugins that are included in the main Maya download are installed automatically:

- **MayaUSD**
- **Bifrost**
- **Substance**
- **FlowRetopology**
- **LookdevX**

Exceptions being **Flow** and **MayaFlow** that require a hosted Flow server.

Tested with success on [**Aurora Linux**](https://getaurora.dev) and [**EndeavourOS**](https://endeavouros.com) running Wayland sessions. It should work even better under X11.

## Instructions

> Keep in mind: the generated container will contain software that may not be redistributed freely.

Maya is licensed software and must be manually obtained from [**the Autodesk website**](https://manage.autodesk.com/products).

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

### Prepare `.distroboxrc`

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

Included in the repository is a [`build.sh`](build.sh) script that **automates the following setup**. If it doesn't work, then just follow the instructions manually as outlined below.

### Build the container

Run the following, replacing `$REPO_DIR` with the path to your clone of this repository:

```bash
podman build --security-opt label=disable -v ~/maya-src:/mnt/maya-src:ro -t localhost/maya-rocky9 "$REPO_DIR"
```

The `--security-opt label=disable` option is necessary to avoid SELinux issues when creating the image.

This will take *several* minutes.

### Create a distrobox of the image

```bash
distrobox create --name maya --image localhost/maya-rocky9 --home ~/.distrobox/maya --init
```

The `--init` is required to allow for systemd to manage the licensing daemon.

### First-time setup

```bash
distrobox enter maya -- /opt/maya-install/first-run.sh
```

### Expose `maya-run`

Export the `maya-run` start-up script to be available to the host system.

```bash
distrobox enter maya -- distrobox-export --bin /usr/local/bin/maya-run
```

### Start Maya

```bash
maya-run
```

Run it in a terminal the first time to catch any potential error messages.

## Troubleshooting

### Missing `xhost`

If the program doesn't start upon calling `maya-run` with an error about authorisation or display issues, make sure you have the `xhost` tool installed.

```text
Authorization required, but no authorization protocol specified
Can't open display: :0
```

It may not be installed on Wayland-based desktop environments by default. Refer to your repositories; the package is commonly called `xhost`, `xorg-xhost` or `x11-xserver-utils`.

Once installed, stop the container with `distrobox stop maya` and then re-enter it with `distrobox enter maya` to see if that solved the problem.

### Program starts but never opens a browser

Verify that you aren't running more than one distrobox simultaneously; each distrobox runs its own licensing daemon, and multiple instances collide. `distrobox stop` other running distroboxes before starting a new one.

### Browser login works but the "open product" button doesn't

It may either do nothing, or it may ask for what program should be used to open the link.

If it's seemingly doing nothing, first verify that it isn't actually working; it may be that the license was established and Maya is just taking a long time to start up in the background. Refer to the progress bar in the Maya splash window.

The workaround is otherwise to intercept the callback URL that the browser is supposed to pass onto the licensing manager, and then just call it manually in the distrobox.

As the installed browser automatically pops up (by default [**Brave**](https://brave.com)) as part of Maya's Autodesk account login procedure, hit **F12** to open the developer tools, then go to the Networks tab. Perform the normal login until you get to the "open product" button and finally the non-working "Open Autodesk Identity Manager" button. Look for a callback URL in the network requests to show up when you click it. It should be a long string that starts with something like `adskidmgr://`.

Copy that URL and invoke the `AdskIdentityManager` licensing manager, passing the URL as argument. At this point Maya should still be waiting for the login to complete.

```bash
/opt/Autodesk/AdskIdentityManager/Current/AdskIdentityManager "adskidmgr://..."
```

Be sure to put the callback URL within quotes.

### Application Home screen is blank

If the Application Home screen is empty, add `--single-process` to the Maya command line (in `maya-run`) to work around the issue. See [**this comment by meepzh**](https://aur.archlinux.org/packages/maya?O=80#comment-871405) on the [**Arch User Repository page for the `maya` package**](https://aur.archlinux.org/packages/maya) for more information.

### Font errors

If the program starts but you get error messages in the bottom right about missing fonts, then fonts from the distrobox may not have been correctly copied to and imported on the host system.

```text
Failed trying to load font : -*-helvetica-bold-r-normal-*-11-*-*-*-*-*-iso8859-1 //
```

These fonts are copied from the container to the host system as part of the `first-run.sh` script that should be run once for this kind of one-time setup. It then invokes `.distroboxrc` on the host system, so the font paths *should* be available right away. If you still see errors, verify that `~/.distroboxrc` is in place and has the expected contents; if not, fix it, then stop the distrobox and re-enter.

```bash
distrobox stop maya
distrobox enter maya
```

### "`WebKitWebProcess` has encountered a fatal error and was closed"

This happens (at least) on Wayland but does not seem to be fatal to the Maya start-up/login process. It just happens; ignore it.

### Some features just don't work

It's impossible to know whether all the dependencies were identified and installed. Some features may not work as expected (or at all) if one or more libraries are missing. The place to start is to use `ldd` on any Maya or plugin binaries that seem relevant.

## Uninstallation

```bash
distrobox stop maya
distrobox rm maya
podman image prune
rm -rf ~/.distrobox/maya
```

## Supplemental notes

### **MtoA**

The **Arnold renderer** must be downloaded separately and installed manually, if desired. It requires accepting a separate license agreement. It is available as (something like) `MtoA-5.6.3.1-linux-2027.run` on the Autodesk website. Merely download the file, set it to executable `+x` and run it inside the distrobox with `sudo` permissions.

## AI

[**Claude**](http://claude.ai) was used to help troubleshoot getting Maya set up in the distrobox environment and to teach container-fu in general.

## License and Copyright

This container project is licensed under the MIT License; see the [**LICENSE**](LICENSE) file for details.

[**Autodesk Maya**](https://www.autodesk.com/products/maya/overview) is Copyright 1997–2026 [**Autodesk, Inc**](https://autodesk.com) and is in no way affiliated with this project.
