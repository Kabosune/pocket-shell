CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra
SDL      = $(shell pkg-config --cflags --libs sdl3)

all: pocket-input pocket-padtest

pocket-input: pocket-input.c
	$(CC) $(CFLAGS) -o $@ $< $(SDL)

pocket-padtest: pocket-padtest.c
	$(CC) $(CFLAGS) -o $@ $< $(SDL)

clean:
	rm -f pocket-input pocket-padtest

.PHONY: all clean
