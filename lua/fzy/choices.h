#ifndef CHOICES_H
#define CHOICES_H CHOICES_H

#include <stdio.h>

#include "config.h"
#include "match.h"

struct scored_result {
	score_t score;
	const char *str;
};

typedef struct {
	char *buffer;
	size_t buffer_size;

	size_t capacity;
	size_t size;

	const char **strings;
	struct scored_result *results;

	size_t available;
	size_t selection;

	unsigned int worker_count;

	char prompt[PROMPT_LEN];
} choices_t;

void choices_init(choices_t *c, int workers);
void choices_fread(choices_t *c, FILE *file, char input_delimiter);
void choices_destroy(choices_t *c);
void choices_add(choices_t *c, const char *choice);
void choices_add_incremental(choices_t *c, const char *choices[], size_t n);
size_t choices_available(choices_t *c);
void choices_search(choices_t *c, const char *search);
const char *choices_get(choices_t *c, size_t n);
score_t choices_getscore(choices_t *c, size_t n);
void choices_prev(choices_t *c);
void choices_next(choices_t *c);

#endif
