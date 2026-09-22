#ifndef CL_WUFFS_H
#define CL_WUFFS_H

#include <stddef.h>
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
};

struct cl_wuffs_image {
  uint8_t* pixels;
  size_t length;
  uint32_t width;
  uint32_t height;
  uint32_t stride;
};

int32_t cl_wuffs_detect_format(const uint8_t* data, size_t length);
int32_t cl_wuffs_decode_image(const uint8_t* data, size_t length,
                              struct cl_wuffs_image* image,
                              const char** error_message);
uint32_t cl_wuffs_adler32(const uint8_t* data, size_t length);
void cl_wuffs_free(void* pointer);

#ifdef __cplusplus
}
#endif

#endif
