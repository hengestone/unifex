#include "cnode_payload.h"

static int shm_alloc_request_encoding(ei_x_buff *buff, int size) {
  return ei_x_encode_tuple_header(buff, 2) ||
         ei_x_encode_atom(buff, "alloc_shm") ||
         ei_x_encode_long(buff, (long)size);
}

static int shm_realloc_request_encoding(ei_x_buff *buff, Shmex *shmex,
                                        int dest_size) {
  return ei_x_encode_tuple_header(buff, 3) ||
         ei_x_encode_atom(buff, "realloc_shm") ||
         shmex_serialize(buff, shmex) ||
         ei_x_encode_long(buff, (long)dest_size);
}

static int shm_release_request_encoding(ei_x_buff *buff, Shmex *shmex) {
  return ei_x_encode_tuple_header(buff, 2) ||
         ei_x_encode_atom(buff, "release_shm") || shmex_serialize(buff, shmex);
}

static void release_binary_payload(UnifexPayload *payload) {}

static int do_receive(int ei_fd, erlang_msg *msg, ei_x_buff *in_buff) {
  int res = 0;

  switch (ei_xreceive_msg_tmo(ei_fd, msg, in_buff, 1000)) {
  case ERL_TICK:
    break;
  case ERL_ERROR:
    res = erl_errno != ETIMEDOUT;
    break;
  default:
    res = 0;
    break;
  }

  return res;
}

static int alloc_shm_payload_data(UnifexEnv *env, UnifexPayload *payload,
                                  unsigned int size) {
  Shmex shmex;

  ei_x_buff out_buff, in_buff;
  ei_x_new(&out_buff);
  ei_x_new(&in_buff);

  shm_alloc_request_encoding(&out_buff, size);

  int send_res =
      ei_send(env->ei_fd, env->gen_server_pid, out_buff.buff, out_buff.index);

  erlang_msg rsp_msg;
  int rec_res = do_receive(env->ei_fd, &rsp_msg, &in_buff);

  int res =
      shmex_deserialize((const char *)in_buff.buff, &in_buff.index, &shmex);
  // if ...
  ShmexLibResult shmex_res = shmex_open_and_mmap(&shmex);
  // if ...

  payload->payload_struct.shm = shmex;
  payload->data = (unsigned char *)shmex.mapped_memory;
  payload->gen_server_pid = env->gen_server_pid;
  payload->size = size;
  payload->ei_fd = env->ei_fd;
  payload->type = UNIFEX_PAYLOAD_SHM;

  ei_x_free(&out_buff);
  ei_x_free(&in_buff);
}

static void alloc_binary_payload_data(UnifexPayload *payload,
                                      unsigned int size) {
  unsigned char *data = (unsigned char *)malloc(size * sizeof(unsigned char));

  payload->payload_struct.binary = (Binary){.data = data, .length = size};
  payload->data = data;
  payload->gen_server_pid = NULL;
  payload->size = size;
  payload->ei_fd = -1;
  payload->type = UNIFEX_PAYLOAD_BINARY;
}

UnifexPayload *unifex_payload_alloc(UnifexEnv *env, UnifexPayloadType type,
                                    unsigned int size) {
  UnifexPayload *payload = (UnifexPayload *)malloc(sizeof(UnifexPayload));
  payload->owned = 1;

  if (type == UNIFEX_PAYLOAD_SHM) {
    alloc_shm_payload_data(env, payload, size);
  } else {
    alloc_binary_payload_data(payload, size);
  }

  return payload;
}

static UNIFEX_TERM shm_payload_to_term(UnifexEnv *env, UnifexPayload *payload) {
  ei_x_buff *buff = (ei_x_buff *)malloc(sizeof(ei_x_buff));
  ei_x_new(buff);

  int res =
      shmex_deserialize(buff->buff, &buff->index, &payload->payload_struct.shm);

  return buff;
}

static UNIFEX_TERM binary_payload_to_term(UnifexPayload *payload) {
  ei_x_buff *buff = (ei_x_buff *)malloc(sizeof(ei_x_buff));
  ei_x_new(buff);

  Binary *binary = &payload->payload_struct.binary;
  int res = ei_x_encode_binary(buff, binary->data, binary->length);

  return buff;
}

