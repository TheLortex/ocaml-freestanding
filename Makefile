.PHONY: all clean install uninstall distclean ocaml

include Makeconf

all:	openlibm/libopenlibm.a nolibc/libnolibc.a ocaml ocaml-freestanding.pc freestanding.conf

TOP=$(abspath .)

# CFLAGS used to build nolibc / openlibm / ocaml runtime
LOCAL_CFLAGS=$(MAKECONF_CFLAGS) -I$(TOP)/nolibc/include -include _freestanding/overrides.h
# CFLAGS used by the OCaml compiler to build C stubs
GLOBAL_CFLAGS=$(MAKECONF_CFLAGS) -I$(MAKECONF_PREFIX)/freestanding-sysroot/include/nolibc/ -include _freestanding/overrides.h
# LIBS used by the OCaml compiler to link executables
GLOBAL_LIBS=-L$(MAKECONF_PREFIX)/freestanding-sysroot/lib/nolibc/ -lnolibc -lopenlibm $(MAKECONF_EXTRA_LIBS)

# NOLIBC
NOLIBC_CFLAGS=$(LOCAL_CFLAGS) -I$(TOP)/openlibm/src -I$(TOP)/openlibm/include
nolibc/libnolibc.a:
	$(MAKE) -C nolibc \
	    "CC=$(MAKECONF_CC)" \
	    "FREESTANDING_CFLAGS=$(NOLIBC_CFLAGS)" \
	    "SYSDEP_OBJS=$(MAKECONF_NOLIBC_SYSDEP_OBJS)"

# OPENLIBM
openlibm/libopenlibm.a:
	$(MAKE) -C openlibm \
		"USECLANG=1" \
	    "CC=$(MAKECONF_CC)" \
	    "CFLAGS=$(LOCAL_CFLAGS)" \
	    libopenlibm.a

# OCAML
ocaml/Makefile:
	cp -r `ocamlfind query ocaml-src` ./ocaml
	sed -i -e 's/runtime\/ocamlrun tools/$$(CAMLRUN) tools/g' ocaml/Makefile
	sed -i -e 's/otherlibraries="dynlink"/otherlibraries=""/g' ocaml/configure
	sed -i -e 's/oc_cflags="/oc_cflags="$$OC_CFLAGS /g' ocaml/configure
	sed -i -e 's/ocamlc_cflags="/ocamlc_cflags="$$OCAMLC_CFLAGS /g' ocaml/configure
	sed -i -e 's/nativecclibs="$$cclibs $$DLLIBS"/nativecclibs="$$GLOBAL_LIBS"/g' ocaml/configure
	echo -e "ocamlrun:\n\tcp $(shell which ocamlrun) .\n" >> ocaml/runtime/Makefile
	echo -e "ocamlrund:\n\tcp $(shell which ocamlrund) .\n" >> ocaml/runtime/Makefile
	echo -e "ocamlruni:\n\tcp $(shell which ocamlruni) .\n" >> ocaml/runtime/Makefile
	echo -e "ocamlyacc:\n\tcp $(shell which ocamlyacc) .\n" >> ocaml/yacc/Makefile
	echo -e "objinfo_helper:\n\ttouch objinfo_helper\n" >> ocaml/tools/Makefile

stubs/solo5_stubs.o: stubs/solo5_stubs.c
	$(MAKECONF_CC) -c $(MAKECONF_CFLAGS) -o $@ $<

