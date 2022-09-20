#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "choices.h"
#include "match.h"

/* Initial size of buffer for storing input in memory */
#define INITIAL_BUFFER_CAPACITY 4096

/* Initial size of choices array */
#define INITIAL_CHOICE_CAPACITY 128

static int
cmpchoice(const void *_idx1, const void *_idx2)
{
	const struct scored_result *a = _idx1;
	const struct scored_result *b = _idx2;

	if (a->score == b->score) {
		/* To ensure a stable sort, we must also sort by the string
		 * pointers. We can do this since we know all the strings are
		 * from a contiguous memory segment (buffer in choices_t).
		 */
		if (a->str < b->str) {
			return -1;
		} else {
			return 1;
		}
	} else if (a->score < b->score) {
		return 1;
	} else {
		return -1;
	}
}

static void *
safe_realloc(void *buffer, size_t size)
{
	buffer = realloc(buffer, size);
	if (!buffer) {
		fprintf(stderr, "Error: Can't allocate memory (%zu bytes)\n", size);
		abort();
	}

	return buffer;
}

void
choices_fread(choices_t *c, FILE *file, char input_delimiter)
{
	/* Save current position for parsing later */
	size_t buffer_start = c->buffer_size;

	/* Resize buffer to at least one byte more capacity than our current
	 * size. This uses a power of two of INITIAL_BUFFER_CAPACITY.
	 * This must work even when c->buffer is NULL and c->buffer_size is 0
	 */
	size_t capacity = INITIAL_BUFFER_CAPACITY;
	while (capacity <= c->buffer_size) {
		capacity *= 2;
	}
	c->buffer = safe_realloc(c->buffer, capacity);

	/* Continue reading until we get a "short" read, indicating EOF */
	while ((c->buffer_size += fread(c->buffer + c->buffer_size, 1,
	                                capacity - c->buffer_size, file)) ==
	       capacity) {
		capacity *= 2;
		c->buffer = safe_realloc(c->buffer, capacity);
	}
	c->buffer = safe_realloc(c->buffer, c->buffer_size + 1);
	c->buffer[c->buffer_size++] = '\0';

	/* Truncate buffer to used size, (maybe) freeing some memory for
	 * future allocations.
	 */

	/* Tokenize input and add to choices */
	const char *line_end = c->buffer + c->buffer_size;
	char *line = c->buffer + buffer_start;
	do {
		char *nl = strchr(line, input_delimiter);
		if (nl) {
			*nl++ = '\0';
		}

		/* Skip empty lines */
		if (*line) {
			choices_add(c, line);
		}

		line = nl;
	} while (line && line < line_end);
}

static void
choices_resize(choices_t *c, size_t new_capacity)
{
	c->strings = safe_realloc(c->strings, new_capacity * sizeof(const char *));
	c->capacity = new_capacity;
}

static void
choices_reset_search(choices_t *c)
{
	free(c->results);
	c->selection = c->available = 0;
	c->results = NULL;
	memset(c->prompt, 0x00, PROMPT_LEN);
}

void
choices_init(choices_t *c, int workers)
{
	c->strings = NULL;
	c->results = NULL;

	c->buffer_size = 0;
	c->buffer = NULL;

	c->capacity = c->size = 0;
	choices_resize(c, INITIAL_CHOICE_CAPACITY);

	if (workers) {
		c->worker_count = workers;
	} else {
		c->worker_count = (int)sysconf(_SC_NPROCESSORS_ONLN);
	}

	choices_reset_search(c);
}

void
choices_destroy(choices_t *c)
{
	free(c->buffer);
	c->buffer = NULL;
	c->buffer_size = 0;

	free(c->strings);
	c->strings = NULL;
	c->capacity = c->size = 0;

	free(c->results);
	c->results = NULL;
	c->available = c->selection = 0;
}

void
choices_add(choices_t *c, const char *choice)
{
	/* Previous search is now invalid */
	choices_reset_search(c);

	if (c->size == c->capacity) {
		choices_resize(c, c->capacity * 2);
	}
	c->strings[c->size++] = choice;

	if (*(c->prompt) != '\0') {
		choices_search(c, NULL);
	}
}

size_t
choices_available(choices_t *c)
{
	return c->available;
}

#define BATCH_SIZE 512

struct result_list {
	struct scored_result *list;
	size_t size;
};

struct search_job {
	pthread_mutex_t lock;
	choices_t *choices;
	size_t processed;
	size_t end;
	struct worker *workers;
};

struct worker {
	pthread_t thread_id;
	struct search_job *job;
	unsigned int worker_num;
	struct result_list result;
};

static void
worker_get_next_batch(struct search_job *job, size_t *start,
                      size_t *end)
{
	pthread_mutex_lock(&job->lock);

	*start = job->processed;

	job->processed += BATCH_SIZE;
	if (job->processed > job->end) {
		job->processed = job->end;
	}

	*end = job->processed;

	pthread_mutex_unlock(&job->lock);
}

static struct result_list
merge2(struct result_list list1,
       struct result_list list2)
{
	size_t result_index = 0, index1 = 0, index2 = 0;

