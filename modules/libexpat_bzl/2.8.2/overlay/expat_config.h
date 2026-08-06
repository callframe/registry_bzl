/* Replaces the configure-generated expat_config.h shipped in the release
   tarball, which is stale and misconfigures every non-glibc target.
   Entropy comes from rand_s on Windows and /dev/urandom elsewhere, so the
   HAVE_ARC4RANDOM* / HAVE_GET{RANDOM,ENTROPY} probes stay undefined. */

#ifndef EXPAT_CONFIG_H
#define EXPAT_CONFIG_H 1

#if defined(_WIN32)
#  define BYTEORDER 1234
#else
#  define BYTEORDER __BYTE_ORDER__
#  define XML_DEV_URANDOM 1
#endif

#endif /* ndef EXPAT_CONFIG_H */
