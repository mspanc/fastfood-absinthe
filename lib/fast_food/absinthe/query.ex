defmodule FastFood.Absinthe.Query do
  import FastFood.Absinthe.Naming
  alias FastFood.Absinthe.Resolver

  defmacro make_queries(ecto_schema) do
    ecto_schema = Macro.expand(ecto_schema, __CALLER__)

    query_many =
      make_root_query_many(ecto_schema)
    query_one =
      make_root_query_one(ecto_schema)
    queries = [query_many, query_one]

    quote do
      unquote(queries)
    end
  end

  defp make_root_query_many(ecto_schema) do
    absinthe_return_type = ecto_schema_to_absinthe_type(ecto_schema)
    query_name = ecto_schema_to_absinthe_query_many(ecto_schema)

    IO.puts "Root Query (many): ecto_schema = #{inspect(ecto_schema)}, absinthe_return_type = non_null(#{inspect(absinthe_return_type)}), query_name = #{inspect(query_name)}"
    quote do
      field unquote(query_name), non_null(list_of(non_null(unquote(absinthe_return_type)))) do
        resolve fn(parent, args, resolution) ->
          Resolver.resolve_root_query_many(unquote(ecto_schema), parent, args, resolution)
        end
      end
    end
  end

  defp make_root_query_one(ecto_schema) do
    absinthe_return_type = ecto_schema_to_absinthe_type(ecto_schema)
    query_name = ecto_schema_to_absinthe_query_one(ecto_schema)

    IO.puts "Root Query (one): ecto_schema = #{inspect(ecto_schema)}, absinthe_return_type = #{inspect(absinthe_return_type)}, query_name = #{inspect(query_name)}"
    quote do
      field unquote(query_name), unquote(absinthe_return_type) do
        arg :id, non_null(:id)
        resolve fn(parent, args, resolution) ->
          Resolver.resolve_root_query_one(unquote(ecto_schema), parent, args, resolution)
        end
      end
    end
  end
end
