##################################################
# Cross-Platform Makefile for the ev3duder utility
#
# Ahmad Fatoum
# Hochschule Aschaffenburg
# 2015-06-17
##################################################

BIN_NAME = ev3duder	
VERSION = 0.3.0
# tip: CC=clang FLAGS=-Weverything shows all GNU extensions
FLAGS += -std=c99 -Wall -Wextra -DVERSION='"$(VERSION)"'
SRCDIR = src
OBJDIR = build

SRCS = src/main.c src/packets.c src/run.c src/test.c src/up.c src/ls.c src/rm.c src/mkdir.c src/mkrbf.c src/dl.c src/listen.c

INC += -Ihidapi/hidapi/
 
####################
CREATE_BUILD_DIR := $(shell mkdir build 2>&1)
ifeq ($(OS),Windows_NT)

## No rm?
ifneq (, $(shell where rm 2>NUL)) 
RM = del /Q
# Powershell, cygwin and msys all provide rm(1)
endif

## Win32
FLAGS += -DCONFIGURATION='"HIDAPI/hid.dll"' -DSYSTEM="Windows"
# TODO: remove all %zu prints altogether?
FLAGS += -Wno-unused-value -D__USE_MINGW_ANSI_STDIO=1
SRCS += src/bt-win.c
HIDSRC += hidapi/windows/hid.c
LDFLAGS += -mwindows -lsetupapi -municode 
BIN_NAME := $(addsuffix .exe, $(BIN_NAME))

else
UNAME = $(shell uname -s)

## Linux
ifeq ($(UNAME),Linux)
FLAGS += -DCONFIGURATION='"HIDAPI/libusb-1.0"' -DSYSTEM='"Linux"'
HIDSRC += hidapi/libusb/hid.c
HIDFLAGS += `pkg-config libusb-1.0 --cflags`
LDFLAGS += `pkg-config libusb-1.0 --libs` -lrt -lpthread
INSTALL = $(shell sh udev.sh)
endif

## OS X
ifeq ($(UNAME),Darwin)
FLAGS += -DCONFIGURATION='"HIDAPI/IOHidManager"' -DSYSTEM='"OS X"'
HIDSRC += hidapi/mac/hid.c
LDFLAGS += -framework IOKit -framework CoreFoundation
endif

## BSD
ifeq ($(findstring BSD, $(UNAME)), BSD)
FLAGS += -DCONFIGURATION='"HIDAPI/libusb-1.0"' -DSYSTEM='"BSD"'
HIDSRC += hidapi/libusb/hid.c
LDFLAGS += -L/usr/local/lib -lusb -liconv -pthread
INC += -I/usr/local/include
endif

## ALL UNICES
SRCS += src/bt-unix.c
SRCS += src/tcp-unix.c
SRCS += src/tunnel.c
endif


OBJS = $(SRCS:$(SRCDIR)/%.c=$(OBJDIR)/%.o)

.DEFAULT: all
all: binary

binary: $(OBJS) $(OBJDIR)/hid.o
	$(CC) $(OBJS) $(OBJDIR)/hid.o $(LDFLAGS) $(LIBS) -o $(BIN_NAME)

# static enables valgrind to act better -DDEBUG!
$(OBJS): $(OBJDIR)/%.o: $(SRCDIR)/%.c
	$(CC) -c $< -MMD $(FLAGS) $(INC) -o $@
-include $(OBJDIR)/*.d

$(OBJDIR)/hid.o: $(HIDSRC)
	$(CC) -c $< -o $@ $(INC) $(HIDFLAGS)


debug: FLAGS += -g
debug: LIBS := $(LIBS)
debug: LIBS += 
debug: binary

# linux only for now, installs udev rules, for rootless access to ev3
.PHONY: install
install: binary ev3-udev.rules udev.sh
	$(INSTALL)

.PHONY: clean
clean:
	$(RM) $(BIN_NAME) && cd $(OBJDIR) && $(RM) *.o *.d 

