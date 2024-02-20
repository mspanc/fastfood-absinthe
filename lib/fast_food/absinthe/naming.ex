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
    |> do_ecto_schema_to_absinthe_type(:ff_absinthe_input_type, nil, "Input")
  end

  @doc """
  Converts Ecto schema module names to enum types used by
  Absinthe. They should be lower case atoms.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car, and
  :ecto_schema_prefix specified in the config is MyApp.Data,
  and the field name that is enum is :vendor, it should
  output :vehicle_car_input_vendor_enum.

  It currently cannot be overriden.
  """
  @spec ecto_schema_to_absinthe_enum_type(struct(), atom()) :: atom()
  def ecto_schema_to_absinthe_enum_type(ecto_schema, field_name) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(nil, nil, "#{field_name}_enum")
  end

  @doc """
  Converts Ecto schema module names to query names used by
  Absinthe for defining root query allowing to fetch
  a collection of records of given Ecto schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output `:vehicle_cars_`.

  It can be overriden by declaring ff_root_query_many/0 in
  the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_query_many(struct()) :: atom()
  def ecto_schema_to_absinthe_query_many(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_query_many, nil, nil, true)
  end

  @doc """
  Converts Ecto schema module names to query names used by
  Absinthe for defining root query allowing to fetch
  a single record of given Ecto schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output `{:vehicle_car_query, "vehicleCar"}`.

  It can be overriden by declaring ff_root_query_one_type/0
  or ff_root_query_one_name/0 in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_query_one(struct()) :: atom()
  def ecto_schema_to_absinthe_query_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_query_one_name)
  end

  @doc """
  Converts Ecto schema module names to mutation names used by
  Absinthe for defining default "create one" mutation,
  allowing creation a single record of given schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :create_vehicle_car.

  It can be overriden by declaring ff_root_mutation_create_one/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_mutation_create_one(struct()) :: atom()
  def ecto_schema_to_absinthe_mutation_create_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_mutation_create_one, "create")
  end

  @doc """
  Converts Ecto schema module names to mutation names used by
  Absinthe for defining default "update one" mutation,
  allowing updating a single record of given schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :update_vehicle_car.

  It can be overriden by declaring ff_root_mutation_update_one/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_mutation_delete_one(struct()) :: atom()
  def ecto_schema_to_absinthe_mutation_delete_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_mutation_delete_one, "delete")
  end

  @doc """
  Converts Ecto schema module names to mutation names used by
  Absinthe for defining default "delete one" mutation,
  allowing deletion of a single record of given schema.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car and
  :ecto_schema_prefix specified in the config is MyApp.Data
  it should output :update_vehicle_car.

  It can be overriden by declaring ff_root_mutation_update_one/0
  in the Ecto schema module.
  """
  @spec ecto_schema_to_absinthe_mutation_update_one(struct()) :: atom()
  def ecto_schema_to_absinthe_mutation_update_one(ecto_schema) do
    ecto_schema
    |> do_ecto_schema_to_absinthe_type(:ff_root_mutation_update_one, "update")
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
  for enum types.

  The default mechanism tries to use module name. For example,
  if your Ecto schema module is MyApp.Data.Vehicle.Car, and
  :ecto_schema_prefix specified in the config is MyApp.Data,
  and field name that is enum is :vendor, it should output
  "VehicleCarInputVendorEnum".

  It currently cannot be overridden.
  """
  @spec ecto_schema_to_graphql_enum_type(struct(), atom()) :: String.t()
  def ecto_schema_to_graphql_enum_type(ecto_schema, field_name) do
    ecto_schema
    |> do_ecto_schema_to_graphql_type(nil, nil, "#{Inflex.camelize(field_name)}Enum")
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
    |> do_ecto_schema_to_graphql_type(:ff_graphql_input_type, nil, "Input")
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

  defp do_ecto_schema_to_absinthe_type(ecto_schema, override_fun, prefix \\ nil, suffix \\ nil, pluralize_base \\ false) do
    do_ecto_schema_prepare(ecto_schema, override_fun, prefix, suffix, pluralize_base)
    |> Enum.join("")
    |> Inflex.underscore()
    |> String.to_atom()
  end

  defp do_ecto_schema_to_graphql_type(ecto_schema, override_fun, prefix \\ nil, suffix \\ nil, pluralize_base \\ false) do
    do_ecto_schema_prepare(ecto_schema, override_fun, prefix, suffix, pluralize_base)
    |> Enum.join("")
  end

  defp do_ecto_schema_prepare(ecto_schema, override_fun, prefix \\ nil, suffix \\ nil, pluralize_base \\ false) do
    if function_exported?(ecto_schema, override_fun, 0) do
      apply(ecto_schema, override_fun, 0)
    else
      stringified =
        ecto_schema
        |> to_string()

      stringified =
        if pluralize_base do
          Inflex.pluralize(stringified)
        else
          stringified
        end

      splitted =
        stringified
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

      if !is_nil(suffix) do
        splitted ++ [suffix]
      else
        splitted
      end
    end
  end
end
