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
    return_absinthe_type = ecto_schema_to_absinthe_type(ecto_schema)
    {query_type, query_name} = ecto_schema_to_absinthe_query_many(ecto_schema)

    IO.puts "Root Query (many): ecto_schema = #{inspect(ecto_schema)}, return_absinthe_type = non_null(#{inspect(return_absinthe_type)}), query_type = #{inspect(query_type)}, query_name = #{inspect(query_name)}"
    quote do
      field unquote(query_type), list_of(non_null(unquote(return_absinthe_type))), name: unquote(query_name) do
        resolve fn(parent, args, resolution) ->
          Resolver.resolve_root_query_many(unquote(ecto_schema), parent, args, resolution)
        end
      end
    end
  end

  defp make_root_query_one(ecto_schema) do
    return_absinthe_type = ecto_schema_to_absinthe_type(ecto_schema)
    {query_type, query_name} = ecto_schema_to_absinthe_query_one(ecto_schema)

    IO.puts "Root Query (one): ecto_schema = #{inspect(ecto_schema)}, absinthe_type = #{inspect(return_absinthe_type)}, query_type = #{inspect(query_type)}, query_name = #{inspect(query_name)}"
    quote do
      field unquote(query_type), unquote(return_absinthe_type), name: unquote(query_name) do
        arg :id, non_null(:id)
        resolve fn(parent, args, resolution) ->
          Resolver.resolve_root_query_one(unquote(ecto_schema), parent, args, resolution)
        end
      end
    end
  end
end
