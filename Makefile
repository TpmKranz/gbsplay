# $Id: Makefile,v 1.69 2004/01/19 20:20:20 mitch Exp $

noincludes  := $(patsubst clean,yes,$(patsubst distclean,yes,$(MAKECMDGOALS)))

prefix      := /usr/local
exec_prefix := $(prefix)

bindir      := $(exec_prefix)/bin
mandir      := $(prefix)/man
man1dir     := $(mandir)/man1
man5dir     := $(mandir)/man5
docdir      := $(prefix)/share/doc/gbsplay
localedir   := $(prefix)/share/locale

CFLAGS  := -Wall -g -Os
LDFLAGS :=

ifneq ($(noincludes),yes)
-include config.mk
endif

DESTDIR :=
DISTDIR := gbsplay-$(VERSION)

CFLAGS  += $(EXTRA_CFLAGS)
LDFLAGS += $(EXTRA_LDFLAGS)

export CC CFLAGS LDFLAGS

docs           := README TODO HISTORY gbsplayrc_sample

mans           := gbsplay.1    gbsinfo.1    gbsplayrc.5
mans_src       := gbsplay.in.1 gbsinfo.in.1 gbsplayrc.in.5

objs_libgbspic := gbcpu.lo gbhw.lo gbs.lo cfgparser.lo crc32.lo
objs_libgbs    := gbcpu.o  gbhw.o  gbs.o  cfgparser.o  crc32.o
objs_gbsplay   := gbsplay.o util.o
objs_gbsinfo   := gbsinfo.o
objs_gbsxmms   := gbsxmms.lo

# Cygwin automatically adds .exe to binaries.
# We should notice that or we can't rm the files later!
gbsplaybin     := gbsplay
gbsinfobin     := gbsinfo
ifeq ($(cygwin_build),yes)
gbsplaybin     :=$(gbsplaybin).exe
gbsinfobin     :=$(gbsinfobin).exe
endif

objs := $(objs_libgbs) $(objs_gbsplay) $(objs_gbsinfo)
dsts := gbsplay gbsinfo

ifeq ($(build_xmmsplugin),yes)
objs += $(objs_gbsxmms)
dsts += gbsxmms.so
endif

.PHONY: all default distclean clean install dist

all: default

# include the rules for each subdir
include $(shell find . -type f -name "subdir.mk")

default: config.mk $(objs) $(dsts) $(mans) $(EXTRA_ALL)

# include the dependency files

ifneq ($(noincludes),yes)
-include $(patsubst %.o,%.d,$(filter %.o,$(objs)))
endif

distclean: clean
	find . -regex ".*\.d" -exec rm -f "{}" \;
	rm -f ./config.mk ./config.h ./config.err ./config.sed

clean:
	find . -regex ".*\.\([aos]\|lo\|mo\|pot\|so\(\.[0-9]\)?\)" -exec rm -f "{}" \;
	find . -name "*~" -exec rm -f "{}" \;
	rm -f libgbs
	rm -f $(mans)
	rm -f ./gbsplay     ./gbsinfo
	rm -f ./gbsplay.exe ./gbsinfo.exe

install: all install-default $(EXTRA_INSTALL)

install-default:
	install -d $(bindir)
	install -d $(man1dir)
	install -d $(man5dir)
	install -d $(docdir)
	install -m 755 $(gbsplaybin) $(gbsinfobin) $(bindir)
	install -m 644 gbsplay.1 gbsinfo.1 $(man1dir)
	install -m 644 gbsplayrc.5 $(man5dir)
	install -m 644 $(docs) $(docdir)
	for i in $(mos); do \
		base=`basename $$i`; \
		install -d $(localedir)/$${base%.mo}/LC_MESSAGES; \
		install -m 644 $$i $(localedir)/$${base%.mo}/LC_MESSAGES/gbsplay.mo; \
	done

install-gbsxmms.so:
	install -d $(DESTDIR)$(XMMS_INPUT_PLUGIN_DIR)
	install -m 644 gbsxmms.so $(DESTDIR)$(XMMS_INPUT_PLUGIN_DIR)/gbsxmms.so

uninstall: uninstall-default $(EXTRA_UNINSTALL)

