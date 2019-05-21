#ifndef _ENDIAN_H
#define _ENDIAN_H

#define __LITTLE_ENDIAN 1234
#define __BIG_ENDIAN 4321
#if defined(__x86_64__) || defined(__aarch64__)
#define __BYTE_ORDER __LITTLE_ENDIAN
#else
#error Unsupported architecture
#endif

# if __BYTE_ORDER == __LITTLE_ENDIAN
#  define htobe16(x) _bswap16 (x)
#  define htole16(x) (x)
#  define be16toh(x) _bswap16 (x)
#  define le16toh(x) (x)
#  define htobe32(x) _bswap32 (x)
#  define htole32(x) (x)
#  define be32toh(x) _bswap32 (x)
#  define le32toh(x) (x)
#  define htobe64(x) _bswap64 (x)
#  define htole64(x) (x)
#  define be64toh(x) _bswap64 (x)
#  define le64toh(x) (x)
# else
#  define htobe16(x) (x)
#  define htole16(x) _bswap16 (x)
#  define be16toh(x) (x)
#  define le16toh(x) _bswap16 (x)
#  define htobe32(x) (x)
#  define htole32(x) _bswap32 (x)
#  define be32toh(x) (x)
#  define le32toh(x) _bswap32 (x)
#  define htobe64(x) (x)
#  define htole64(x) _bswap64 (x)
#  define be64toh(x) (x)
#  define le64toh(x) _bswap64 (x)
# endif

#endif