static int shm_payload_realloc(UnifexPayload *payload, unsigned int size) {
  Shmex *payload_shm_ptr = &payload->payload_struct.shm;

  ei_x_buff out_buff, in_buff;
  ei_x_new(&out_buff);
  ei_x_new(&in_buff);

  shm_realloc_request_encoding(&out_buff, payload_shm_ptr, size);

  int send_res = ei_send(payload->ei_fd, payload->gen_server_pid, out_buff.buff,
                         out_buff.index);

  erlang_msg rsp_msg;
  int rec_res = do_receive(payload->ei_fd, &rsp_msg, &in_buff);

  int res = shmex_deserialize((const char *)in_buff.buff, &in_buff.index,
                              payload_shm_ptr);
  // if ...
  // todo: czy trzeba tutaj robic jakies zwalnianie pamieci???
  ShmexLibResult shmex_res = shmex_open_and_mmap(payload_shm_ptr);
  // if ...

  ei_x_free(&out_buff);
  ei_x_free(&in_buff);
}

static int binary_payload_realloc(UnifexPayload *payload, unsigned int size) {
  void *old_ptr = (void *)payload->payload_struct.binary.data;
  void *new_ptr = realloc(old_ptr, size);

  payload->payload_struct.binary.data = (unsigned char *)new_ptr;
  payload->payload_struct.binary.length = size;
  payload->size = size;
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
    payload->payload_struct.binary = (Binary){.data = data, .length = length};
    payload->gen_server_pid = NULL;
    payload->ei_fd = -1;

  } else {
    Shmex shmex;
    shmex_deserialize(term->buff, &index, &shmex);
    shmex_open_and_mmap(&shmex);

    payload->type = UNIFEX_PAYLOAD_SHM;
    payload->data = (unsigned char *)shmex.mapped_memory;
    payload->size = shmex.size;
    payload->owned = 1;
    payload->payload_struct.shm = shmex;
    payload->gen_server_pid = env->gen_server_pid;
    payload->ei_fd = env->ei_fd;
  }

  return 0;
}

UNIFEX_TERM unifex_payload_to_term(UnifexEnv *env, UnifexPayload *payload) {
  return (payload->type == UNIFEX_PAYLOAD_SHM)
             ? shm_payload_to_term(env, payload)
             : binary_payload_to_term(payload);
}

int unifex_payload_realloc(UnifexPayload *payload, unsigned int size) {
  return payload->type == UNIFEX_PAYLOAD_SHM
             ? shm_payload_realloc(payload, size)
             : binary_payload_realloc(payload, size);
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
// int pack_shared_payload_into_buff(ei_x_buff *buff, UnifexPayload *payload) {
//   // 4b: packing to ei_x_buff
//   // use int shmex_serialize(ei_x_buff *buf, Shmex *payload);

//   Shmex *shm = &payload->payload_struct.shm;
//   return shmex_serialize(buff, shm);
// }

// UnifexPayload *unpack_shared_payload(ei_buff *buff, int *index) {
//   Shmex shm;
//   shmex_deserialize((const char *)buff, index, &shm);

//   // shm to unifex_payload
//   // return it
// }

// static UnifexPayload *alloc_shared_payload(cnode_context *ctx,
//                                            unsigned int size) {
//   // 1: send msg to genserver

//   ei_x_buff out_buff;
//   ei_x_new_with_version(&out_buff);
//   shm_creation_request_encoding(&out_buff);
//   sending_and_freeing(ctx, &out_buff);

//   // 3: receive msg from creator
//   //    msg has shm ref

//   ei_x_buff in_buff;
//   ei_x_new(&in_buff);

//   UnifexPayload *result = NULL;

//   while (1) {
//     erlang_msg emsg;
//     int rec_res = ei_xreceive_msg_tmo(ctx->ei_fd, &emsg, &in_buff, 100);
//     if (rec_res && erl_errno == ETIMEDOUT) {
//       fprintf(stderr, "dsffsddsf\n");
//       // todo: zrob zeby to nie bylo takie dziadowe xd
//     } else if (!rec_res && emsg.msgtype == ERL_REG_SEND) {
//       int i = 0;
//       result = unpack_shared_payload(&in_buff, i);
//       break;
//     }
//   }

//   return result;
// }

// static void release_shm_payload(Shmex *shmex) {
//   // 4a: send important message to payload creator
//   ei_x_buff out_buff;
//   ei_x_new(&out_buff);
//   shm_release_request_encoding(&out_buff, shmex);
//   //   ei_send payload->creator_pid, payload->socket(wtf), out_buff,
//   ei_x_free(&out_buff);
// }