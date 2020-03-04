#pragma once

#include "cnode_utils.h"
#include <shmex/lib_cnode.h>

typedef struct UnifexPayloadData {
  erlang_pid *creator_pid;
  int ei_fd;
} UnifexPayloadData;

typedef struct _UnifexPayload {
  unsigned char *data;
  unsigned int size;
  union {
    Shmex shm;
    void *binary;
  } payload_struct;
  UnifexPayloadType type;
  int owned;
  UnifexPayloadData data;
} UnifexPayload;

extern ErlNifResourceType *UNIFEX_PAYLOAD_GUARD_RESOURCE_TYPE;
