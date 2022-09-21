FILES = choices.c match.c fzy.c

CFLAGS += $(shell pkg-config --cflags luajit)
LIBS += -lpthread $(shell pkg-config --libs luajit)

LIBPATH := ../fzy.so

all:
	$(CC) $(CFLAGS) -Ofast -fPIC -shared $(LIBS) $(FILES) -o $(LIBPATH)

format:
	uncrustify --replace --no-backup -c .uncrustify *.c *.h

lint:
	uncrustify --check -c .uncrustify *.c *.h

clean:
	rm -f $(LIBPATH)