# OCaml >= 4.08.0 uses an autotools-based build system. In this case we
# convince it to think it's using the Solo5 compiler as a cross compiler, and
# let the build system do its work with as little additional changes on our
# side as possible.
#
# Notes:
#
# - CPPFLAGS must be set for configure as well as CC, otherwise it complains
#   about headers due to differences of opinion between the preprocessor and
#   compiler.
# - ARCH must be overridden manually in Makefile.config due to the use of
#   hardcoded combinations in the OCaml configure.
# - We use LIBS with a stubbed out solo5 implementation to override the OCaml 
# 	configure link test
# - We override OCAML_OS_TYPE since configure just hardcodes it to "Unix".
# - We override HAS_SOCKETS because of a bug in the ocaml configure script that
# 	always enables sockets.
OC_CFLAGS=$(LOCAL_CFLAGS) -I$(TOP)/openlibm/include -I$(TOP)/openlibm/src -nostdlib
OC_LIBS=-L$(TOP)/nolibc -lnolibc -L$(TOP)/openlibm -lopenlibm $(TOP)/stubs/solo5_stubs.o -nostdlib $(MAKECONF_EXTRA_LIBS)
ocaml/Makefile.config: ocaml/Makefile stubs/solo5_stubs.o openlibm/libopenlibm.a nolibc/libnolibc.a
	cd ocaml && \
		CC="$(MAKECONF_CC)" \
		OC_CFLAGS="$(OC_CFLAGS)" \
		OCAMLC_CFLAGS="$(GLOBAL_CFLAGS)" \
		AS="$(MAKECONF_AS)" \
		ASPP="$(MAKECONF_CC) $(OC_CFLAGS) -c" \
		CPPFLAGS="$(OC_CFLAGS)" \
		LIBS="$(OC_LIBS)"\
		GLOBAL_LIBS="$(GLOBAL_LIBS)"\
		LD="$(MAKECONF_LD)" \
		ac_cv_prog_DIRECT_LD="$(MAKECONF_LD)" \
	  ./configure \
		-host=$(MAKECONF_BUILD_ARCH)-unknown-none \
		-prefix $(MAKECONF_PREFIX)/freestanding-sysroot \
		-disable-shared\
		-disable-systhreads\
		-disable-unix-lib\
		-disable-instrumented-runtime
	echo "ARCH=$(MAKECONF_OCAML_BUILD_ARCH)" >> ocaml/Makefile.config
	echo '#undef HAS_SOCKETS' >> ocaml/runtime/caml/s.h
	echo '#undef OCAML_OS_TYPE' >> ocaml/runtime/caml/s.h
	echo '#define OCAML_OS_TYPE "None"' >> ocaml/runtime/caml/s.h

ocaml/runtime/caml/version.h: ocaml/Makefile.config
	ocaml/tools/make-version-header.sh > $@

CAMLOPT:=$(shell which ocamlopt)
CAMLRUN:=$(shell which ocamlrun)
CAMLC:=$(shell which ocamlc)

ocaml: ocaml/Makefile.config ocaml/runtime/caml/version.h
	$(MAKE) -C ocaml world
	$(MAKE) -C ocaml opt

# CONFIGURATION FILES
ocaml-freestanding.pc: ocaml-freestanding.pc.in Makeconf
	sed -e 's!@@PKG_CONFIG_EXTRA_LIBS@@!$(MAKECONF_EXTRA_LIBS)!' ocaml-freestanding.pc.in |\
	sed -e 's!@@CFLAGS@@!$(MAKECONF_CFLAGS)!' > $@

freestanding.conf: freestanding.conf.in
	sed -e 's!@@PREFIX@@!$(MAKECONF_PREFIX)!' \
	    freestanding.conf.in > $@

# COMMANDS
install: all
	MAKE=$(MAKE) PREFIX=$(MAKECONF_PREFIX) ./install.sh

uninstall:
	./uninstall.sh

clean:
	$(RM) -r ocaml/
	$(RM) ocaml-freestanding.pc freestanding.conf
	$(RM) stubs/solo5_stubs.o
	$(MAKE) -C openlibm clean
	$(MAKE) -C nolibc \
	    "FREESTANDING_CFLAGS=$(NOLIBC_CFLAGS)" \
	    "SYSDEP_OBJS=$(MAKECONF_NOLIBC_SYSDEP_OBJS)" \
	    clean

distclean: clean
	rm Makeconf
