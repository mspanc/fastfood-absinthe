defmodule FastFood.Absinthe.Mutation do
  import FastFood.Absinthe.Naming
  alias FastFood.Absinthe.{Resolver, Schema}

  defmacro make_mutations(ecto_schema) do
    ecto_schema = Macro.expand(ecto_schema, __CALLER__)
    Schema.check_fastfood_schema!(ecto_schema)

    create_one = make_create_one(ecto_schema)
    update_one = make_update_one(ecto_schema)
    delete_one = make_delete_one(ecto_schema)

    mutations = [create_one, update_one, delete_one]

    quote do
      unquote(mutations)
    end
  end

  defp make_create_one(ecto_schema) do
    mutation_name = ecto_schema_to_absinthe_mutation_create_one(ecto_schema)
    absinthe_input_type = ecto_schema_to_absinthe_input_type(ecto_schema)
    absinthe_return_type = ecto_schema_to_absinthe_type(ecto_schema)

    IO.puts(
      "Root Mutation (create one): ecto_schema = #{inspect(ecto_schema)}, absinthe_input_type = #{inspect(absinthe_input_type)}, absinthe_return_type = #{inspect(absinthe_return_type)}, mutation_name = #{inspect(mutation_name)}"
    )

    quote do
      field unquote(mutation_name), unquote(absinthe_return_type) do
        arg(:input, non_null(unquote(absinthe_input_type)))

        resolve(fn parent, args, resolution ->
          Resolver.resolve_root_create_one(unquote(ecto_schema), parent, args, resolution)
        end)
      end
    end
  end

  defp make_update_one(ecto_schema) do
    mutation_name = ecto_schema_to_absinthe_mutation_update_one(ecto_schema)
    absinthe_input_type = ecto_schema_to_absinthe_input_type(ecto_schema)
    absinthe_return_type = ecto_schema_to_absinthe_type(ecto_schema)

    IO.puts(
      "Root Mutation (update one): ecto_schema = #{inspect(ecto_schema)}, absinthe_input_type = #{inspect(absinthe_input_type)}, absinthe_return_type = #{inspect(absinthe_return_type)}, mutation_name = #{inspect(mutation_name)}"
    )

    quote do
      field unquote(mutation_name), unquote(absinthe_return_type) do
        arg(:id, non_null(:id))
        arg(:input, non_null(unquote(absinthe_input_type)))

        resolve(fn parent, args, resolution ->
          Resolver.resolve_root_update_one(unquote(ecto_schema), parent, args, resolution)
        end)
      end
    end
  end

  defp make_delete_one(ecto_schema) do
    mutation_name = ecto_schema_to_absinthe_mutation_delete_one(ecto_schema)
    absinthe_input_type = ecto_schema_to_absinthe_input_type(ecto_schema)
    absinthe_return_type = ecto_schema_to_absinthe_type(ecto_schema)

    IO.puts(
      "Root Mutation (delete one): ecto_schema = #{inspect(ecto_schema)}, absinthe_input_type = #{inspect(absinthe_input_type)}, absinthe_return_type = #{inspect(absinthe_return_type)}, mutation_name = #{inspect(mutation_name)}"
    )

    quote do
      field unquote(mutation_name), unquote(absinthe_return_type) do
        arg(:id, non_null(:id))

        resolve(fn parent, args, resolution ->
          Resolver.resolve_root_delete_one(unquote(ecto_schema), parent, args, resolution)
        end)
      end
    end
  end
end
