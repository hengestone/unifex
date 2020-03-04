defmodule Unifex.BundlexProject do
  use Bundlex.Project

  def project do
    [
      libs: libs(),
      nifs: nifs()
    ]
  end

  defp libs do
    [
      unifex: [
        deps: [shmex: :lib_nif],
        sources: ["unifex.c", "payload.c"]
      ],
      cnode_utils: [
        sources: ["cnode_utils.c"]
      ]
    ]
  end

  defp nifs do
    [
      cnode_payload_handler: [
        deps: [shmex: :lib_nif, unifex: :unifex],
        sources: ["cnode_payload_handler.c", "_generated/cnode_payload_handler.c"]
      ]
    ]
  end
end
