#include "cnode_payload.h"

ErlNifResourceType *UNIFEX_PAYLOAD_GUARD_RESOURCE_TYPE;

UnifexPayload *unifex_payload_alloc(UnifexEnv *env, UnifexPayloadType type,
                                    unsigned int size) {
  UnifexPayload *payload = (UnifexPayload *)malloc(sizeof(UnifexPayload));
  payload->size = size;
  payload->type = type;
  payload->owned = 1;

  if (type == UNIFEX_PAYLOAD_SHM) {
    alloc_shm_payload_data(env, payload, size);
  } else {
    alloc_binary_payload_data(payload, size);
  }

  return payload
}

static int alloc_shm_payload_data(UnifexEnv *env,
                                  UnifexPayload *payload unsigned int size) {
  Shmex shmex;

  ei_x_buff out_buff, in_buff;
  ei_x_new(&out_buff);
  
  alloc_shm_request_encoding(&out_buff, size);

  int send_res =
      ei_send(env->ei_fd, env->gen_server_pid, &out_buff, &out_buff.index);
  // sending to genserver
  // receiveing
  int index = 0;
  int res = shmex_deserialize((const char *)in_buff->buff, index, &shmex);
  // if ...
  ShmexLibResult shmex_res = shmex_open_and_mmap(payload);
  // if ...

  payload->payload_struct.shm = shmex;
  payload->data = (unsigned char *)shmex.mapped_memory;
  payload->gen_server_pid = env->gen_server_pid;

  ei_x_free(out_buff);
}

static void alloc_binary_payload_data(UnifexPayload *payload,
                                      unsigned int size) {
  payload->data = (unsigned char *)malloc(size * sizeof(unsigned char));
  payload->binary = {.data = payload->data, .length = size};
  payload->gen_server_pid = NULL;
}

static int alloc_shm_request_encoding(ei_x_buff *buff, int size) {
  return ei_x_encode_tuple_header(buff, 2) ||
         ei_x_encode_atom(buff, "alloc_shm") ||
         ei_x_encode_long(buff, (long)size);
}

static int shm_realloc_request_encoding(ei_x_buff *buff, Shmex *shmex,
                                        int dest_size) {
  return ei_x_encode_tuple_header(buff, 3) || ei_x_encode_atom("realloc_shm") ||
         shmex_serialize(buff, shmex) ||
         ei_x_encode_long(buff, (long)dest_size);
}

static int shm_release_request_encoding(ei_x_buff *buff, Shmex *shmex) {
  return ei_x_encode_tuple_header(buff, 2) || ei_x_encode_atom("release_shm") ||
         shmex_serialize(buff, shmex);
}

int unifex_payload_from_term(UnifexEnv *env, UNIFEX_TERM term,
                             UnifexPayload *payload) {
  int type, size, index = 0;
  ei_get_type(term->buff, &index, &type, &size);

  unsigned char *data = (unsigned char *)malloc(size * sizeof(unsigned char));
  long length;
  int res = ei_decode_binary(term->buff, &index, (void *)data, &length);

  if (res == 0) { // term is binary
    payload->type = UNIFEX_PAYLOAD_BINARY;
    payload->data = data;
    payload->size = length;
    payload->owned = 1;
    payload->payload_struct.binary = {.data = data, .length = length};

  } else {
    Shmex shmex;
    shmex_deserialize(term->budd, &index, &shmex);
    shmex_open_and_mmap(payload);

    payload->type = UNIFEX_PAYLOAD_SHM;
    payload->data = (unsigned char *)shmex.mapped_memory;
    payload->size = shmex.size;
    payload->owned = 1;
    payload->payload_struct.shm = shmex;
  }
}

UNIFEX_TERM unifex_payload_to_term(UnifexEnv *env, UnifexPayload *payload) {
  return payload->type == UNIFEX_PAYLOAD_SHM ? shm_payload_to_term(env, payload)
                                             : binary_payload_to_term(payload);
}

static UNIFEX_TERM shm_payload_to_term(UnifexEnv *env, UnifexPayload *payload) {
  ;
  ;
}

static UNIFEX_TERM binary_payload_to_term(UnifexPayload *payload) {
  ;
  ;
}

int unifex_payload_realloc(UnifexPayload *payload, unsigned int size) {
  return payload->type == UNIFEX_PAYLOAD_SHM
             ? shm_payload_realloc(payload, size)
             : binary_payload_realloc(payload, size);
}

static int shm_payload_realloc(UnifexPayload *payload, unsigned int size) {
  ;
  ;
}

static int binary_payload_realloc(UnifexPayload *payload, unsigned int size) {
  ;
  ;
}

void unifex_payload_release(UnifexPayload *payload) {
  // switch (payload->type) {
  // case UNIFEX_PAYLOAD_BINARY:
  //   if (payload->owned) {
  //     enif_release_binary(&payload->payload_struct.binary);
  //   }
  //   break;
  // case UNIFEX_PAYLOAD_SHM:
  //   release_shm_payload(&payload->payload_struct.shm);
  //   break;
  // }
}

void unifex_payload_release_ptr(UnifexPayload **payload) {
  // if (*payload == NULL) {
  //   return;
  // }

  // unifex_payload_release(*payload);
  // free(*payload);
  // *payload = NULL;
}

static UnifexPayload *alloc_shared_payload(cnode_context *ctx,
                                           unsigned int size) {
  // 1: send msg to genserver

  ei_x_buff out_buff;
  ei_x_new_with_version(&out_buff);
  shm_creation_request_encoding(&out_buff);
  sending_and_freeing(ctx, &out_buff);

  // 3: receive msg from creator
  //    msg has shm ref

  ei_x_buff in_buff;
  ei_x_new(&in_buff);

  UnifexPayload *result = NULL;

  while (true) {
    erlang_msg emsg;
    int rec_res = ei_xreceive_msg_tmo(ei_fd, &emsg, &in_buf, 100);
    if (rec_res && erl_errno == ETIMEDOUT) {
      fprintf(stderr, "dsffsddsf\n");
      // todo: zrob zeby to nie bylo takie dziadowe xd
    } else if (!rec_res && emsg.msgtype == ERL_REG_SEND) {
      int i = 0;
      result = unpack_shared_payload(&in_buff, i);
      break;
    }
  }

  return result;
}

static void release_shm_payload(Shmex *shmex) {
  // 4a: send important message to payload creator
  ei_x_buff out_buff;
  ei_x_new(&out_buff);
  shm_release_request_encoding(&out_buff, shmex);
  //   ei_send payload->creator_pid, payload->socket(wtf), out_buff,
  ei_x_free(&out_buff);
}

static void release_binary_payload(UnifexPayload *payload) {}

int pack_shared_payload_into_buff(ei_x_buff *buff, UnifexPayload *payload) {
  // 4b: packing to ei_x_buff
  // use int shmex_serialize(ei_x_buff *buf, Shmex *payload);

  Shmex *shm = payload->payload_struct.binary;
  return shmex_serialize(buff, shm);
}

// UnifexPayload *unpack_shared_payload(ei_buff *buff, int *index) {
//   Shmex shm;
//   shmex_deserialize((const char *)buff, index, &shm);

//   // shm to unifex_payload
//   // return it
// }
