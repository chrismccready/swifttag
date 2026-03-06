#ifndef FlacMetadataBridge_h
#define FlacMetadataBridge_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char *key;
    const char *value;
} FlacTagPair;

typedef struct {
    FlacTagPair *pairs;
    size_t count;
} FlacTagResult;

typedef struct {
    uint32_t type;
    const char *mime_type;
    const char *description;
    unsigned char *data;
    size_t data_length;
} FlacPicture;

typedef struct {
    FlacPicture *pictures;
    size_t count;
} FlacPictureResult;

typedef struct {
    const char *key;
    const char *value;
} FlacWriteTagPair;

typedef struct {
    uint32_t type;
    const char *mime_type;
    const char *description;
    const unsigned char *data;
    size_t data_length;
} FlacWritePicture;

// Reads Vorbis comment tags from a FLAC file.
// Returns 0 on success; non-zero on error.
// On success, caller must call flac_free_tag_result.
// On error, if error_message is non-NULL, caller must call flac_free_c_string.
int flac_read_tags(const char *file_path, FlacTagResult *out_result, char **error_message);
int flac_read_pictures(const char *file_path, FlacPictureResult *out_result, char **error_message);
int flac_write_metadata(
    const char *file_path,
    const char *temp_file_path,
    const FlacWriteTagPair *tag_pairs,
    size_t tag_count,
    const FlacWritePicture *pictures,
    size_t picture_count,
    uint8_t write_tags,
    uint8_t write_pictures,
    uint8_t *used_temp_file,
    char **error_message
);

void flac_free_tag_result(FlacTagResult *result);
void flac_free_picture_result(FlacPictureResult *result);
void flac_free_c_string(char *value);

#ifdef __cplusplus
}
#endif

#endif
