defmodule FastFood.Absinthe.Resolver do
  @moduledoc false

  @ecto_repo Application.compile_env!(:fastfood_absinthe, :ecto_repo)

  import Ecto.Query
  require Logger

  def resolve_root_query_many(ecto_schema, parent, args, resolution) do
    Logger.debug("[FastFood.Absinthe.Resolver] Root Query (many), ecto_schema = #{inspect(ecto_schema)}, parent = #{inspect(parent)}, args = #{inspect(args)}")
    %Absinthe.Blueprint.Document.Field{selections: selections} = resolution.definition

    @ecto_repo.transaction(fn ->
      load_many(ecto_schema, selections)
    end)
  end

  def resolve_root_query_one(ecto_schema, parent, %{id: id} = args, resolution) do
    Logger.debug("[FastFood.Absinthe.Resolver] Root Query (one), ecto_schema = #{inspect(ecto_schema)}, parent = #{inspect(parent)}, args = #{inspect(args)}")
    %Absinthe.Blueprint.Document.Field{selections: selections} = resolution.definition

    @ecto_repo.transaction(fn ->
      load_one(ecto_schema, id, selections)
    end)
  end

  def resolve_root_create_one(ecto_schema, parent, %{input: input} = args, resolution) do
    Logger.debug("[FastFood.Absinthe.Resolver] Root Create (one), ecto_schema = #{inspect(ecto_schema)}, parent = #{inspect(parent)}, args = #{inspect(args)}")
    %Absinthe.Blueprint.Document.Field{selections: selections} = resolution.definition

    @ecto_repo.transaction(fn ->
      base = struct(ecto_schema)

      changeset =
        if function_exported?(ecto_schema, :ff_changeset_create, 2) do
          ecto_schema.ff_changeset_create(base, input)
        else
          ecto_schema.changeset(base, input)
        end

      changeset =
        if function_exported?(ecto_schema, :ff_before_create, 1) do
          ecto_schema.ff_before_create(changeset)
        else
          changeset
        end

      case @ecto_repo.insert(changeset) do
        {:ok, record} ->
          if function_exported?(ecto_schema, :ff_after_create, 1) do
            ecto_schema.ff_after_create(record)
          else
            changeset
          end

          # Re-load so we apply the same logic as when querying
          load_one(ecto_schema, record.id, selections)

        {:error, reason} ->
          @ecto_repo.rollback(reason)
      end
    end)
    |> format_result()
  end

  def resolve_root_update_one(ecto_schema, parent, %{id: id, input: input} = args, resolution) do
    Logger.debug("[FastFood.Absinthe.Resolver] Root Update (one), ecto_schema = #{inspect(ecto_schema)}, parent = #{inspect(parent)}, args = #{inspect(args)}")
    %Absinthe.Blueprint.Document.Field{selections: selections} = resolution.definition

    @ecto_repo.transaction(fn ->
      case @ecto_repo.get(ecto_schema, id) do
        nil ->
          @ecto_repo.rollback(:notfound)
        base ->
          changeset =
            if function_exported?(ecto_schema, :ff_changeset_update, 2) do
              ecto_schema.ff_changeset_update(base, input)
            else
              ecto_schema.changeset(base, input)
            end

          changeset =
            if function_exported?(ecto_schema, :ff_before_update, 1) do
              ecto_schema.ff_before_update(changeset)
            else
              changeset
            end

          case @ecto_repo.update(changeset) do
            {:ok, record} ->
              if function_exported?(ecto_schema, :ff_after_update, 1) do
                ecto_schema.ff_after_update(record)
              else
                changeset
              end

              # Re-load so we apply the same logic as when querying
              load_one(ecto_schema, record.id, selections)

            {:error, reason} ->
              @ecto_repo.rollback(reason)
          end
      end
    end)
    |> format_result()
  end

  def resolve_root_delete_one(ecto_schema, parent, %{id: id} = args, resolution) do
    Logger.debug("[FastFood.Absinthe.Resolver] Root Delete (one), ecto_schema = #{inspect(ecto_schema)}, parent = #{inspect(parent)}, args = #{inspect(args)}")
    %Absinthe.Blueprint.Document.Field{selections: selections} = resolution.definition

    @ecto_repo.transaction(fn ->
      # Re-load so we apply the same logic as when querying
      old_record = load_one(ecto_schema, id, selections)

      case @ecto_repo.get(ecto_schema, id) do
        nil ->
          @ecto_repo.rollback(:notfound)

        record ->
          if function_exported?(ecto_schema, :ff_before_delete, 1) do
            ecto_schema.ff_before_delete(record)
          end

          case @ecto_repo.delete(record) do
            {:ok, _record} ->
              if function_exported?(ecto_schema, :ff_after_delete, 1) do
                ecto_schema.ff_after_delete(record)
              end

              # Return deleted record as it was loaded prior to deletion
              old_record

            {:error, reason} ->
              @ecto_repo.rollback(reason)
          end
      end
    end)
    |> format_result()
  end

  # Mutation helpers
  #
  defp format_result(result) do
    case result do
      {:ok, result} ->
        {:ok, result}

      {:error, :notfound} ->
        {:error, message: "Unable to find record with given ID", code: :notfound}

      {:error, changeset = %Ecto.Changeset{}} ->
        # FIXME put this in extensions structure so it is machine readable
        reason =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)
          |> Enum.map(fn ({field, errors}) ->
            # FIXME errors can be nested, e.g.
            # %{a: %{b: [\"message\"]}})
            "#{field} #{inspect(errors)}"
          end)
          |> Enum.join("; ")
        {:error, message: "Unable to perform database operation: (#{reason})", code: :validation}
    end
  end

  # Entry points for loading in queries

  defp load_many(ecto_schema, selections) do
    ecto_schema
    |> apply_filter_query_for_root()
    |> @ecto_repo.all()
    |> Enum.map(&apply_virtual_fields/1)
    |> do_load_collection(selections, [])
  end

  defp load_one(ecto_schema, id, selections) do
    ecto_schema
    |> apply_filter_query_for_root()
    |> where([x], x.id == ^id)
    |> @ecto_repo.one()
    |> apply_virtual_fields()
    |> do_load_single(selections, %{})
  end

  # Traverse field/assoc handlers

  defp do_load_single(nil, _selections, _acc) do
    nil
  end

  defp do_load_single(_record, [], acc) do
    acc
  end

  # Association (many, nullable)
  defp do_load_single(record, [%Absinthe.Blueprint.Document.Field{
    selections: selections,
    schema_node: %Absinthe.Type.Field{
      identifier: field_identifier,
      type: %Absinthe.Type.List{of_type: assoc_field_type}
    }}|rest], acc) when is_atom(assoc_field_type) and length(selections) != 0 do
    # IO.puts "- do_load_single (assoc one nullable) record = #{print_record(record)}, field_identifier = #{inspect(field_identifier)}, acc = #{inspect(acc)}"
    assoc_data =
      record
      |> fetch_assoc_many(field_identifier)
      |> do_load_collection(selections, [])

    do_load_single(record, rest, Map.put(acc, field_identifier, assoc_data))
  end

  # Association (many, list non-nullable, items nullable)
  defp do_load_single(record, [%Absinthe.Blueprint.Document.Field{
    selections: selections,
    schema_node: %Absinthe.Type.Field{
      identifier: field_identifier,
      type: %Absinthe.Type.NonNull{
        of_type: %Absinthe.Type.List{
          of_type: assoc_field_type
        }
      }
    }}|rest], acc) when is_atom(assoc_field_type) and length(selections) != 0 do
    # IO.puts "- do_load_single (assoc one nullable) record = #{print_record(record)}, field_identifier = #{inspect(field_identifier)}, acc = #{inspect(acc)}"

    assoc_data =
      record
      |> fetch_assoc_many(field_identifier)
      |> do_load_collection(selections, [])

    do_load_single(record, rest, Map.put(acc, field_identifier, assoc_data))
  end

  # Association (many, list non-nullable, items non-nullable)
  defp do_load_single(record, [%Absinthe.Blueprint.Document.Field{
    selections: selections,
    schema_node: %Absinthe.Type.Field{
      identifier: field_identifier,
      type: %Absinthe.Type.NonNull{
        of_type: %Absinthe.Type.List{
          of_type: %Absinthe.Type.NonNull{
            of_type: assoc_field_type
          }
        }
      }
    }}|rest], acc) when is_atom(assoc_field_type) and length(selections) != 0 do
    # IO.puts "- do_load_single (assoc one nullable) record = #{print_record(record)}, field_identifier = #{inspect(field_identifier)}, acc = #{inspect(acc)}"

    assoc_data =
      record
      |> fetch_assoc_many(field_identifier)
      |> do_load_collection(selections, [])

    do_load_single(record, rest, Map.put(acc, field_identifier, assoc_data))
  end

  # Association (one, nullable)
  defp do_load_single(record, [%Absinthe.Blueprint.Document.Field{
    selections: selections,
    schema_node: %Absinthe.Type.Field{
      identifier: field_identifier,
      type: assoc_field_type
    }}|rest], acc) when is_atom(assoc_field_type) and length(selections) != 0 do
    # IO.puts "- do_load_single (assoc one nullable) record = #{print_record(record)}, field_identifier = #{inspect(field_identifier)}, acc = #{inspect(acc)}"
    assoc_data = fetch_assoc_one(record, field_identifier)
    do_load_single(record, rest, Map.put(acc, field_identifier, assoc_data))
  end

  # Association (one, list non-nullable)
  defp do_load_single(record, [%Absinthe.Blueprint.Document.Field{
    selections: selections,
    schema_node: %Absinthe.Type.Field{
      identifier: field_identifier,
      type: %Absinthe.Type.NonNull{of_type: assoc_field_type},
    }}|rest], acc) when is_atom(assoc_field_type) and length(selections) != 0 do
      # IO.puts "- do_load_single (assoc one non-nullable) record = #{print_record(record)}, field_identifier = #{inspect(field_identifier)}, acc = #{inspect(acc)}"
      assoc_data = fetch_assoc_one(record, field_identifier)
      do_load_single(record, rest, Map.put(acc, field_identifier, assoc_data))
  end

  # Regular field
  defp do_load_single(record, [%Absinthe.Blueprint.Document.Field{
    selections: selections,
    schema_node: %Absinthe.Type.Field{
      identifier: field_identifier
    }}|rest], acc) when length(selections) == 0 do
      # IO.puts "- do_load_single (field) record = #{print_record(record)}, field_identifier = #{inspect(field_identifier)}, acc = #{inspect(acc)}"
    do_load_single(record, rest, Map.put(acc, field_identifier, Map.get(record, field_identifier)))
  end

  defp do_load_single(record, [field|_rest], _acc) do
    raise "TODO do_load_single #{inspect(record)} #{inspect(field)}"
  end

  defp do_load_collection([], _selections, acc) do
    # IO.puts "- do_load_collection done, acc = #{inspect(acc)}"
    Enum.reverse(acc)
  end

  defp do_load_collection([record|rest], selections, acc) do
    # IO.puts "- do_load_collection record = #{print_record(record)}, selections = #{inspect(selections)}, acc = #{inspect(acc)}"
    data =
      record
      |> do_load_single(selections, %{})

    do_load_collection(rest, selections, [data|acc])
  end

  # Association helpers

  defp fetch_assoc_one(record, field_identifier) do
    if Enum.member?(record.__struct__.__schema__(:embeds), field_identifier) do
      record
      |> Map.get(field_identifier)
      |> apply_virtual_fields()
    else
      default_query =
        record
        |> Ecto.assoc(field_identifier)

      related_ecto_schema =
        record.__struct__.__schema__(:association, field_identifier).related

      filtered_query =
        record
        |> apply_filter_query_with_parent(related_ecto_schema, default_query)

      filtered_query
      |> @ecto_repo.one()
      |> apply_virtual_fields()
    end
  end

  defp fetch_assoc_many(record, field_identifier) do
    if Enum.member?(record.__struct__.__schema__(:embeds), field_identifier) do
      record
      |> Map.get(field_identifier)
      |> Enum.map(&apply_virtual_fields/1)
    else
      default_query =
        record
        |> Ecto.assoc(field_identifier)

      related_ecto_schema =
        record.__struct__.__schema__(:association, field_identifier).related

      filtered_query =
        record
        |> apply_filter_query_with_parent(related_ecto_schema, default_query)

      filtered_query
      |> @ecto_repo.all()
      |> Enum.map(&apply_virtual_fields/1)
    end
  end

  # Customizations

  defp apply_filter_query_for_root(ecto_schema) do
    queryable = (from ecto_schema)
    if function_exported?(ecto_schema, :ff_filter_query, 2) do
      ecto_schema.ff_filter_query(nil, queryable)
    else
      queryable
    end
  end

  defp apply_filter_query_with_parent(parent, ecto_schema, queryable) when is_struct(parent) do
    # TODO pass args etc.
    if function_exported?(ecto_schema, :ff_filter_query, 2) do
      ecto_schema.ff_filter_query(parent, queryable)
    else
      queryable
    end
  end

  defp apply_virtual_fields(nil) do
    nil
  end

  defp apply_virtual_fields(record) when is_struct(record) do
    # TODO pass args etc.
    ecto_schema = record.__struct__
    if function_exported?(ecto_schema, :ff_virtual_values, 1) do
      ecto_schema.ff_virtual_values(record)
    else
      record
    end
  end

  # Debugging

  # defp print_record(record) do
  #   "#{to_string(record.__struct__)}##{record.id}"
  # end
end
