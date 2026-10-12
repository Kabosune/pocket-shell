CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra
SDL      = $(shell pkg-config --cflags --libs sdl3)

pocket-input: pocket-input.c
	$(CC) $(CFLAGS) -o $@ $< $(SDL)

clean:
	rm -f pocket-input

.PHONY: clean
