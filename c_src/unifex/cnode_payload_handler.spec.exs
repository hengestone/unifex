module Unifex.CNodePayloadHandler

spec alloc_payload(size :: int) :: {:ok :: label, payload}
spec realloc_payload(old_payload :: payload, dest_size :: int) :: {:ok :: label, new_payload :: payload}
