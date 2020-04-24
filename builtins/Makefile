ifneq ($(shell pkg-config --exists bash > /dev/null; echo $$?),0)
  $(error Could not find pkg-config package for bash, \
      please install the bash-builtins system package)
endif

CC := `pkg-config --variable=SHOBJ_CC bash`
LD := `pkg-config --variable=SHOBJ_LD bash`
CFLAGS := `pkg-config --cflags bash`

PREFIX ?= /usr/local

# SHOBJ_LDFLAGS can contain `$@' for example, need to eval thus stuff
$(eval LDFLAGS = \
	`pkg-config --variable=SHOBJ_LDFLAGS bash` \
	`pkg-config --variable=SHOBJ_XLDFLAGS bash` \
	`pkg-config --libs bash`)


.c.o:
	$(CC) $(CFLAGS) -c -o $@ $<

all: oida-builtins.so

oida-builtins.so: builtins.o
	$(LD) $(LDFLAGS) -o $@ builtins.o $(SHOBJ_LIBS)

clean:
	rm -f *.o
	rm -f oida-builtins.so

install:
	install -D -m 755 oida-builtins.so $(DESTDIR)$(PREFIX)/oida-builtins.so

.PHONY: all clean install
