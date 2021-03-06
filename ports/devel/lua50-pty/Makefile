# New ports collection makefile for: 	lua50-pty
# Date created:				3 Apr 2005
# Whom:					Chris Pressey

PORTNAME=	lua50-pty
PORTVERSION=	0.1
INTERNAL=	YES
CATEGORIES=	devel
DISTNAME=	luapty-${PORTVERSION}
WRKSRC=		work/pty

LIB_DEPENDS=	lua50.5:${PORTSDIR}/lang/lua50
BUILD_DEPENDS=	${LOCALBASE}/bin/lua50c51:${PORTSDIR}/devel/lua50-compat51
RUN_DEPENDS=	${LOCALBASE}/bin/lua50c51:${PORTSDIR}/devel/lua50-compat51

MAINTAINER=	cpressey@catseye.mine.nu
COMMENT=	Pty (pseudo-terminal) bindings for Lua 5.0.x

PLIST_FILES=	lib/lua/5.0/lpty.so \
		share/lua/5.0/pty.lua

do-fetch:
	@if [ ! -f ${_DISTDIR}${DISTNAME}${EXTRACT_SUFX} ]; then		\
		${ECHO_MSG};							\
		${ECHO_MSG} "Distfile ${DISTNAME}${EXTRACT_SUFX} not found!";	\
		${ECHO_MSG};							\
		${ECHO_MSG} "This is an 'INTERNAL' port, meaning that the distfile is not retrieved";	\
		${ECHO_MSG} "from the Internet, but rather created from a local checkout of the";	\
		${ECHO_MSG} "BSD Installer CVS repository.  Please see the shell scripts in the";	\
		${ECHO_MSG} "scripts/build directory of the repository for more information on how";	\
		${ECHO_MSG} "to create these distfiles.";			\
		false;								\
	fi

do-install:
	${INSTALL_PROGRAM} ${WRKSRC}/lpty.so ${PREFIX}/lib/lua/5.0
	${INSTALL_DATA} ${WRKSRC}/pty.lua ${PREFIX}/share/lua/5.0

OSTYPE!=sysctl -n kern.ostype

.if ${OSTYPE} == "FreeBSD"
.include <bsd.port.mk>
.endif

.if ${OSTYPE} == "DragonFly"
.include <bsd.dfport.mk>
.endif
