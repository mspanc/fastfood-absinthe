defmodule FastFood.Absinthe.Object do
  import FastFood.Absinthe.Naming

  defmacro make_types(ecto_schema) do
    ecto_schema = Macro.expand(ecto_schema, __CALLER__)

    enum_type = make_enum_type(ecto_schema)
    type = make_type(ecto_schema)
    input_type = make_input_type(ecto_schema)

    types = [enum_type, type, input_type]

    quote do
      unquote(types)
    end
  end

  def make_type(ecto_schema) do
    absinthe_type = ecto_schema_to_absinthe_type(ecto_schema)
    graphql_type = ecto_schema_to_graphql_type(ecto_schema)

    IO.puts(
      "Type: ecto_schema = #{inspect(ecto_schema)}, absinthe_type = #{inspect(absinthe_type)}, graphql_type = #{inspect(graphql_type)}"
    )

    fields = make_fields(ecto_schema, false)

    quote do
      object unquote(absinthe_type), name: unquote(graphql_type) do
        unquote(fields)
      end
    end
  end

  def make_input_type(ecto_schema) do
    absinthe_type = ecto_schema_to_absinthe_input_type(ecto_schema)
    graphql_type = ecto_schema_to_graphql_input_type(ecto_schema)

    IO.puts(
      "Input Type: ecto_schema = #{inspect(ecto_schema)}, absinthe_type = #{inspect(absinthe_type)}, graphql_type = #{inspect(graphql_type)}"
    )

    fields = make_fields(ecto_schema, true)

    quote do
      input_object unquote(absinthe_type), name: unquote(graphql_type) do
        unquote(fields)
      end
    end
  end

  def make_enum_type(ecto_schema) do
    all_fields = ecto_schema.__schema__(:fields)

    for field_name <- all_fields do
      ecto_type = ecto_schema.__schema__(:type, field_name)

      case ecto_type do
        {:parameterized, Ecto.Enum, %{on_cast: on_cast}} ->
          absinthe_type = ecto_schema_to_absinthe_enum_type(ecto_schema, field_name)
          graphql_type = ecto_schema_to_graphql_enum_type(ecto_schema, field_name)

          enum_values =
            on_cast
            |> Map.keys()
            |> Enum.map(&String.to_atom/1)

          fields =
            for enum_value <- enum_values do
              quote do
                value(unquote(enum_value))
              end
            end

          IO.puts(
            "Enum Type: ecto_schema = #{inspect(ecto_schema)}, absinthe_type = #{inspect(absinthe_type)}, graphql_type = #{inspect(graphql_type)}, enum_values = #{inspect(enum_values)}"
          )

          quote do
            enum unquote(absinthe_type), name: unquote(graphql_type) do
              unquote(fields)
            end
          end

        _ ->
          nil
      end
    end
  end

  defp make_fields(ecto_schema, is_input_type) do
    make_persistent_fields(ecto_schema, is_input_type) ++
      make_virtual_fields(ecto_schema, is_input_type) ++
      make_embedded_fields(ecto_schema, is_input_type) ++
      make_associations(ecto_schema, is_input_type)
  end

  defp make_persistent_fields(ecto_schema, is_input_type) do
    all_fields = ecto_schema.__schema__(:fields)
    embedded_fields = ecto_schema.__schema__(:embeds)
    persistent_fields = all_fields -- embedded_fields

    for field_name <- persistent_fields do
      ecto_type = ecto_schema.__schema__(:type, field_name)

      is_primary_key =
        ecto_schema.__schema__(:primary_key)
        |> Enum.member?(field_name)

      is_autogenerated =
        ecto_schema.__schema__(:autogenerate_fields)
        |> Enum.member?(field_name)

      if !(is_input_type && (is_primary_key || is_autogenerated)) do
        declare_field(ecto_schema, field_name, ecto_type, is_input_type)
      end
    end
  end

  defp make_embedded_fields(ecto_schema, is_input_type) do
    for field_name <- ecto_schema.__schema__(:embeds) do
      %Ecto.Embedded{cardinality: cardinality, related: related_ecto_schema} =
        ecto_schema.__schema__(:embed, field_name)

      absinthe_type =
        if is_input_type do
          ecto_schema_to_absinthe_input_type(related_ecto_schema)
        else
          ecto_schema_to_absinthe_type(related_ecto_schema)
        end

      # FIXME make separate nulls for CUD and R
      non_null =
        if is_input_type do
          false
        else
          is_field_non_null?(ecto_schema, field_name)
        end

      IO.puts(
        " - embed: field_name = #{inspect(field_name)}, related_ecto_schema = #{inspect(related_ecto_schema)}, absinthe_type = #{inspect(absinthe_type)}, non_null = #{inspect(non_null)}, cardinality = #{inspect(cardinality)}"
      )

      if !is_nil(absinthe_type) do
        case cardinality do
          :one ->
            if non_null do
              quote do
                field(unquote(field_name), non_null(unquote(absinthe_type)))
              end
            else
              quote do
                field(unquote(field_name), unquote(absinthe_type))
              end
            end

          :many ->
            if is_input_type do
              quote do
                field(unquote(field_name), non_null(list_of(non_null(unquote(absinthe_type)))))
              end
            else
              quote do
                field(unquote(field_name), non_null(list_of(non_null(unquote(absinthe_type)))))
              end
            end
        end
      end
    end
  end

  defp make_virtual_fields(ecto_schema, is_input_type) do
    if !is_input_type do
      for field_name <- ecto_schema.__schema__(:virtual_fields) do
        ecto_type = ecto_schema.__schema__(:virtual_type, field_name)
        declare_field(ecto_schema, field_name, ecto_type, is_input_type)
      end
    else
      []
    end
  end

  defp make_associations(ecto_schema, is_input_type) do
    for association_name <- ecto_schema.__schema__(:associations) do
      ecto_assoc = ecto_schema.__schema__(:association, association_name)

      {cardinality, related_ecto_schema} =
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
              through_ecto_schema.__schema__(:association, through_field)
              |> Map.get(:related)

            {cardinality, related_ecto_schema}
        end

      absinthe_type =
        if is_input_type do
          ecto_schema_to_absinthe_input_type(related_ecto_schema)
        else
          ecto_schema_to_absinthe_type(related_ecto_schema)
        end

      # FIXME make separate nulls for CUD and R
      non_null =
        if is_input_type do
          false
        else
          is_field_non_null?(ecto_schema, association_name)
        end

      IO.puts(
        " - association: field_name = #{inspect(association_name)}, related_ecto_schema = #{inspect(related_ecto_schema)}, absinthe_type = #{inspect(absinthe_type)}, non_null = #{inspect(non_null)}, cardinality = #{inspect(cardinality)}"
      )

      if !is_nil(absinthe_type) do
        case cardinality do
          :one ->
            if non_null do
              quote do
                field(unquote(association_name), non_null(unquote(absinthe_type)))
              end
            else
              quote do
                field(unquote(association_name), unquote(absinthe_type))
              end
            end

          :many ->
            if is_input_type do
              quote do
                field(unquote(association_name), list_of(non_null(unquote(absinthe_type))))
              end
            else
              quote do
                field(
                  unquote(association_name),
                  non_null(list_of(non_null(unquote(absinthe_type))))
                )
              end
            end
        end
      end
    end
  end

  defp declare_field(ecto_schema, field_name, ecto_type, is_input_type) do
    absinthe_type =
      case ecto_type do
        {:parameterized, Ecto.Enum, _} ->
          ecto_schema_to_absinthe_enum_type(ecto_schema, field_name)

        ecto_type ->
          ecto_field_type_to_absinthe_type(ecto_type)
      end

    # FIXME make separate nulls for CUD and R
    non_null =
      if is_input_type do
        false
      else
        is_field_non_null?(ecto_schema, field_name)
      end

    IO.puts(
      " - field: field_name = #{inspect(field_name)}, ecto_type = #{inspect(ecto_type)}, absinthe_type = #{inspect(absinthe_type)}, non_null = #{inspect(non_null)}"
    )

    if !is_nil(absinthe_type) do
      if non_null do
        quote do
          field(unquote(field_name), non_null(unquote(absinthe_type)))
        end
      else
        quote do
          field(unquote(field_name), unquote(absinthe_type))
        end
      end
    end
  end
end
