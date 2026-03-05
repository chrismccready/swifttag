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

static int append_picture(FlacPictureResult *result, const FLAC__StreamMetadata_Picture *picture) {
    if (result == NULL || picture == NULL) {
        return -1;
    }

    if (picture->data == NULL || picture->data_length == 0) {
        return 0;
    }

    FlacPicture *next = (FlacPicture *)realloc(result->pictures, sizeof(FlacPicture) * (result->count + 1));
    if (next == NULL) {
        return -1;
    }

    result->pictures = next;
    FlacPicture *destination = &result->pictures[result->count];
    destination->type = (uint32_t)picture->type;
    destination->mime_type = NULL;
    destination->description = NULL;
    destination->data = NULL;
    destination->data_length = 0;

    destination->mime_type = bridge_strdup((const char *)picture->mime_type);
    destination->description = bridge_strdup((const char *)picture->description);
    destination->data = (unsigned char *)malloc((size_t)picture->data_length);

    if (destination->mime_type == NULL || destination->description == NULL || destination->data == NULL) {
        free((void *)destination->mime_type);
        free((void *)destination->description);
        free(destination->data);
        destination->mime_type = NULL;
        destination->description = NULL;
        destination->data = NULL;
        destination->data_length = 0;
        return -1;
    }

    memcpy(destination->data, picture->data, picture->data_length);
    destination->data_length = (size_t)picture->data_length;
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

int flac_read_pictures(const char *file_path, FlacPictureResult *out_result, char **error_message) {
    if (out_result == NULL || file_path == NULL) {
        set_error(error_message, "Invalid arguments for flac_read_pictures.");
        return -1;
    }

    out_result->pictures = NULL;
    out_result->count = 0;

    FLAC__Metadata_Chain *chain = FLAC__metadata_chain_new();
    if (chain == NULL) {
        set_error(error_message, "Failed to allocate FLAC metadata chain.");
        return -1;
    }

    if (!FLAC__metadata_chain_read(chain, file_path)) {
        set_error(error_message, "FLAC__metadata_chain_read failed for file.");
        FLAC__metadata_chain_delete(chain);
        return -1;
    }

    FLAC__Metadata_Iterator *iterator = FLAC__metadata_iterator_new();
    if (iterator == NULL) {
        set_error(error_message, "Failed to allocate FLAC metadata iterator.");
        FLAC__metadata_chain_delete(chain);
        return -1;
    }

    FLAC__metadata_iterator_init(iterator, chain);
    do {
        FLAC__StreamMetadata *metadata = FLAC__metadata_iterator_get_block(iterator);
        if (metadata == NULL || metadata->type != FLAC__METADATA_TYPE_PICTURE) {
            continue;
        }

        if (append_picture(out_result, &metadata->data.picture) != 0) {
            set_error(error_message, "Out of memory while collecting FLAC pictures.");
            FLAC__metadata_iterator_delete(iterator);
            FLAC__metadata_chain_delete(chain);
            return -1;
        }
    } while (FLAC__metadata_iterator_next(iterator));

    FLAC__metadata_iterator_delete(iterator);
    FLAC__metadata_chain_delete(chain);
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

void flac_free_picture_result(FlacPictureResult *result) {
    if (result == NULL) {
        return;
    }

    if (result->pictures != NULL) {
        for (size_t i = 0; i < result->count; i++) {
            free((void *)result->pictures[i].mime_type);
            free((void *)result->pictures[i].description);
            free(result->pictures[i].data);
        }
        free(result->pictures);
    }

    result->pictures = NULL;
    result->count = 0;
}

void flac_free_c_string(char *value) {
    free(value);
}
