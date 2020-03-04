#pragma once

#include <stdio.h>
#include <stdint.h>
#include <erl_nif.h>
#include <unifex/unifex.h>
#include <unifex/payload.h>
#include "../cnode_payload_handler.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Declaration of native functions for module Elixir.Unifex.CNodePayloadHandler.
 * The implementation have to be provided by the user.
 */

UNIFEX_TERM alloc_payload(UnifexEnv* env, int size);
UNIFEX_TERM realloc_payload(UnifexEnv* env, UnifexPayload * old_payload, int dest_size);

/*
 * Functions that manage lib and state lifecycle
 * Functions with 'unifex_' prefix are generated automatically,
 * the user have to implement rest of them.
 * Available only and only if in ../cnode_payload_handler.h
 * exisis definition of UnifexNigState
 */

/*
 * Callbacks for nif lifecycle hooks.
 * Have to be implemented by user.
 */

/*
 * Functions that create the defined output from Nif.
 * They are automatically generated and don't need to be implemented.
 */

UNIFEX_TERM alloc_payload_result_ok(UnifexEnv* env, const UnifexPayload * payload);
UNIFEX_TERM realloc_payload_result_ok(UnifexEnv* env, const UnifexPayload * new_payload);

/*
 * Functions that send the defined messages from Nif.
 * They are automatically generated and don't need to be implemented.
 */

#ifdef __cplusplus
}
#endif
