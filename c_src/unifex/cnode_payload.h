#pragma once

#include "cnode_utils.h"
#include <ei_connect.h>
#include <erl_interface.h>
#include <shmex/lib_cnode.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum { UNIFEX_PAYLOAD_BINARY, UNIFEX_PAYLOAD_SHM } UnifexPayloadType;

typedef struct Binary {
  unsigned char *data;
  unsigned int lenght;
} Binary;

typedef struct _UnifexPayload {
  unsigned char *data;
  unsigned int size;
  union {
    Shmex shm;
    Binary binary;
  } payload_struct;
  UnifexPayloadType type;
  int owned;
  erlang_pid *gen_server_pid = NULL;
} UnifexPayload;

typedef struct _UnifexPayload UnifexPayload;

UnifexPayload *unifex_payload_alloc(UnifexEnv *env, UnifexPayloadType type,
                                    unsigned int size);
int unifex_payload_from_term(UnifexEnv *env, UNIFEX_TERM term,
                             UnifexPayload *payload);
UNIFEX_TERM unifex_payload_to_term(UnifexEnv *env, UnifexPayload *payload);
int unifex_payload_realloc(UnifexPayload *payload, unsigned int size);
void unifex_payload_release(UnifexPayload *payload);
void unifex_payload_release_ptr(UnifexPayload **payload);

// extern ErlNifResourceType *UNIFEX_PAYLOAD_GUARD_RESOURCE_TYPE;
// void unifex_payload_guard_destructor(UnifexEnv *env, void *resource);

#ifdef __cplusplus
}
#endif
