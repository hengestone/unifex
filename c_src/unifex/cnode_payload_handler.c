#include "cnode_payload_handler.h"
#include <unifex/payload.h>

// spec alloc_payload(size :: int) :: {:ok :: label, payload}
UNIFEX_TERM alloc_payload(UnifexEnv *env, int size) {
  UnifexPayload *result = unifex_payload_alloc(env, UNIFEX_PAYLOAD_SHM, size);
  unifex_payload_release(result);
  return alloc_payload_result_ok(env, result);
}

// spec realloc_payload(old_payload :: payload, dest_size :: int)
// :: {:ok :: label, new_payload :: payload}
UNIFEX_TERM realloc_payload(UnifexEnv *env, UnifexPayload *payload,
                            int dest_size) {
  unifex_payload_realloc(payload, dest_size);
  return realloc_payload_ok(env, payload);
}
