#!/usr/bin/env bash

########################################################################
##
## A script for Wine compilation.
## By default it uses two Ubuntu bootstraps (x32 and x64), which it enters
## with bubblewrap (root rights are not required).
##
## This script requires: git, wget, autoconf, xz, bubblewrap
##
## You can change the environment variables below to your desired values.
##
########################################################################

# Prevent launching as root
if [ $EUID = 0 ] && [ -z "$ALLOW_ROOT" ]; then
	echo "Do not run this script as root!"
	echo
	echo "If you really need to run it as root and you know what you are doing,"
	echo "set the ALLOW_ROOT environment variable."

	exit 1
fi

# Wine version to compile.
# You can set it to "latest" to compile the latest available version.
# You can also set it to "git" to compile the latest git revision.
#
# This variable affects only vanilla and staging branches. Other branches
# use their own versions.
export WINE_VERSION="${WINE_VERSION:-latest}"

# Available branches: vanilla, staging, staging-tkg, proton, wayland
export WINE_BRANCH="${WINE_BRANCH:-staging}"

# Available proton branches: proton_3.7, proton_3.16, proton_4.2, proton_4.11
# proton_5.0, proton_5.13, experimental_5.13, proton_6.3, experimental_6.3
# proton_7.0, experimental_7.0, proton_8.0, experimental_8.0, experimental_9.0
# bleeding-edge
# Leave empty to use the default branch.
export PROTON_BRANCH="${PROTON_BRANCH:-proton_8.0}"

# Sometimes Wine and Staging versions don't match (for example, 5.15.2).
# Leave this empty to use Staging version that matches the Wine version.
export STAGING_VERSION="${STAGING_VERSION:-}"

#######################################################################
# If you're building specifically for Termux glibc, set this to true.
export TERMUX_GLIBC="true"

# If you want to build Wine for proot/chroot, set this to true.
# It will incorporate address space adjustment which might improve
# compatibility. ARM CPUs are limited in this case.
export TERMUX_PROOT="false"

# These two variables cannot be "true" at the same time, otherwise Wine
# will not build. Select only one which is appropriate to you.
#######################################################################

# Specify custom arguments for the Staging's patchinstall.sh script.
# For example, if you want to disable ntdll-NtAlertThreadByThreadId
# patchset, but apply all other patches, then set this variable to
# "--all -W ntdll-NtAlertThreadByThreadId"
# Leave empty to apply all Staging patches
export STAGING_ARGS="${STAGING_ARGS:-}"

# Make 64-bit Wine builds with the new WoW64 mode (32-on-64)
export EXPERIMENTAL_WOW64="true"

# Set this to a path to your Wine source code (for example, /home/username/wine-custom-src).
# This is useful if you already have the Wine source code somewhere on your
# storage and you want to compile it.
#
# You can also set this to a GitHub clone url instead of a local path.
#
# If you don't want to compile a custom Wine source code, then just leave this
# variable empty.
export CUSTOM_SRC_PATH="${CUSTOM_SRC_PATH:-}"

# Set to true to download and prepare the source code, but do not compile it.
# If this variable is set to true, root rights are not required.
export DO_NOT_COMPILE="false"

# Set to true to use ccache to speed up subsequent compilations.
# First compilation will be a little longer, but subsequent compilations
# will be significantly faster (especially if you use a fast storage like SSD).
#
# Note that ccache requires additional storage space.
# By default it has a 5 GB limit for its cache size.
#
# Make sure that ccache is installed before enabling this.
export USE_CCACHE="${USE_CCACHE:-false}"

export WINE_BUILD_OPTIONS="--disable-winemenubuilder --disable-win16 --enable-win64 --disable-tests --without-capi --without-coreaudio --without-cups --without-gphoto --without-osmesa --without-oss --without-pcap --without-pcsclite --without-sane --without-udev --without-unwind --without-usb --without-v4l2 --without-wayland --without-xinerama"

# A temporary directory where the Wine source code will be stored.
# Do not set this variable to an existing non-empty directory!
# This directory is removed and recreated on each script run.
export BUILD_DIR=/home/runner/work/Wine-DarkOS-Builds/Wine-DarkOS-Builds/wine

