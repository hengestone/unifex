#include "cnode_payload_handler.h"

UNIFEX_TERM alloc_payload_result_ok(UnifexEnv* env, const UnifexPayload * payload) {
  return ({
        const ERL_NIF_TERM terms[] = {
          enif_make_atom(env, "ok"),
          unifex_payload_to_term(env, payload)
        };
        enif_make_tuple_from_array(env, terms, 2);
      });
}

UNIFEX_TERM realloc_payload_result_ok(UnifexEnv* env, const UnifexPayload * new_payload) {
  return ({
        const ERL_NIF_TERM terms[] = {
          enif_make_atom(env, "ok"),
          unifex_payload_to_term(env, new_payload)
        };
        enif_make_tuple_from_array(env, terms, 2);
      });
}

static int unifex_load_nif(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  UNIFEX_UNUSED(load_info);
  UNIFEX_UNUSED(priv_data);

  ErlNifResourceFlags flags = (ErlNifResourceFlags) (ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER);

  UNIFEX_PAYLOAD_GUARD_RESOURCE_TYPE =
    enif_open_resource_type(env, NULL, "UnifexPayloadGuard", (ErlNifResourceDtor*) unifex_payload_guard_destructor, flags, NULL);

  return 0;
}

static ERL_NIF_TERM export_alloc_payload(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
  UNIFEX_UNUSED(argc);
  ERL_NIF_TERM result;

  UnifexEnv *unifex_env = env;
  int size;

  if(!enif_get_int(env, argv[0], &size)) {
    result = unifex_raise_args_error(env, "size", "enif_get_int(env, argv[0], &size)");
    goto exit_export_alloc_payload;
  }

  result = alloc_payload(unifex_env, size);
  goto exit_export_alloc_payload;
exit_export_alloc_payload:

  return result;
}

static ERL_NIF_TERM export_realloc_payload(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
  UNIFEX_UNUSED(argc);
  ERL_NIF_TERM result;

  UnifexEnv *unifex_env = env;
  UnifexPayload * old_payload;
  int dest_size;

  old_payload = (UnifexPayload *) enif_alloc(sizeof (UnifexPayload));

  if(!unifex_payload_from_term(env, argv[0], old_payload)) {
    result = unifex_raise_args_error(env, "old_payload", "unifex_payload_from_term(env, argv[0], old_payload)");
    goto exit_export_realloc_payload;
  }
  if(!enif_get_int(env, argv[1], &dest_size)) {
    result = unifex_raise_args_error(env, "dest_size", "enif_get_int(env, argv[1], &dest_size)");
    goto exit_export_realloc_payload;
  }

  result = realloc_payload(unifex_env, old_payload, dest_size);
  goto exit_export_realloc_payload;
exit_export_realloc_payload:
  unifex_payload_release_ptr(&old_payload);
  return result;
}

static ErlNifFunc nif_funcs[] =
{
  {"unifex_alloc_payload", 1, export_alloc_payload, 0},
  {"unifex_realloc_payload", 2, export_realloc_payload, 0}
};

ERL_NIF_INIT(Elixir.Unifex.CNodePayloadHandler.Nif, nif_funcs, unifex_load_nif, NULL, NULL, NULL)
