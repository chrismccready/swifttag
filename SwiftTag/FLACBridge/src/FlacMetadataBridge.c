#include "../include/FlacMetadataBridge.h"
#include <FLAC/callback.h>
#include <FLAC/metadata.h>

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
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
    destination->width = picture->width;
    destination->height = picture->height;
    destination->depth = picture->depth;
    destination->colors = picture->colors;
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

static int copy_streaminfo_md5_hex(const FLAC__byte md5sum[16], char **out_fingerprint) {
    static const char hex_digits[] = "0123456789abcdef";

    if (md5sum == NULL || out_fingerprint == NULL) {
        return -1;
    }

    char *fingerprint = (char *)malloc(33);
    if (fingerprint == NULL) {
        return -1;
    }

    for (size_t index = 0; index < 16; index++) {
        unsigned char byte = md5sum[index];
        fingerprint[index * 2] = hex_digits[byte >> 4];
        fingerprint[index * 2 + 1] = hex_digits[byte & 0x0F];
    }
    fingerprint[32] = '\0';
    *out_fingerprint = fingerprint;
    return 0;
}

static void set_chain_error(char **error_message, FLAC__Metadata_Chain *chain, const char *fallback_message) {
    if (chain != NULL) {
        FLAC__Metadata_ChainStatus status = FLAC__metadata_chain_status(chain);
        const char *status_message = FLAC__Metadata_ChainStatusString[status];
        if (status_message != NULL) {
            set_error(error_message, status_message);
            return;
        }
    }

    set_error(error_message, fallback_message);
}

static int strings_equal_case_insensitive(const char *lhs, const char *rhs) {
    if (lhs == NULL || rhs == NULL) {
        return 0;
    }

    while (*lhs != '\0' && *rhs != '\0') {
        unsigned char lhs_char = (unsigned char)*lhs;
        unsigned char rhs_char = (unsigned char)*rhs;
        if (lhs_char >= 'A' && lhs_char <= 'Z') {
            lhs_char = (unsigned char)(lhs_char - 'A' + 'a');
        }
        if (rhs_char >= 'A' && rhs_char <= 'Z') {
            rhs_char = (unsigned char)(rhs_char - 'A' + 'a');
        }

        if (lhs_char != rhs_char) {
            return 0;
        }

        lhs++;
        rhs++;
    }

    return *lhs == '\0' && *rhs == '\0';
}

static int ensure_single_png_icon_picture(const FlacWritePicture *pictures, size_t picture_count, char **error_message) {
    size_t type1_count = 0;

    for (size_t i = 0; i < picture_count; i++) {
        const FlacWritePicture *picture = &pictures[i];
        if (picture->type != 1) {
            continue;
        }

        type1_count += 1;
        if (type1_count > 1) {
            set_error(error_message, "FLAC picture type 1 allows only a single PNG icon per file.");
            return -1;
        }

        if (!strings_equal_case_insensitive(picture->mime_type, "image/png")) {
            set_error(error_message, "FLAC picture type 1 must use MIME type image/png.");
            return -1;
        }
    }

    return 0;
}

static int flac_io_seek(FLAC__IOHandle handle, FLAC__int64 offset, int whence) {
    return fseeko((FILE *)handle, (off_t)offset, whence);
}

static size_t flac_io_read(void *ptr, size_t size, size_t nmemb, FLAC__IOHandle handle) {
    return fread(ptr, size, nmemb, (FILE *)handle);
}

static size_t flac_io_write(const void *ptr, size_t size, size_t nmemb, FLAC__IOHandle handle) {
    return fwrite(ptr, size, nmemb, (FILE *)handle);
}

static FLAC__int64 flac_io_tell(FLAC__IOHandle handle) {
    off_t offset = ftello((FILE *)handle);
    return offset < 0 ? -1 : (FLAC__int64)offset;
}

static int flac_io_eof(FLAC__IOHandle handle) {
    return feof((FILE *)handle);
}

static int flac_io_close(FLAC__IOHandle handle) {
    return fclose((FILE *)handle);
}

