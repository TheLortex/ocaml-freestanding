#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/times.h>
#include <unistd.h>
#include <reent.h>
#include <stdint.h>

/**
  * @brief  Output a char to uart, which uart to output(which is in uart module in ROM) is not in scope of the function.
  *         Can not print float point data format, or longlong data format
  *
  * @param  char c : char to output.
  *
  * @return None
  */
void ets_write_char_uart(char c);


/**
  * @brief  Printf the strings to uart or other devices, similar with printf, simple than printf.
  *         Can not print float point data format, or longlong data format.
  *         So we maybe only use this in ROM.
  *
  * @param  const char *fmt : See printf.
  *
  * @param  ... : See printf.
  *
  * @return int : the length printed to the output device.
  */
int ets_printf(const char *fmt, ...);


void esp32_print(const char* s, size_t l) {
    for (int i=0;i<l;i++){
        ets_write_char_uart(s[i]);
    }
}

int fputs (const char * string, FILE * stream ) {
    return stream->write(stream, string, strlen(string));
}

/*
 * Global errno lives in this module.
 */
// newlib's libm uses __errno;
int errno;
int* __errno() {
    return &errno;
};


/*
 * Standard output and error "streams".
 */
static size_t console_write(FILE *f __attribute__((unused)), const char *s,
        size_t l)
{
    esp32_print(s, l);
    return l;
}

static FILE console = { .write = console_write };
FILE *stderr = &console;
FILE *stdout = &console;

ssize_t write(int fd, const void *buf, size_t count)
{
    if (fd == 1 || fd == 2) {
        esp32_print(buf, count);
        return count;
    }
    errno = ENOSYS;
    return -1;
}


int esp_cpu_in_ocd_debug_mode() /* from IDF cpu_util.c */
{
    int dcr;
    int reg=0x10200C; //DSRSET register
    asm("rer %0,%1":"=r"(dcr):"r"(reg));
    return (dcr&0x1);
}


void exit(int status)
{
    while(1);
}

void abort(void) /* from IDF bootloader_init.c */
{
    ets_printf("abort() was called at PC 0x%08x\r\n", (intptr_t)__builtin_return_address(0) - 3);

    if (esp_cpu_in_ocd_debug_mode()) {
        __asm__ ("break 0,0");
    }
    while (1);
}

/*
 * System time.
 * FIXME: no rtc in spike/qemu
 *        returns a fake value
 */

int gettimeofday(struct timeval *tv, struct timezone *tz)
{
    esp32_print("gettimeofday() not supported on risc-v\n", 39);
    if (tv != NULL) {
        memset(tv, 0, sizeof(*tv));
    }
    if (tz != NULL) {
        memset(tz, 0, sizeof(*tz));
    }
    return 0;
}

clock_t times(struct tms *buf)
{
    memset(buf, 0, sizeof(*buf));
    return (clock_t)0;
}

static uintptr_t sbrk_start;
static uintptr_t sbrk_end;
static uintptr_t sbrk_cur;

/*
 * This is to be called by the bootcode before handing of
 * control via caml_startup(char**)
 *
 * XXX: There is intentionally no public prototype for this function. There
 * should really be a caml_freestanding_startup(), but I'm lazy and don't have
 * a proper place to put it in the build system right now.
 */
void _nolibc_init(uintptr_t heap_start, uintptr_t heap_size)
{
    sbrk_start = sbrk_cur = heap_start;
    sbrk_end = heap_start + heap_size;
}

/*
 * Called by dlmalloc to allocate or free memory.
 */
void *sbrk(intptr_t increment)
{
    uintptr_t prev, brk;
    prev = brk = sbrk_cur;

    /*
     * dlmalloc guarantees increment values less than half of size_t, so this
     * is safe from overflow.
     */
    brk += increment;
    if (brk >= sbrk_end || brk < sbrk_start)
        return (void *)-1;

    sbrk_cur = brk;
    return (void *)prev;
}

/*
 * dlmalloc configuration:
 */

/*
 * DEBUG not defined and assertions compiled out corresponds to the default
 * recommended configuration (see documentation below). If you need to debug
 * dlmalloc on Solo5 then define DEBUG to `1' here.
 */
#if defined(DEBUG) && (DEBUG)
#define ABORT_ON_ASSERT_FAILURE 0
#else
#undef assert
#define assert(x)
#define NO_MALLINFO 1
#endif

#undef WIN32
#define HAVE_MMAP 0
#define HAVE_MREMAP 0
#define MMAP_CLEARS 0
#define NO_MALLOC_STATS 1
#define LACKS_FCNTL_H
#define LACKS_SYS_PARAM_H
#define LACKS_SYS_MMAN_H
#define LACKS_STRINGS_H
#define LACKS_SYS_TYPES_H
#define LACKS_SCHED_H
#define LACKS_TIME_H
#define MALLOC_FAILURE_ACTION
#define USE_LOCKS 0

/* disable null-pointer-arithmetic warning on clang */
#if defined(__clang__) && __clang_major__ >= 6
#pragma clang diagnostic ignored "-Wnull-pointer-arithmetic"
#endif

/* inline the dlmalloc implementation into this module */
#include "dlmalloc.i"

/*
 * When adding new functions to this module, add them BEFORE the "dlmalloc
 * configuration" comment above, not here.
 */
