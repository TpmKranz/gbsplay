/*
 * gbsplay is a Gameboy sound player
 *
 * This file contains various toolbox functions that
 * can be useful in different parts of gbsplay.
 *
 * 2003-2020 (C) by Christian Garbs <mitch@cgarbs.de>
 *
 * Licensed under GNU GPL v1 or, at your option, any later version.
 */

#include <stdlib.h>
#include <stdbool.h>
#include <stdarg.h>
#include <inttypes.h>

#include "common.h"
#include "util.h"
#include "test.h"

typedef bool emit_fn(void *ctx, uint8_t val);

static int vspack(emit_fn emit, void *ctx, const char *fmt, va_list ap)
{
	/* <  little endian
	 * >  big endian
	 * =  native endian
	 * {  enter verbatim section
	 * }  exit verbatim section
	 * b  byte        (8 bit)
	 * w  word       (16 bit)
	 * d  doubleword (32 bit)
	 * q  quadword   (64 bit)
	 */
	bool little_endian = is_le_machine();
	bool verbatim = false;
	int bytes = 0;
	int written = 0;
	uint64_t tmp = 0;
	for (;*fmt;fmt++) {
		if (verbatim && *fmt != '}') {
			tmp = *fmt;
			bytes = 1;
		} else switch (*fmt) {
		case '{': verbatim = true; break;
		case '}': verbatim = false; break;
		case '=': little_endian = is_le_machine(); break;
		case '<': little_endian = true; break;
		case '>': little_endian = false; break;
		case 'b':
			/* promoted type is int */
			tmp = va_arg(ap, int);
			bytes = sizeof(uint8_t);
			break;
		case 'w':
			/* promoted type is int */
			tmp = va_arg(ap, int);
			bytes = sizeof(uint16_t);
			break;
		case 'd':
			tmp = va_arg(ap, uint32_t);
			bytes = sizeof(uint32_t);
			break;
		case 'q':
			tmp = va_arg(ap, uint64_t);
			bytes = sizeof(uint64_t);
			break;
		}
		for (int i = 0; i < bytes; i++) {
			int shift = little_endian ? i : bytes - i - 1;
			uint64_t x = tmp >> (shift * 8);
			if (!emit(ctx, x)) {
				goto exit;
			}
			written++;
		}
		bytes = 0;
	}
exit:
	return written;
}

static bool emit_buf(void *ctx, uint8_t val)
{
	uint8_t **buf = ctx;
	**buf = val;
	(*buf)++;
	return true;
}

static bool emit_file(void *ctx, uint8_t val)
{
	FILE *f = ctx;
	return fwrite(&val, 1, 1, f) == 1;
}

int spack(uint8_t *dst, const char *fmt, ...)
{
	int written;
	va_list ap;
	va_start(ap, fmt);
	written = vspack(emit_buf, &dst, fmt, ap);
	va_end(ap);
	return written;
}

int fpack(FILE *f, const char *fmt, ...)
{
	int written;
	va_list ap;
	va_start(ap, fmt);
	written = vspack(emit_file, f, fmt, ap);
	va_end(ap);
	return written;
}

int fpackat(FILE *f, long offset, const char *fmt, ...)
{
	int written;
	va_list ap;
	fseek(f, offset, SEEK_SET);
	va_start(ap, fmt);
	written = vspack(emit_file, f, fmt, ap);
	va_end(ap);
	return written;
}

test void test_spack()
{
	uint8_t want[] = { 0x20, 1, 2, 0, 3, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0,
	                   0x31, 1, 0, 2, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 4 };
	uint8_t got[sizeof(want)] = { 0 };
	uint8_t b = 1;
	uint8_t w = 2;
	uint8_t d = 3;
	uint8_t q = 4;

	int l = spack(got, "{ }<bwdq{1}>bwdq", b, w, d, q, b, w, d, q);

	ASSERT_ARRAY_EQUAL("%d", want, got);
	ASSERT_EQUAL("%d", (int)sizeof(want), l);
}
TEST(test_spack);

long rand_long(long max)
/* return random long from [0;max[ */
{
	return (long) (((double)max)*rand()/(RAND_MAX+1.0));
}

void shuffle_long(long *array, long elements)
/* shuffle a long array in place
 * Fisher-Yates algorithm, see `perldoc -q shuffle` :-)  */
{
	long i, j, temp;
	for (i = elements-1; i > 0; i--) {
		j=rand_long(i);      /* pick element  */
		temp = array[i];     /* swap elements */
		array[i] = array[j];
		array[j] = temp;
	}
}

test void test_shuffle()
{
	long actual[]   = { 1, 2, 3, 4, 5, 6, 7, 8, 9 };
#ifdef __MSYS__
	long expected[] = { 7, 8, 9, 2, 6, 3, 4, 5, 1 };
#else
	long expected[] = { 2, 8, 9, 1, 6, 4, 5, 3, 7 };
#endif
	long len = sizeof(actual) / sizeof(*actual);
	int i;

	srand(0);
	shuffle_long(actual, len);

	for (i=0; i<len; i++) {
		ASSERT_EQUAL("%ld", actual[i], expected[i]);
	}
}
TEST(test_shuffle);
TEST_EOF;