uninstall-default:
	rm -f $(bindir)/$(gbsplaybin) $(bindir)/$(gbsinfobin)
	-rmdir -p $(bindir)
	rm -f $(man1dir)/gbsplay.1 $(man1dir)/gbsinfo.1
	-rmdir -p $(man1dir)
	rm -f $(man5dir)/gbsplayrc.5 $(man5dir)/gbsplayrc.5	
	-rmdir -p $(man5dir)
	rm -rf $(docdir)
	-mkdir -p $(docdir)
	-rmdir -p $(docdir)
	-for i in $(mos); do \
		base=`basename $$i`; \
		rm -f $(localedir)/$${base%.mo}/LC_MESSAGES/gbsplay.mo; \
		rmdir -p $(localedir)/$${base%.mo}/LC_MESSAGES; \
	done

uninstall-gbsxmms.so:
	rm -f $(DESTDIR)$(XMMS_INPUT_PLUGIN_DIR)/gbsxmms.so
	-rmdir -p $(DESTDIR)$(XMMS_INPUT_PLUGIN_DIR)

dist:	distclean
	install -d ./$(DISTDIR)
	sed 's/^VERSION=.*/VERSION=$(VERSION)/' < configure > ./$(DISTDIR)/configure
	chmod 755 ./$(DISTDIR)/configure
	install -m 755 depend.sh ./$(DISTDIR)/
	install -m 644 Makefile ./$(DISTDIR)/
	install -m 644 *.c ./$(DISTDIR)/
	install -m 644 *.h ./$(DISTDIR)/
	install -m 644 $(mans_src) ./$(DISTDIR)/
	install -m 644 $(docs) INSTALL ./$(DISTDIR)/
	install -d ./$(DISTDIR)/contrib
	install -m 755 contrib/gbs2ogg.sh ./$(DISTDIR)/contrib
	install -d ./$(DISTDIR)/po
	install -m 644 po/*.po ./$(DISTDIR)/po
	install -m 644 po/subdir.mk ./$(DISTDIR)/po
	tar -c $(DISTDIR)/ -vzf ../$(DISTDIR).tar.gz
	rm -rf ./$(DISTDIR)

ifeq ($(use_sharedlibgbs),yes)
LDFLAGS += -L. -lgbs

libgbs.so.1: $(objs_libgbspic)
	$(CC) -fPIC -shared -Wl,-soname=$@ -o $@ $+
	ln -s $@ libgbs.so

libgbs: libgbs.so.1
else
objs_gbsinfo    += libgbs.a
objs_gbsplay    += libgbs.a
objs_gbsxmms    += libgbspic.a

libgbs: libgbs.a libgbspic.a
	touch libgbs
endif

libgbspic.a: $(objs_libgbspic)
	$(AR) r $@ $+
libgbs.a: $(objs_libgbs)
	$(AR) r $@ $+
gbsinfo: $(objs_gbsinfo) libgbs
	$(CC) -o $(gbsinfobin) $(objs_gbsinfo) $(LDFLAGS)
gbsplay: $(objs_gbsplay) libgbs
	$(CC) -o $(gbsplaybin) $(objs_gbsplay) $(LDFLAGS) -lm

gbsxmms.so: $(objs_gbsxmms) libgbs
	$(CC) -shared -fPIC -o $@ $(objs_gbsxmms) $(LDFLAGS) $(PTHREAD)

# rules for suffixes

.SUFFIXES: .i .s .lo

.c.lo:
	@echo CC $< -o $@
	@$(CC) $(CFLAGS) -fPIC -c -o $@ $<
.c.o:
	@echo CC $< -o $@
	@$(CC) $(CFLAGS) -c -o $@ $<
.c.i:
	$(CC) -E $(CFLAGS) -o $@ $<
.c.s:
	$(CC) -S $(CFLAGS) -fverbose-asm -o $@ $<

# rules for generated files

config.mk: configure
	./configure

%.d: %.c config.mk
	@echo DEP $< -o $@
	@./depend.sh $< config.mk > $@

%.1: %.in.1
	sed -f config.sed $< > $@

%.5: %.in.5
	sed -f config.sed $< > $@

