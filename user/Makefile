CC ?= aarch64-linux-gnu-gcc
CFLAGS := -O2 -Wall -fPIC

all: libclient.a test_client

libclient.a: client.c client.h
	$(CC) $(CFLAGS) -c client.c -o client.o
	ar rcs libclient.a client.o

test_client: test_client.c libclient.a
	$(CC) $(CFLAGS) test_client.c -L. -lclient -o test_client

clean:
	rm -f *.o *.a test_client

.PHONY: all clean
