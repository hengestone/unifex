#include "cnode_payload.h"

ErlNifResourceType *UNIFEX_PAYLOAD_GUARD_RESOURCE_TYPE;

static int shm_creation_request_encoding(ei_x_buff *buff) {}
static int shm_release_request_encoding(ei_x_buff *buff) {}

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

static void release_shared_payload(UnifexPayload *payload) {
  // 4a: send important message to payload creator
  ei_x_buff out_buff;
  ei_x_new(&out_buff);
  shm_release_request_encoding(&out_buff);
  //   ei_send payload->creator_pid, payload->socket(wtf), out_buff,
  ei_x_free(&out_buff);
}

int pack_shared_payload_into_buff(ei_x_buff *buff, UnifexPayload *payload) {
  // 4b: packing to ei_x_buff
  // use int shmex_serialize(ei_x_buff *buf, Shmex *payload);

  Shmex *shm = payload->payload_struct.binary;
  return shmex_serialize(buff, shm);
}

UnifexPayload *unpack_shared_payload(ei_buff *buff, int *index) {
  Shmex shm;
  shmex_deserialize((const char *)buff, index, &shm);

  // shm to unifex_payload
  // return it
}