static const FLAC__IOCallbacks flac_stdio_callbacks = {
    flac_io_read,
    flac_io_write,
    flac_io_seek,
    flac_io_tell,
    flac_io_eof,
    flac_io_close
};

static FLAC__StreamMetadata *find_vorbis_comment_block(FLAC__Metadata_Chain *chain) {
    FLAC__Metadata_Iterator *iterator = FLAC__metadata_iterator_new();
    if (iterator == NULL) {
        return NULL;
    }

    FLAC__metadata_iterator_init(iterator, chain);
    do {
        FLAC__StreamMetadata *metadata = FLAC__metadata_iterator_get_block(iterator);
        if (metadata != NULL && metadata->type == FLAC__METADATA_TYPE_VORBIS_COMMENT) {
            FLAC__metadata_iterator_delete(iterator);
            return metadata;
        }
    } while (FLAC__metadata_iterator_next(iterator));

    FLAC__metadata_iterator_delete(iterator);
    return NULL;
}

static int ensure_vorbis_comment_block(
    FLAC__Metadata_Chain *chain,
    FLAC__StreamMetadata **out_block,
    char **error_message
) {
    FLAC__StreamMetadata *block = find_vorbis_comment_block(chain);
    if (block != NULL) {
        *out_block = block;
        return 0;
    }

    block = FLAC__metadata_object_new(FLAC__METADATA_TYPE_VORBIS_COMMENT);
    if (block == NULL) {
        set_error(error_message, "Failed to allocate VORBIS_COMMENT block.");
        return -1;
    }

    FLAC__Metadata_Iterator *iterator = FLAC__metadata_iterator_new();
    if (iterator == NULL) {
        FLAC__metadata_object_delete(block);
        set_error(error_message, "Failed to allocate FLAC metadata iterator.");
        return -1;
    }

    FLAC__metadata_iterator_init(iterator, chain);
    if (!FLAC__metadata_iterator_insert_block_after(iterator, block)) {
        FLAC__metadata_iterator_delete(iterator);
        FLAC__metadata_object_delete(block);
        set_chain_error(error_message, chain, "Failed to insert VORBIS_COMMENT block.");
        return -1;
    }

    FLAC__metadata_iterator_delete(iterator);
    *out_block = block;
    return 0;
}

static int rewrite_vorbis_comments(
    FLAC__Metadata_Chain *chain,
    const FlacWriteTagPair *tag_pairs,
    size_t tag_count,
    char **error_message
) {
    FLAC__StreamMetadata *block = NULL;
    if (ensure_vorbis_comment_block(chain, &block, error_message) != 0) {
        return -1;
    }

    if (!FLAC__metadata_object_vorbiscomment_resize_comments(block, 0)) {
        set_error(error_message, "Failed to clear existing Vorbis comments.");
        return -1;
    }

    for (size_t i = 0; i < tag_count; i++) {
        const FlacWriteTagPair *pair = &tag_pairs[i];
        if (pair->key == NULL || pair->value == NULL || pair->value[0] == '\0') {
            continue;
        }

        FLAC__StreamMetadata_VorbisComment_Entry entry;
        memset(&entry, 0, sizeof(entry));
        if (!FLAC__metadata_object_vorbiscomment_entry_from_name_value_pair(&entry, pair->key, pair->value)) {
            set_error(error_message, "Failed to create Vorbis comment entry.");
            return -1;
        }

        if (!FLAC__metadata_object_vorbiscomment_append_comment(block, entry, /*copy=*/false)) {
            free(entry.entry);
            set_error(error_message, "Failed to append Vorbis comment entry.");
            return -1;
        }
    }

    return 0;
}

