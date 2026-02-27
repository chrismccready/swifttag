#ifndef FlacMetadataBridge_h
#define FlacMetadataBridge_h

#include <stddef.h>

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

// Reads Vorbis comment tags from a FLAC file.
// Returns 0 on success; non-zero on error.
// On success, caller must call flac_free_tag_result.
// On error, if error_message is non-NULL, caller must call flac_free_c_string.
int flac_read_tags(const char *file_path, FlacTagResult *out_result, char **error_message);

void flac_free_tag_result(FlacTagResult *result);
void flac_free_c_string(char *value);

#ifdef __cplusplus
}
#endif

#endif
