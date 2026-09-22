#ifndef CL_WUFFS_H
#define CL_WUFFS_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum cl_wuffs_status {
  CL_WUFFS_OK = 0,
  CL_WUFFS_UNKNOWN_FORMAT = 1,
  CL_WUFFS_DECODE_ERROR = 2,
  CL_WUFFS_INVALID_ARGUMENT = 3,
  CL_WUFFS_OUT_OF_MEMORY = 4,
  CL_WUFFS_DECOMPRESSION_ERROR = 5,
};

enum cl_wuffs_compression_format {
  CL_WUFFS_BZIP2 = 1,
  CL_WUFFS_DEFLATE = 2,
  CL_WUFFS_GZIP = 3,
  CL_WUFFS_LZW = 4,
  CL_WUFFS_ZLIB = 5,
};

enum cl_wuffs_hash_algorithm {
  CL_WUFFS_ADLER32 = 1,
  CL_WUFFS_CRC32 = 2,
};

struct cl_wuffs_image {
  uint8_t* pixels;
  size_t length;
  uint32_t width;
  uint32_t height;
  uint32_t stride;
};

struct cl_wuffs_decompressor;
struct cl_wuffs_hasher;

int32_t cl_wuffs_detect_format(const uint8_t* data, size_t length);
int32_t cl_wuffs_decode_image(const uint8_t* data, size_t length,
                              struct cl_wuffs_image* image,
                              const char** error_message);
uint32_t cl_wuffs_adler32(const uint8_t* data, size_t length);
uint32_t cl_wuffs_crc32(const uint8_t* data, size_t length);
int32_t cl_wuffs_hasher_create(int32_t algorithm,
                               struct cl_wuffs_hasher** hasher,
                               const char** error_message);
int32_t cl_wuffs_hasher_update(struct cl_wuffs_hasher* hasher,
                               const uint8_t* data, size_t length,
                               uint32_t* digest, const char** error_message);
void cl_wuffs_hasher_free(struct cl_wuffs_hasher* hasher);
int32_t cl_wuffs_decompressor_create(int32_t format, uint32_t literal_width,
                                     struct cl_wuffs_decompressor** decompressor,
                                     const char** error_message);
int32_t cl_wuffs_decompressor_process(struct cl_wuffs_decompressor* decompressor,
                                      const uint8_t* data, size_t length,
                                      bool finish, uint8_t** output,
                                      size_t* output_length,
                                      const char** error_message);
void cl_wuffs_decompressor_free(struct cl_wuffs_decompressor* decompressor);
void cl_wuffs_free(void* pointer);

#ifdef __cplusplus
}
#endif

#endif