static int delete_all_picture_blocks(FLAC__Metadata_Chain *chain, char **error_message) {
    while (1) {
        int found_picture = 0;
        FLAC__Metadata_Iterator *iterator = FLAC__metadata_iterator_new();
        if (iterator == NULL) {
            set_error(error_message, "Failed to allocate FLAC metadata iterator.");
            return -1;
        }

        FLAC__metadata_iterator_init(iterator, chain);
        do {
            FLAC__StreamMetadata *metadata = FLAC__metadata_iterator_get_block(iterator);
            if (metadata == NULL || metadata->type != FLAC__METADATA_TYPE_PICTURE) {
                continue;
            }

            found_picture = 1;
            if (!FLAC__metadata_iterator_delete_block(iterator, /*replace_with_padding=*/false)) {
                FLAC__metadata_iterator_delete(iterator);
                set_chain_error(error_message, chain, "Failed to delete existing PICTURE block.");
                return -1;
            }

            break;
        } while (FLAC__metadata_iterator_next(iterator));

        FLAC__metadata_iterator_delete(iterator);

        if (!found_picture) {
            return 0;
        }
    }
}

static int append_picture_block(
    FLAC__Metadata_Chain *chain,
    const FlacWritePicture *picture,
    char **error_message
) {
    if (picture == NULL || picture->mime_type == NULL || picture->description == NULL) {
        set_error(error_message, "Invalid FLAC picture payload.");
        return -1;
    }

    if (picture->data_length > UINT32_MAX) {
        set_error(error_message, "FLAC picture payload is too large.");
        return -1;
    }

    FLAC__StreamMetadata *block = FLAC__metadata_object_new(FLAC__METADATA_TYPE_PICTURE);
    if (block == NULL) {
        set_error(error_message, "Failed to allocate PICTURE block.");
        return -1;
    }

    block->data.picture.type = (FLAC__StreamMetadata_Picture_Type)picture->type;
    block->data.picture.width = picture->width;
    block->data.picture.height = picture->height;
    block->data.picture.depth = picture->depth;
    block->data.picture.colors = picture->colors;

    if (!FLAC__metadata_object_picture_set_mime_type(block, (char *)picture->mime_type, /*copy=*/true)) {
        FLAC__metadata_object_delete(block);
        set_error(error_message, "Failed to set FLAC picture MIME type.");
        return -1;
    }

    if (!FLAC__metadata_object_picture_set_description(block, (FLAC__byte *)picture->description, /*copy=*/true)) {
        FLAC__metadata_object_delete(block);
        set_error(error_message, "Failed to set FLAC picture description.");
        return -1;
    }

    if (!FLAC__metadata_object_picture_set_data(block, (FLAC__byte *)picture->data, (FLAC__uint32)picture->data_length, /*copy=*/true)) {
        FLAC__metadata_object_delete(block);
        set_error(error_message, "Failed to set FLAC picture data.");
        return -1;
    }

    const char *violation = NULL;
    if (!FLAC__metadata_object_picture_is_legal(block, &violation)) {
        FLAC__metadata_object_delete(block);
        set_error(error_message, violation != NULL ? violation : "Illegal FLAC picture block.");
        return -1;
    }

    FLAC__Metadata_Iterator *iterator = FLAC__metadata_iterator_new();
    if (iterator == NULL) {
        FLAC__metadata_object_delete(block);
        set_error(error_message, "Failed to allocate FLAC metadata iterator.");
        return -1;
    }

    FLAC__metadata_iterator_init(iterator, chain);
    while (FLAC__metadata_iterator_next(iterator)) {
    }

    if (!FLAC__metadata_iterator_insert_block_after(iterator, block)) {
        FLAC__metadata_iterator_delete(iterator);
        FLAC__metadata_object_delete(block);
        set_chain_error(error_message, chain, "Failed to append PICTURE block.");
        return -1;
    }

    FLAC__metadata_iterator_delete(iterator);
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

int flac_read_fingerprint(const char *file_path, char **out_fingerprint, char **error_message) {
    if (out_fingerprint == NULL || file_path == NULL) {
        set_error(error_message, "Invalid arguments for flac_read_fingerprint.");
        return -1;
    }

    *out_fingerprint = NULL;

    FLAC__StreamMetadata streaminfo;
    memset(&streaminfo, 0, sizeof(streaminfo));

    if (!FLAC__metadata_get_streaminfo(file_path, &streaminfo)) {
        set_error(error_message, "FLAC__metadata_get_streaminfo failed for file.");
        return -1;
    }

    if (streaminfo.type != FLAC__METADATA_TYPE_STREAMINFO) {
        set_error(error_message, "FLAC stream info metadata block was unavailable.");
        return -1;
    }

    if (copy_streaminfo_md5_hex(streaminfo.data.stream_info.md5sum, out_fingerprint) != 0) {
        set_error(error_message, "Out of memory while collecting FLAC fingerprint.");
        return -1;
    }

    return 0;
}

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
) {
    if (file_path == NULL) {
        set_error(error_message, "Invalid file path for flac_write_metadata.");
        return -1;
    }

    if (used_temp_file != NULL) {
        *used_temp_file = 0;
    }

    if (!write_tags && !write_pictures) {
        return 0;
    }

    if (write_pictures && pictures != NULL && ensure_single_png_icon_picture(pictures, picture_count, error_message) != 0) {
        return -1;
    }

    FLAC__Metadata_Chain *chain = FLAC__metadata_chain_new();
    if (chain == NULL) {
        set_error(error_message, "Failed to allocate FLAC metadata chain.");
        return -1;
    }

    FILE *source_file = fopen(file_path, "r+b");
    if (source_file == NULL) {
        set_error(error_message, "Failed to open FLAC file for update.");
        FLAC__metadata_chain_delete(chain);
        return -1;
    }

    if (!FLAC__metadata_chain_read_with_callbacks(chain, source_file, flac_stdio_callbacks)) {
        set_chain_error(error_message, chain, "FLAC__metadata_chain_read failed for file.");
        fclose(source_file);
        FLAC__metadata_chain_delete(chain);
        return -1;
    }

    if (write_tags && rewrite_vorbis_comments(chain, tag_pairs, tag_count, error_message) != 0) {
        fclose(source_file);
        FLAC__metadata_chain_delete(chain);
        return -1;
    }

    if (write_pictures) {
        if (delete_all_picture_blocks(chain, error_message) != 0) {
            fclose(source_file);
            FLAC__metadata_chain_delete(chain);
            return -1;
        }

        for (size_t i = 0; i < picture_count; i++) {
            if (append_picture_block(chain, &pictures[i], error_message) != 0) {
                fclose(source_file);
                FLAC__metadata_chain_delete(chain);
                return -1;
            }
        }
    }

    const FLAC__bool use_padding = true;
    FLAC__bool needs_tempfile = FLAC__metadata_chain_check_if_tempfile_needed(chain, use_padding);
    FLAC__bool write_ok = false;

    if (!needs_tempfile) {
        write_ok = FLAC__metadata_chain_write_with_callbacks(chain, use_padding, source_file, flac_stdio_callbacks);
    } else {
        if (temp_file_path == NULL || temp_file_path[0] == '\0') {
            fclose(source_file);
            FLAC__metadata_chain_delete(chain);
            set_error(error_message, "A temporary FLAC rewrite path is required but was not provided.");
            return -1;
        }

        FILE *temp_file = fopen(temp_file_path, "w+b");
        if (temp_file == NULL) {
            fclose(source_file);
            FLAC__metadata_chain_delete(chain);
            set_error(error_message, "Failed to open temporary FLAC rewrite file.");
            return -1;
        }

        write_ok = FLAC__metadata_chain_write_with_callbacks_and_tempfile(
            chain,
            use_padding,
            source_file,
            flac_stdio_callbacks,
            temp_file,
            flac_stdio_callbacks
        );

        if (fclose(temp_file) != 0 && write_ok) {
            write_ok = false;
            set_error(error_message, "Failed to close temporary FLAC rewrite file.");
        }

        if (write_ok && used_temp_file != NULL) {
            *used_temp_file = 1;
        }
    }

    if (!write_ok) {
        set_chain_error(error_message, chain, "FLAC__metadata_chain_write failed.");
        fclose(source_file);
        FLAC__metadata_chain_delete(chain);
        return -1;
    }

    fclose(source_file);
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
