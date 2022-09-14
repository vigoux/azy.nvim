FILES = choices.c match.c fzy.c

CFLAGS += $(shell pkg-config --cflags luajit)
LIBS = -lpthread $(shell pkg-config --libs luajit)

all:
	$(CC) $(CFLAGS) -Ofast -fPIC -shared $(LIBS) $(FILES) -o ../fzy.so
