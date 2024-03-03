defmodule FastFood.Absinthe.Schema do
  # TODO add parent, context, selection to callbacks

  @type parent() :: struct()
  @type record() :: struct()
  @type context() :: map()

  @callback before_query(parent(), Ecto.Queryable.t(), context()) :: Ecto.Queryable.t()
  @callback after_query(parent(), record(), context()) :: record()
  @callback before_insert(parent() | nil, Ecto.Changeset.t(), context()) :: Ecto.Changeset.t()
  @callback after_insert(parent() | nil, record(), context()) :: any()
  @callback before_update(parent() | nil, Ecto.Changeset.t(), context()) :: Ecto.Changeset.t()
  @callback after_update(parent() | nil, record(), context()) :: any()
  @callback before_delete(parent() | nil, record(), context()) :: any()
  @callback after_delete(parent() | nil, record(), context()) :: any()

  @optional_callbacks \
    before_query: 3,
    after_query: 3,
    before_insert: 3,
    after_insert: 3,
    before_update: 3,
    after_update: 3,
    before_delete: 3,
    after_delete: 3

  defmacro __using__(opts \\ []) do
    quote do
      use Ecto.Schema
      @behaviour FastFood.Absinthe.Schema
      import FastFood.Absinthe.Schema, only: [fastfood_schema: 2]
    end
  end

  defmacro fastfood_schema(source, do: block) do

  end
end
