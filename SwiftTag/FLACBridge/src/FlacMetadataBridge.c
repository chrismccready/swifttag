#include "../include/FlacMetadataBridge.h"
#include <FLAC/metadata.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *bridge_strdup(const char *value) {
    if (value == NULL) {
        return NULL;
    }

    size_t len = strlen(value);
    char *copy = (char *)malloc(len + 1);
    if (copy == NULL) {
        return NULL;
    }

    memcpy(copy, value, len + 1);
    return copy;
}

static void set_error(char **error_message, const char *message) {
    if (error_message == NULL) {
        return;
    }

    if (*error_message != NULL) {
        free(*error_message);
        *error_message = NULL;
    }

    *error_message = bridge_strdup(message != NULL ? message : "Unknown bridge error");
}

static int append_tag_pair(FlacTagResult *result, const char *key, const char *value) {
    if (result == NULL || key == NULL || value == NULL) {
        return -1;
    }

    FlacTagPair *next = (FlacTagPair *)realloc(result->pairs, sizeof(FlacTagPair) * (result->count + 1));
    if (next == NULL) {
        return -1;
    }

    result->pairs = next;
    result->pairs[result->count].key = bridge_strdup(key);
    result->pairs[result->count].value = bridge_strdup(value);

    if (result->pairs[result->count].key == NULL || result->pairs[result->count].value == NULL) {
        free((void *)result->pairs[result->count].key);
        free((void *)result->pairs[result->count].value);
        result->pairs[result->count].key = NULL;
        result->pairs[result->count].value = NULL;
        return -1;
    }

    result->count += 1;
    return 0;
}

int flac_read_tags(const char *file_path, FlacTagResult *out_result, char **error_message) {
    if (out_result == NULL || file_path == NULL) {
        set_error(error_message, "Invalid arguments for flac_read_tags.");
        return -1;
    }

    out_result->pairs = NULL;
    out_result->count = 0;

    FLAC__StreamMetadata *metadata = NULL;
    FLAC__bool ok = FLAC__metadata_get_tags(file_path, &metadata);
    if (!ok || metadata == NULL) {
        set_error(error_message, "FLAC__metadata_get_tags failed for file.");
        if (metadata != NULL) {
            FLAC__metadata_object_delete(metadata);
        }
        return -1;
    }

    if (metadata->type == FLAC__METADATA_TYPE_VORBIS_COMMENT) {
        FLAC__StreamMetadata_VorbisComment vc = metadata->data.vorbis_comment;

        for (uint32_t i = 0; i < vc.num_comments; i++) {
            FLAC__StreamMetadata_VorbisComment_Entry entry = vc.comments[i];
            if (entry.entry == NULL || entry.length == 0) {
                continue;
            }

            size_t lineLen = (size_t)entry.length;
            char *line = (char *)malloc(lineLen + 1);
            if (line == NULL) {
                set_error(error_message, "Out of memory while parsing FLAC tags.");
                FLAC__metadata_object_delete(metadata);
                return -1;
            }

            memcpy(line, entry.entry, lineLen);
            line[lineLen] = '\0';

            char *equals = strchr(line, '=');
            if (equals != NULL) {
                *equals = '\0';
                const char *key = line;
                const char *value = equals + 1;

                if (key[0] != '\0') {
                    if (append_tag_pair(out_result, key, value) != 0) {
                        free(line);
                        set_error(error_message, "Out of memory while collecting FLAC tags.");
                        FLAC__metadata_object_delete(metadata);
                        return -1;
                    }
                }
            }

            free(line);
        }
    }

    FLAC__metadata_object_delete(metadata);
    return 0;
}

void flac_free_tag_result(FlacTagResult *result) {
    if (result == NULL) {
        return;
    }

    if (result->pairs != NULL) {
        for (size_t i = 0; i < result->count; i++) {
            free((void *)result->pairs[i].key);
            free((void *)result->pairs[i].value);
        }
        free(result->pairs);
    }

    result->pairs = NULL;
    result->count = 0;
}

void flac_free_c_string(char *value) {
    free(value);
}
