defmodule FastFood.Absinthe.Assoc do
  @moduledoc false

  @doc """
  Resolves related Ecto Schema for given Ecto Schema and association name.

  Returns tuple `{cardinality, ecto_schema}`.
  """
  @spec resolve_related_ecto_schema(module(), atom()) :: module()
  def resolve_related_ecto_schema(ecto_schema, association_name) do
    ecto_assoc = ecto_schema.__schema__(:association, association_name)

    case ecto_assoc do
      %Ecto.Association.BelongsTo{related: related_ecto_schema} ->
        {:one, related_ecto_schema}

      %Ecto.Association.Has{cardinality: cardinality, related: related_ecto_schema} ->
        {cardinality, related_ecto_schema}

      %Ecto.Association.ManyToMany{related: related_ecto_schema} ->
        {:many, related_ecto_schema}

      %Ecto.Association.HasThrough{
        cardinality: cardinality,
        owner: owner,
        through: [through_assoc, through_field]
      }
      when is_atom(through_field) ->
        # TODO add support for nested through
        %Ecto.Association.Has{related: through_ecto_schema} =
          owner.__schema__(:association, through_assoc)

        related_ecto_schema =
          case through_ecto_schema.__schema__(:association, through_field) do
            nil ->
              raise """
              Failed to resolve "has through" association for the following FastFood schema:

                #{ecto_schema}.#{association_name}

                  has many through

                #{through_assoc} -> #{through_field}

                It seems that #{ecto_schema}.#{through_assoc} points to

                  #{through_ecto_schema}

                but its field "#{through_field}" is not a valid association.
              """

            related_ecto_schema ->
              related_ecto_schema
              |> Map.get(:related)
          end

        {cardinality, related_ecto_schema}
    end
  end
end
