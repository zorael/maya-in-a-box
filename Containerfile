# Maya 2027 container
#
# Creates a container based on Rocky Linux 9, which is the supported base
# for Maya 2027.
#
# Tested with success on Aurora Linux (https://getaurora.dev)
# and EndeavourOS (https://endeavouros.com) in Wayland environments.

FROM quay.io/toolbx-images/rockylinux-toolbox:9

# Runtime dependencies for Maya, its ancillaries and its plugins.
# Maya's RPMs declare almost nothing, so this list was generated manually
# by parsing ldd output, plus some heavy trial and error.
RUN dnf install -y \
        audiofile \
        glx-utils \
        libXScrnSaver \
        libXaw \
        libXpm \
        libglew \
        libgs \
        libicu \
        libpng12 \
        libtiff \
        libva \
        libvdpau \
        libwayland-server \
        libxkbcommon-x11 \
        libxkbfile \
        webkit2gtk3 \
        xorg-x11-fonts-100dpi \
        xorg-x11-fonts-75dpi \
        xorg-x11-fonts-ISO8859-1-100dpi \
        xorg-x11-fonts-ISO8859-1-75dpi \
        xorg-x11-server-utils \
    && dnf clean all

# Legacy list. Fall back to this if the slim list above is insufficient.
#
# compat-openssl11 is required as Maya 2027 depends on OpenSSL 1.1 but
# Rocky Linux 9 ships with OpenSSL 3 by default.
#RUN dnf install -y \
#        alsa-lib audiofile compat-openssl11 desktop-file-utils fontconfig \
#        freetype glibc-all-langpacks glibc-locale-source glx-utils gtk2 \
#        libX11-xcb libXScrnSaver libXcomposite libXcursor libXdamage libXi \
#        libXinerama libXp libXpm libXrandr libXrender libXtst libatomic \
#        libcanberra-gtk2 liberation-fonts libglvnd libglvnd-glx libglvnd-opengl \
#        libjpeg libjpeg-turbo libmng libnsl libpng libpng15 libpq libtiff \
#        libvdpau libxkbcommon libxkbcommon-x11 libxkbfile mesa-dri-drivers \
#        mesa-libGL mesa-libGLU mtdev nspr nss nss-util pciutils-libs \
#        pcre2-utf16 pcre2-utf32 pinentry tcsh urw-base35-fonts webkit2gtk3 \
#        whois xcb-util-cursor xcb-util-image xcb-util-keysyms \
#        xcb-util-renderutil xcb-util-wm xdg-utils xorg-x11-fonts-100dpi \
#        xorg-x11-fonts-75dpi xorg-x11-fonts-ISO8859-1-100dpi \
#        xorg-x11-fonts-ISO8859-1-75dpi xset zsh \
#    && dnf clean all

# curl is already installed as curl-minimal, so the --allowerasing is needed to
# allow for replacing it with the full curl package.
RUN dnf install -y --allowerasing curl \
    && dnf clean all

RUN dnf install -y \
        /mnt/maya-src/Packages/Maya2027_64-*.x86_64.rpm \
        /mnt/maya-src/Packages/Licensing/adsklicensing*.x86_64.rpm \
        /mnt/maya-src/Packages/AdskIdentityManager/adskidentitymanager*.x86_64.rpm \
    && dnf clean all

RUN mkdir -p /opt/Autodesk/AdpDesktopSDK/bin \
    && unzip -o /mnt/maya-src/Packages/AdpSdk/adp-desktop-sdk.zip \
        -d /opt/Autodesk/AdpDesktopSDK/bin

RUN dnf install -y \
        /mnt/maya-src/Packages/MayaUSD2027-*.x86_64.rpm \
        /mnt/maya-src/Packages/Bifrost2027-*.x86_64.rpm \
        /mnt/maya-src/Packages/AdobeSubstance3DforMaya-*.rpm \
        /mnt/maya-src/Packages/flowretopology/FlowRetopologyMaya*.rpm \
    && dnf clean all

# LookdevX has dependencies declared but the Maya packages are missing the
# respective Provides: sections in their RPM metadata.
RUN rpm -ivh --nodeps /mnt/maya-src/Packages/LookdevX-*.rpm

RUN mkdir -p /opt/maya-install \
    && cp /mnt/maya-src/MayaConfig.pit /opt/maya-install/MayaConfig.pit

# A browser is needed for logging into the Autodesk account.
# Brave was chosen simply because it is comparatively uncommon and is thus less
# likely to crosstalk with any running instances on the host system.
# Replace with Firefox if desired. Might work. Might also clobber your settings.
RUN dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo \
    && dnf install -y brave-browser \
    && dnf clean all

COPY --chmod=0755 maya-run /usr/local/bin/

COPY --chmod=0755 first-run.sh /opt/maya-install/

COPY --chmod=0755 setup-licensing.sh /opt/maya-install/
