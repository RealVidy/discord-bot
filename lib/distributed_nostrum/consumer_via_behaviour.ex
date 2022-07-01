defmodule DistributedNostrum.ConsumerViaBehaviour do
  @callback via_tuple(id :: term()) ::
              {:via, registry_module :: module(), registry_tuple :: tuple()}
end
