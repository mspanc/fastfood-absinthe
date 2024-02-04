defmodule FastFood.Absinthe.Naming do
  @moduledoc false

  @ecto_schema_prefix_length Application.compile_env!(:fastfood_absinthe, :ecto_schema_prefix) |> to_string() |> String.split(".") |> length()

  @doc """
  Converts Ecto schema module names to types used by Absinthe.
  They should be lower case atoms.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :vehicle_car.

  It can be overriden by declaring ff_absinthe_type/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_type(struct()) :: atom()
  def ecto_schema_to_absinthe_type(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_absinthe_type)
  end

  @doc """
  Converts Ecto schema module names to input types used by
  Absinthe. They should be lower case atoms.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :vehicle_car_input.

  It can be overriden by declaring ff_absinthe_input_type/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_input_type(struct()) :: atom()
  def ecto_schema_to_absinthe_input_type(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_absinthe_input_type, nil, "input")
  end

  @doc """
  Converts Ecto schema module names to query names used by
  Absinthe for defining root query allowing to fetch
  a collection of records of given Ecto schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :vehicle_car_list.

  It can be overriden by declaring ff_root_query_many/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_query_many(struct()) :: atom()
  def ecto_schema_to_absinthe_query_many(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_query_many, nil, "list")
  end

  @doc """
  Converts Ecto schema module names to query names used by
  Absinthe for defining root query allowing to fetch
  a single record of given Ecto schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :vehicle_car.

  It can be overriden by declaring ff_root_query_one/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_query_one(struct()) :: atom()
  def ecto_schema_to_absinthe_query_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_query_one)
  end

  @doc """
  Converts Ecto schema module names to mutation names used by
  Absinthe for defining default "create one" mutation,
  allowing creation a single record of given schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :create_vehicle_car.

  It can be overriden by declaring ff_root_create_mutation_one/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_create_mutation_one(struct()) :: atom()
  def ecto_schema_to_absinthe_create_mutation_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_create_mutation_one, "create")
  end

  @doc """
  Converts Ecto schema module names to mutation names used by
  Absinthe for defining default "update one" mutation,
  allowing updating a single record of given schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :update_vehicle_car.

  It can be overriden by declaring ff_root_update_mutation_one/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_delete_mutation_one(struct()) :: atom()
  def ecto_schema_to_absinthe_delete_mutation_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_delete_mutation_one, "delete")
  end

  @doc """
  Converts Ecto schema module names to mutation names used by
  Absinthe for defining default "delete one" mutation,
  allowing deletion of a single record of given schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :update_vehicle_car.

  It can be overriden by declaring ff_root_update_mutation_one/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_update_mutation_one(struct()) :: atom()
  def ecto_schema_to_absinthe_update_mutation_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_update_mutation_one, "update")
  end

  defp do_ecto_schema_to_absinthe_type(ecto_schema, override_fun, prefix \\ nil, suffix \\ nil) do
    if function_exported?(ecto_schema, override_fun, 0) do
      apply(ecto_schema, override_fun, [])
    else
      splitted =
        ecto_schema
        |> to_string()
        |> String.downcase()
        |> String.split(".")

      splitted =
        splitted
        |> Enum.slice(@ecto_schema_prefix_length, length(splitted))

      splitted =
        if !is_nil(prefix) do
          [prefix|splitted]
        else
          splitted
        end

      splitted =
        if !is_nil(suffix) do
          splitted ++ [suffix]
        else
          splitted
        end

      splitted
      |> Enum.join("_")
      |> String.to_atom()
    end
  end

  @doc """
  Converts Ecto schema module names to GraphQL typenames.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output "VehicleCar".

  It can be overriden by declaring ff_graphql_type/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_graphql_type(struct()) :: String.t()
  def ecto_schema_to_graphql_type(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_graphql_type(:ff_graphql_type)
  end


  @doc """
  Converts Ecto schema module names to GraphQL typenames
  for input types.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output "VehicleCarInput".

  It can be overriden by declaring ff_graphql_input_type/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_graphql_input_type(struct()) :: String.t()
  def ecto_schema_to_graphql_input_type(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_graphql_type(:ff_graphql_input_type, "Input")
  end

  defp do_ecto_schema_to_graphql_type(ecto_schema, override_fun, suffix \\ nil) do
    if function_exported?(ecto_schema, override_fun, 0) do
      apply(ecto_schema, override_fun, 0)
    else
      splitted =
        ecto_schema
        |> to_string()
        |> String.split(".")

      splitted =
        splitted
        |> Enum.slice(@ecto_schema_prefix_length, length(splitted))

      splitted =
        if !is_nil(suffix) do
          splitted ++ [suffix]
        else
          splitted
        end

      splitted
      |> Enum.join("")
    end
  end

  @doc """
  Converts field types used by Ecto to ones used by Absinthe.
  """
  @spec ecto_field_type_to_absinthe_type(atom()) :: atom()
  def ecto_field_type_to_absinthe_type(ecto_type) do
    # TODO support polymorphic embed
    case ecto_type do
      :utc_datetime_usec ->
        :datetime

      :utc_datetime ->
        :datetime

      {:parameterized, Ecto.Embedded, %Ecto.Embedded{cardinality: :one, related: related_ecto_schema}} ->
        ecto_schema_to_absinthe_type(related_ecto_schema)

      {:parameterized, Ecto.Enum, %{type: enum_base_type}} ->
        ecto_field_type_to_absinthe_type(enum_base_type)

      other ->
        other
    end
  end

  @doc """
  Checks if given field should be marked non-null as GraphQL treats
  all fields as nullable by default.

  Field might be marked as non-null if any of the following happens:
  - it is manually whitelisted as non-null via ecto_schema's
    ff_non_null_fields function
  - it is a part of the primary key,
  - it is autogenerated on insert.
  """
  @spec is_field_non_null?(struct(), atom()) :: boolean()
  def is_field_non_null?(ecto_schema, field_name) do
    is_whitelisted =
      function_exported?(ecto_schema, :ff_non_null_fields, 0)
      && Enum.member?(ecto_schema.ff_non_null_fields(), field_name)

    is_primary_key =
      ecto_schema.__schema__(:primary_key)
      |> Enum.member?(field_name)

    is_autogenerated =
      ecto_schema.__schema__(:autogenerate_fields)
      |> Enum.member?(field_name)

    is_whitelisted || is_primary_key || is_autogenerated
  end
end