# Implement a new WoW64 specific check which will change the way Wine is built.
# New WoW64 builds will use a different bootstrap which require different
# variables and they are not compatible with old WoW64 build mode.
if [ "${EXPERIMENTAL_WOW64}" = "true" ]; then

   export BOOTSTRAP_X64=/opt/chroots/noble64_chroot

   export scriptdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

   export CC="gcc-14"
   export CXX="g++-14"
   
   export CROSSCC_X64="x86_64-w64-mingw32-gcc"
   export CROSSCXX_X64="x86_64-w64-mingw32-g++"

   export CFLAGS_X64="-march=x86-64 -msse3 -mfpmath=sse -O3 -ftree-vectorize -pipe"
   export LDFLAGS="-Wl,-O1,--sort-common,--as-needed"
   
   export CROSSCFLAGS_X64="${CFLAGS_X64}"
   export CROSSLDFLAGS="${LDFLAGS}"

   if [ "$USE_CCACHE" = "true" ]; then
	export CC="ccache ${CC}"
	export CXX="ccache ${CXX}"
 
	export x86_64_CC="ccache ${CROSSCC_X64}"
 
	export CROSSCC_X64="ccache ${CROSSCC_X64}"
	export CROSSCXX_X64="ccache ${CROSSCXX_X64}"

	if [ -z "${XDG_CACHE_HOME}" ]; then
		export XDG_CACHE_HOME="${HOME}"/.cache
	fi

	mkdir -p "${XDG_CACHE_HOME}"/ccache
	mkdir -p "${HOME}"/.ccache
   fi

   build_with_bwrap () {
		BOOTSTRAP_PATH="${BOOTSTRAP_X64}"

    bwrap --ro-bind "${BOOTSTRAP_PATH}" / --dev /dev --ro-bind /sys /sys \
		  --proc /proc --tmpfs /tmp --tmpfs /home --tmpfs /run --tmpfs /var \
		  --tmpfs /mnt --tmpfs /media --bind "${BUILD_DIR}" "${BUILD_DIR}" \
		  --bind-try "${XDG_CACHE_HOME}"/ccache "${XDG_CACHE_HOME}"/ccache \
		  --bind-try "${HOME}"/.ccache "${HOME}"/.ccache \
		  --setenv PATH "/bin:/sbin:/usr/bin:/usr/sbin" \
			"$@"
}

else

export BOOTSTRAP_X64=/opt/chroots/bionic64_chroot
export BOOTSTRAP_X32=/opt/chroots/bionic32_chroot

export scriptdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

export CC="gcc-9"
export CXX="g++-9"

export CROSSCC_X32="i686-w64-mingw32-gcc"
export CROSSCXX_X32="i686-w64-mingw32-g++"
export CROSSCC_X64="x86_64-w64-mingw32-gcc"
export CROSSCXX_X64="x86_64-w64-mingw32-g++"

export CFLAGS_X32="-march=i686 -msse2 -mfpmath=sse -O3 -ftree-vectorize -pipe"
export CFLAGS_X64="-march=x86-64 -msse3 -mfpmath=sse -O3 -ftree-vectorize -pipe"
export LDFLAGS="-Wl,-O1,--sort-common,--as-needed"

export CROSSCFLAGS_X32="${CFLAGS_X32}"
export CROSSCFLAGS_X64="${CFLAGS_X64}"
export CROSSLDFLAGS="${LDFLAGS}"

if [ "$USE_CCACHE" = "true" ]; then
	export CC="ccache ${CC}"
	export CXX="ccache ${CXX}"

	export i386_CC="ccache ${CROSSCC_X32}"
	export x86_64_CC="ccache ${CROSSCC_X64}"

	export CROSSCC_X32="ccache ${CROSSCC_X32}"
	export CROSSCXX_X32="ccache ${CROSSCXX_X32}"
	export CROSSCC_X64="ccache ${CROSSCC_X64}"
	export CROSSCXX_X64="ccache ${CROSSCXX_X64}"

	if [ -z "${XDG_CACHE_HOME}" ]; then
		export XDG_CACHE_HOME="${HOME}"/.cache
	fi

	mkdir -p "${XDG_CACHE_HOME}"/ccache
	mkdir -p "${HOME}"/.ccache
