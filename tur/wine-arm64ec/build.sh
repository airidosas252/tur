TERMUX_PKG_HOMEPAGE=https://gitlab.winehq.org/wine/wine
TERMUX_PKG_DESCRIPTION="A compatibility layer for running Windows programs (Wine ARM64EC)"
TERMUX_PKG_LICENSE="LGPL-2.1"
TERMUX_PKG_LICENSE_FILE="LICENSE, LICENSE.OLD, COPYING.LIB"
TERMUX_PKG_MAINTAINER="@termux-user-repository"
TERMUX_PKG_VERSION=10.1
TERMUX_PKG_REVISION=0
_REAL_VERSION="${TERMUX_PKG_VERSION/\~/-}"
TERMUX_PKG_SRCURL=https://dl.winehq.org/wine/source/10.x/wine-10.5.tar.xz
TERMUX_PKG_SHA256=c036ec1ef47674774a5f994583022e9e2eb68fe8fc18b3a8c79e685b3bec89bc
TERMUX_PKG_DEPENDS="fontconfig, freetype, krb5, libandroid-spawn, libandroid-shmem, libc++, libgmp, libgnutls, libxcb, libxcomposite, libxcursor, libxfixes, libxrender, mesa, opengl, pulseaudio, sdl2, vulkan-loader, xorg-xrandr"
TERMUX_PKG_ANTI_BUILD_DEPENDS="vulkan-loader"
TERMUX_PKG_BUILD_DEPENDS="libandroid-spawn-static, libandroid-shmem-static, vulkan-loader-generic"
TERMUX_PKG_NO_STATICSPLIT=true
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_EXTRA_HOSTBUILD_CONFIGURE_ARGS="
--without-x
--disable-tests
"

TERMUX_PKG_BLACKLISTED_ARCHES="arm, i686, x86_64"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
enable_wineandroid_drv=no
--prefix=$TERMUX_PREFIX/opt/wine-arm64ec
--exec-prefix=$TERMUX_PREFIX/opt/wine-arm64ec
--libdir=$TERMUX_PREFIX/opt/wine-arm64ec/lib
--with-wine-tools=$TERMUX_PKG_HOSTBUILD_DIR
--enable-nls
--disable-tests
--without-alsa
--without-capi
--without-coreaudio
--without-cups
--without-dbus
--with-fontconfig
--with-freetype
--without-gettext
--with-gettextpo=no
--without-gphoto
--with-gnutls
--without-gstreamer
--without-inotify
--with-krb5
--with-mingw
--without-netapi
--without-opencl
--with-opengl
--with-osmesa
--without-oss
--without-pcap
--with-pthread
--with-pulse
--without-sane
--with-sdl
--without-udev
--without-unwind
--without-usb
--without-v4l2
--with-vulkan
--with-xcomposite
--with-xcursor
--with-xfixes
--without-xinerama
--with-xinput
--with-xinput2
--with-xrandr
--with-xrender
--without-xshape
--with-xshm
--without-xxf86vm
--enable-archs=i386,arm,aarch64,arm64ec
"
# TODO: `--enable-archs=arm` doesn't build with option `--with-mingw=clang`, but
# TODO: `arm64ec` doesn't build with option `--with-mingw` (arm64ec-w64-mingw32-clang)

_setup_llvm_mingw_toolchain() {
	# LLVM-mingw's version number must not be the same as the NDK's.
	local _llvm_mingw_version=19
	local _version="20241218"
	local _url="https://github.com/bylaws/llvm-mingw/releases/download/20241812/llvm-mingw-20241218-ucrt-ubuntu-20.04-x86_64.tar.xz"
	local _path="$TERMUX_PKG_CACHEDIR/$(basename $_url)"
	local _sha256sum=710b7a96a06c99128427d31e3b7b1cac5b17a111219ae1c163e1f1f870c434b6
	termux_download $_url $_path $_sha256sum
	local _extract_path="$TERMUX_PKG_CACHEDIR/llvm-mingw-toolchain-$_llvm_mingw_version"
	if [ ! -d "$_extract_path" ]; then
		mkdir -p "$_extract_path"-tmp
		tar -C "$_extract_path"-tmp --strip-component=1 -xf "$_path"
		mv "$_extract_path"-tmp "$_extract_path"
	fi
	export PATH="$_extract_path/bin:$PATH"
}

termux_step_host_build() {
	# Setup llvm-mingw toolchain
	_setup_llvm_mingw_toolchain

	# Make host wine-tools
	"$TERMUX_PKG_SRCDIR/configure" ${TERMUX_PKG_EXTRA_HOSTBUILD_CONFIGURE_ARGS}
	make -j "$TERMUX_PKG_MAKE_PROCESSES" __tooldeps__ nls/all
}

termux_step_pre_configure() {
	# Setup llvm-mingw toolchain
	_setup_llvm_mingw_toolchain

	# Fix overoptimization
	CPPFLAGS="${CPPFLAGS/-Oz/}"
	CFLAGS="${CFLAGS/-Oz/}"
	CXXFLAGS="${CXXFLAGS/-Oz/}"

	# Disable hardening
	CPPFLAGS="${CPPFLAGS/-fstack-protector-strong/}"
	CFLAGS="${CFLAGS/-fstack-protector-strong/}"
	CXXFLAGS="${CXXFLAGS/-fstack-protector-strong/}"
	LDFLAGS="${LDFLAGS/-Wl,-z,relro,-z,now/}"

	LDFLAGS+=" -landroid-spawn -landroid-shmem"
}
termux_step_make() {
	make -j $TERMUX_PKG_MAKE_PROCESSES
}

termux_step_make_install() {
	make -j $TERMUX_PKG_MAKE_PROCESSES install

	# Create hangover-wine script
	mkdir -p $TERMUX_PREFIX/bin
	cat << EOF > $TERMUX_PREFIX/bin/wine-arm64ec
#!$TERMUX_PREFIX/bin/env sh
exec $TERMUX_PREFIX/opt/wine-arm64ec/bin/wine "\$@"
EOF
	chmod +x $TERMUX_PREFIX/bin/wine-arm64ec
}
