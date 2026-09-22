#define WUFFS_IMPLEMENTATION
#include "../vendor/wuffs/wuffs-v0.3.c"
#include "cl_wuffs.h"

#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

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
    case CL_WUFFS_DECOMPRESSION_ERROR:
      return "decompression failed";
    default:
      return "image decode failed";
  }
}

bool set_error(const char** error_message, const char* message) {
  last_error = message;
  if (error_message) *error_message = last_error.c_str();
  return false;
}

}  // namespace

struct cl_wuffs_decompressor {
  wuffs_base__io_transformer* transformer;
  std::vector<uint8_t> workbuf;
  std::vector<uint8_t> pending_input;
  uint64_t input_position;
  bool finished;
};

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

extern "C" int32_t cl_wuffs_decompressor_create(
    int32_t format, uint32_t literal_width,
    struct cl_wuffs_decompressor** decompressor, const char** error_message) {
  if (error_message) *error_message = nullptr;
  if (!decompressor) return CL_WUFFS_INVALID_ARGUMENT;
  *decompressor = nullptr;
  wuffs_base__io_transformer* transformer = nullptr;
  switch (format) {
    case CL_WUFFS_BZIP2:
      transformer = wuffs_bzip2__decoder__alloc_as__wuffs_base__io_transformer();
      break;
    case CL_WUFFS_DEFLATE:
      transformer = wuffs_deflate__decoder__alloc_as__wuffs_base__io_transformer();
      break;
    case CL_WUFFS_GZIP:
      transformer = wuffs_gzip__decoder__alloc_as__wuffs_base__io_transformer();
      break;
    case CL_WUFFS_LZW: {
      auto* decoder = wuffs_lzw__decoder__alloc();
      if (decoder && (literal_width < 2 || literal_width > 8)) {
        std::free(decoder);
        set_error(error_message, "LZW literal width must be between 2 and 8");
        return CL_WUFFS_INVALID_ARGUMENT;
      }
      if (decoder) wuffs_lzw__decoder__set_literal_width(decoder, literal_width);
      transformer = wuffs_lzw__decoder__upcast_as__wuffs_base__io_transformer(decoder);
      break;
    }
    case CL_WUFFS_ZLIB:
      transformer = wuffs_zlib__decoder__alloc_as__wuffs_base__io_transformer();
      break;
    default:
      set_error(error_message, "unsupported compression format");
      return CL_WUFFS_INVALID_ARGUMENT;
  }
  if (!transformer) {
    set_error(error_message, "out of memory");
    return CL_WUFFS_OUT_OF_MEMORY;
  }
  wuffs_base__range_ii_u64 workbuf_len =
      wuffs_base__io_transformer__workbuf_len(transformer);
  if (workbuf_len.max_incl > SIZE_MAX) {
    std::free(transformer);
    set_error(error_message, "decoder work buffer is too large");
    return CL_WUFFS_OUT_OF_MEMORY;
  }
  try {
    *decompressor = new cl_wuffs_decompressor{
        transformer, std::vector<uint8_t>(static_cast<size_t>(workbuf_len.max_incl)), {}, 0, false};
  } catch (...) {
    std::free(transformer);
    set_error(error_message, "out of memory");
    return CL_WUFFS_OUT_OF_MEMORY;
  }
  return CL_WUFFS_OK;
}

extern "C" int32_t cl_wuffs_decompressor_process(
    struct cl_wuffs_decompressor* decompressor, const uint8_t* data, size_t length,
    bool finish, uint8_t** output, size_t* output_length, const char** error_message) {
  if (error_message) *error_message = nullptr;
  if (!decompressor || !output || !output_length || (!data && length)) {
    set_error(error_message, "invalid argument");
    return CL_WUFFS_INVALID_ARGUMENT;
  }
  *output = nullptr;
  *output_length = 0;
  if (decompressor->finished) {
    set_error(error_message, "decompressor is already finished");
    return CL_WUFFS_INVALID_ARGUMENT;
  }
  std::vector<uint8_t> result;
  try {
    if (length) {
      decompressor->pending_input.insert(decompressor->pending_input.end(), data, data + length);
    }
  } catch (...) {
    set_error(error_message, "out of memory");
    return CL_WUFFS_OUT_OF_MEMORY;
  }
  size_t available = decompressor->pending_input.size();
  if (!finish) {
    if (available == 1) return CL_WUFFS_OK;
    available--;
  }
  wuffs_base__io_buffer src = wuffs_base__make_io_buffer(
      wuffs_base__make_slice_u8(decompressor->pending_input.data(), available),
      wuffs_base__make_io_buffer_meta(available, 0, decompressor->input_position, finish));
  for (;;) {
    uint8_t buffer[8192];
    wuffs_base__io_buffer dst = wuffs_base__ptr_u8__writer(buffer, sizeof(buffer));
    wuffs_base__slice_u8 workbuf = wuffs_base__make_slice_u8(
        decompressor->workbuf.data(), decompressor->workbuf.size());
    wuffs_base__status status = wuffs_base__io_transformer__transform_io(
        decompressor->transformer, &dst, &src, workbuf);
    try {
      result.insert(result.end(), buffer, buffer + dst.meta.wi);
    } catch (...) {
      set_error(error_message, "out of memory");
      return CL_WUFFS_OUT_OF_MEMORY;
    }
    if (status.repr == wuffs_base__suspension__short_write) continue;
    if (status.repr == wuffs_base__suspension__short_read && !finish) break;
    if (!status.repr || status.repr == wuffs_base__note__end_of_data) {
      if (finish) decompressor->finished = true;
      break;
    }
    last_error = status.repr;
    if (error_message) *error_message = last_error.c_str();
    return CL_WUFFS_DECOMPRESSION_ERROR;
  }
  decompressor->input_position += src.meta.ri;
  decompressor->pending_input.erase(decompressor->pending_input.begin(),
                                    decompressor->pending_input.begin() + src.meta.ri);
  if (result.empty()) return CL_WUFFS_OK;
  uint8_t* bytes = static_cast<uint8_t*>(std::malloc(result.size()));
  if (!bytes) {
    set_error(error_message, "out of memory");
    return CL_WUFFS_OUT_OF_MEMORY;
  }
  std::memcpy(bytes, result.data(), result.size());
  *output = bytes;
  *output_length = result.size();
  return CL_WUFFS_OK;
}

extern "C" void cl_wuffs_decompressor_free(
    struct cl_wuffs_decompressor* decompressor) {
  if (!decompressor) return;
  std::free(decompressor->transformer);
  delete decompressor;
}

extern "C" void cl_wuffs_free(void* pointer) {
  std::free(pointer);
}