fi

build_with_bwrap () {
	if [ "${1}" = "32" ]; then
		BOOTSTRAP_PATH="${BOOTSTRAP_X32}"
	else
		BOOTSTRAP_PATH="${BOOTSTRAP_X64}"
	fi

	if [ "${1}" = "32" ] || [ "${1}" = "64" ]; then
		shift
	fi

    bwrap --ro-bind "${BOOTSTRAP_PATH}" / --dev /dev --ro-bind /sys /sys \
		  --proc /proc --tmpfs /tmp --tmpfs /home --tmpfs /run --tmpfs /var \
		  --tmpfs /mnt --tmpfs /media --bind "${BUILD_DIR}" "${BUILD_DIR}" \
		  --bind-try "${XDG_CACHE_HOME}"/ccache "${XDG_CACHE_HOME}"/ccache \
		  --bind-try "${HOME}"/.ccache "${HOME}"/.ccache \
		  --setenv PATH "/bin:/sbin:/usr/bin:/usr/sbin" \
			"$@"
}
fi

if [ ! -d wine ]; then
	clear
	echo "No Wine source code found!"
	echo "Make sure that the correct Wine version is specified."
	exit 1
fi

cd wine || exit 1

###
dlls/winevulkan/make_vulkan
tools/make_requests
tools/make_specfiles
autoreconf -f
cd "${BUILD_DIR}" || exit 1

if [ "${DO_NOT_COMPILE}" = "true" ]; then
	clear
	echo "DO_NOT_COMPILE is set to true"
	echo "Force exiting"
	exit
fi

if ! command -v bwrap 1>/dev/null; then
	echo "Bubblewrap is not installed on your system!"
	echo "Please install it and run the script again"
	exit 1
fi

if [ "${EXPERIMENTAL_WOW64}" = "true" ]; then
    if [ ! -d "${BOOTSTRAP_X64}" ]; then
        clear
        echo "Bootstraps are required for compilation!"
        exit 1
    fi
else    
    if [ ! -d "${BOOTSTRAP_X64}" ] || [ ! -d "${BOOTSTRAP_X32}" ]; then
        clear
        echo "Bootstraps are required for compilation!"
        exit 1
    fi
fi

if [ "${EXPERIMENTAL_WOW64}" = "true" ]; then
BWRAP64="build_with_bwrap"
else
BWRAP64="build_with_bwrap 64"
BWRAP32="build_with_bwrap 32"
fi

if [ "${EXPERIMENTAL_WOW64}" = "true" ]; then

export CROSSCC="${CROSSCC_X64}"
export CROSSCXX="${CROSSCXX_X64}"
export CFLAGS="${CFLAGS_X64}"
export CXXFLAGS="${CFLAGS_X64}"
export CROSSCFLAGS="${CROSSCFLAGS_X64}"
export CROSSCXXFLAGS="${CROSSCFLAGS_X64}"
rm -rf "${BUILD_DIR}"/build
mkdir build && cd build
${BWRAP64} "${BUILD_DIR}"/wine/configure --enable-archs=i386,x86_64 ${WINE_BUILD_OPTIONS} --prefix "${BUILD_DIR}"/wine-protonGE-amd64
${BWRAP64} make -j8
${BWRAP64} make install

fi

echo
echo "Compilation complete"
echo "Creating and compressing archives..."

cd "${BUILD_DIR}" || exit

if touch "${scriptdir}"/write_test; then
	rm -f "${scriptdir}"/write_test
	result_dir="${scriptdir}"
else
	result_dir="${HOME}"
fi

export XZ_OPT="-9"
mkdir results
mv wine-protonGE-amd64 results/wine

if [ -d "results/wine" ]; then
    rm -rf results/wine/include results/wine/share/applications results/wine/share/man

    if [ -f wine/wine-tkg-config.txt ]; then
        cp results/wine/wine-tkg-config.txt results/wine
    fi
    cd results
    tar -Jcf "wine-action-protonGE".tar.xz wine
    mv wine-action-protonGE.tar.xz "${result_dir}"
    cd -
fi


echo
echo "Done"
echo "The builds should be in ${result_dir}"
