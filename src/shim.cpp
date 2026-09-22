#define WUFFS_IMPLEMENTATION
#include "../vendor/wuffs/wuffs-v0.3.c"
#include "cl_wuffs.h"

#include <cstdlib>
#include <cstring>

namespace {

thread_local std::string last_error;

const char* status_message(int32_t status) {
  switch (status) {
    case CL_WUFFS_UNKNOWN_FORMAT:
      return "unknown image format";
    case CL_WUFFS_INVALID_ARGUMENT:
      return "invalid argument";
    case CL_WUFFS_OUT_OF_MEMORY:
      return "out of memory";
    default:
      return "image decode failed";
  }
}

}  // namespace

extern "C" int32_t cl_wuffs_detect_format(const uint8_t* data, size_t length) {
  if (!data && length) {
    return 0;
  }
  return wuffs_base__magic_number_guess_fourcc(
      wuffs_base__make_slice_u8(const_cast<uint8_t*>(data), length), true);
}

extern "C" int32_t cl_wuffs_decode_image(const uint8_t* data, size_t length,
                                           struct cl_wuffs_image* image,
                                           const char** error_message) {
  if (error_message) {
    *error_message = nullptr;
  }
  if (!image || (!data && length)) {
    last_error = status_message(CL_WUFFS_INVALID_ARGUMENT);
    if (error_message) *error_message = last_error.c_str();
    return CL_WUFFS_INVALID_ARGUMENT;
  }
  std::memset(image, 0, sizeof(*image));
  int32_t fourcc = cl_wuffs_detect_format(data, length);
  switch (fourcc) {
    case WUFFS_BASE__FOURCC__BMP:
    case WUFFS_BASE__FOURCC__GIF:
    case WUFFS_BASE__FOURCC__NIE:
    case WUFFS_BASE__FOURCC__PNG:
    case WUFFS_BASE__FOURCC__TGA:
    case WUFFS_BASE__FOURCC__WBMP:
      break;
    default:
      last_error = status_message(CL_WUFFS_UNKNOWN_FORMAT);
      if (error_message) *error_message = last_error.c_str();
      return CL_WUFFS_UNKNOWN_FORMAT;
  }
  wuffs_aux::sync_io::MemoryInput input(data, length);
  wuffs_aux::DecodeImageCallbacks callbacks;
  wuffs_aux::DecodeImageResult result = wuffs_aux::DecodeImage(callbacks, input);
  if (!result.error_message.empty()) {
    last_error = result.error_message;
    if (error_message) *error_message = last_error.c_str();
    return CL_WUFFS_DECODE_ERROR;
  }
  uint64_t bytes = wuffs_base__pixel_config__pixbuf_len(&result.pixbuf.pixcfg);
  if (bytes > SIZE_MAX) {
    last_error = status_message(CL_WUFFS_OUT_OF_MEMORY);
    if (error_message) *error_message = last_error.c_str();
    return CL_WUFFS_OUT_OF_MEMORY;
  }
  uint8_t* pixels = static_cast<uint8_t*>(std::malloc(static_cast<size_t>(bytes)));
  if (!pixels && bytes) {
    last_error = status_message(CL_WUFFS_OUT_OF_MEMORY);
    if (error_message) *error_message = last_error.c_str();
    return CL_WUFFS_OUT_OF_MEMORY;
  }
  wuffs_base__table_u8 plane = result.pixbuf.plane(0);
  std::memcpy(pixels, plane.ptr, static_cast<size_t>(bytes));
  image->pixels = pixels;
  image->length = static_cast<size_t>(bytes);
  image->width = wuffs_base__pixel_config__width(&result.pixbuf.pixcfg);
  image->height = wuffs_base__pixel_config__height(&result.pixbuf.pixcfg);
  image->stride = image->width * 4;
  return CL_WUFFS_OK;
}

extern "C" uint32_t cl_wuffs_adler32(const uint8_t* data, size_t length) {
  if (!data && length) return 0;
  wuffs_adler32__hasher hasher = {};
  if (!wuffs_adler32__hasher__initialize(&hasher, sizeof(hasher), WUFFS_VERSION,
                                         WUFFS_INITIALIZE__ALREADY_ZEROED).is_ok()) {
    return 0;
  }
  return wuffs_adler32__hasher__update_u32(
      &hasher, wuffs_base__make_slice_u8(const_cast<uint8_t*>(data), length));
}

extern "C" void cl_wuffs_free(void* pointer) {
  std::free(pointer);
}
