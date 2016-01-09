#!/bin/sh -x

# $Id: remove_installer_packages.sh,v 1.4 2005/07/30 07:07:06 cpressey Exp $
# Remove all BSD Installer packages from the running system.
# Note that this generally requires root privledges.

SCRIPT=`realpath $0`
SCRIPTDIR=`dirname $SCRIPT`

[ -r $SCRIPTDIR/build.conf ] && . $SCRIPTDIR/build.conf
. $SCRIPTDIR/build.conf.defaults
. $SCRIPTDIR/pver.conf

PVERSUFFIX=""
if [ "X$RELEASEBUILD" != "XYES" ]; then
	PVERSUFFIX=.`date "+%Y.%m%d"`
fi

INSTALLER_PACKAGES='libaura-*
		    libdfui-*
		    libinstaller-*
		    dfuibe_*
		    dfuife_*
		    thttpd-notimeout-*
		    lua50-*
		    bsdinstaller-*'

for PKG in $INSTALLER_PACKAGES; do
	pkg_delete -f $PKG || true
done