	struct result_list result;
	result.size = list1.size + list2.size;
	result.list = malloc(result.size * sizeof(struct scored_result));
	if (!result.list) {
		fprintf(stderr, "Error: Can't allocate memory\n");
		abort();
	}

	while (index1 < list1.size && index2 < list2.size) {
		if (cmpchoice(&list1.list[index1], &list2.list[index2]) < 0) {
			result.list[result_index++] = list1.list[index1++];
		} else {
			result.list[result_index++] = list2.list[index2++];
		}
	}

	while (index1 < list1.size) {
		result.list[result_index++] = list1.list[index1++];
	}
	while (index2 < list2.size) {
		result.list[result_index++] = list2.list[index2++];
	}

	free(list1.list);
	free(list2.list);

	return result;
}

static void *
choices_search_worker(void *data)
{
	struct worker *w = (struct worker *)data;
	struct search_job *job = w->job;
	const choices_t *c = job->choices;
	struct result_list *result = &w->result;

	size_t start, end;

	for (;;) {
		worker_get_next_batch(job, &start, &end);

		if (start == end) {
			break;
		}

		for (size_t i = start; i < end; i++) {
			if (has_match(job->choices->prompt, c->strings[i])) {
				result->list[result->size].str = c->strings[i];
				result->list[result->size].score =
					match(job->choices->prompt, c->strings[i]);
				result->size++;
			}
		}
	}

	/* Sort the partial result */
	qsort(result->list, result->size, sizeof(struct scored_result), cmpchoice);

	/* Fan-in, merging results */
	for (unsigned int step = 0;; step++) {
		if (w->worker_num % (2 << step)) {
			break;
		}

		unsigned int next_worker = w->worker_num | (1 << step);
		if (next_worker >= c->worker_count) {
			break;
		}

		if ((errno = pthread_join(job->workers[next_worker].thread_id, NULL))) {
			perror("pthread_join");
			exit(EXIT_FAILURE);
		}

		w->result = merge2(w->result, job->workers[next_worker].result);
	}

	return NULL;
}

struct result_list
run_search(choices_t *c, size_t start, size_t end)
{
	struct result_list ret;
	struct search_job *job = calloc(1, sizeof(struct search_job));
	job->processed = start;
	job->end = end;
	job->choices = c;
	if (pthread_mutex_init(&job->lock, NULL) != 0) {
		fprintf(stderr, "Error: pthread_mutex_init failed\n");
		abort();
	}
	job->workers = calloc(c->worker_count, sizeof(struct worker));

	struct worker *workers = job->workers;
	for (int i = c->worker_count - 1; i >= 0; i--) {
		workers[i].job = job;
		workers[i].worker_num = i;
		workers[i].result.size = 0;
		workers[i].result.list = malloc(
			c->size * sizeof(struct scored_result)); /* FIXME: This is overkill */

		/* These must be created last-to-first to avoid a race condition when
		 * fanning in */
		if ((errno = pthread_create(&workers[i].thread_id, NULL,
		                            &choices_search_worker, &workers[i]))) {
			perror("pthread_create");
			exit(EXIT_FAILURE);
		}
	}

	if (pthread_join(workers[0].thread_id, NULL)) {
		perror("pthread_join");
		exit(EXIT_FAILURE);
	}

	ret = workers[0].result;

	free(workers);
	pthread_mutex_destroy(&job->lock);
	free(job);

	return ret;
}

void
choices_search(choices_t *c, const char *search)
{
	choices_reset_search(c);

	if (search != NULL) {
		strncpy(c->prompt, search, PROMPT_LEN);
	}

	struct result_list res = run_search(c, 0, c->size);
	c->results = res.list;
	c->available = res.size;
}

void
choices_add_incremental(choices_t *c, const char *choices[], size_t n)
{
	while (c->size + n >= c->capacity) {
		choices_resize(c, c->capacity * 2);
	}

	size_t start = c->size;
	for (size_t i = 0; i < n; i++) {
		c->strings[c->size++] = choices[i];
	}

	if (c->available && c->prompt[0] != '\0') {
		// Now we need to sort the entries we added, then merge them with the rest
		// of the entries
		struct result_list current = {
			.list = c->results,
			.size = c->available,
		};

		const char *old = c->results[c->selection].str;

		struct result_list ret = merge2(current, run_search(c, start, c->size));
		c->results = ret.list;
		c->available = ret.size;

		// Now correct the cursor position
		for (size_t i = c->selection; i < c->available; i++) {
			if (c->results[i].str == old) {
				c->selection = i;
			}
		}
	}
}

const char *
choices_get(choices_t *c, size_t n)
{
	if (n < c->available) {
		return c->results[n].str;
	} else {
		return NULL;
	}
}

score_t
choices_getscore(choices_t *c, size_t n)
{
	return c->results[n].score;
}

void
choices_prev(choices_t *c)
{
	if (c->available) {
		c->selection = (c->selection + c->available - 1) % c->available;
	}
}

void
choices_next(choices_t *c)
{
	if (c->available) {
		c->selection = (c->selection + 1) % c->available;
	}
}
