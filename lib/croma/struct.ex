defmodule Croma.Struct do
  @moduledoc """
  Utility module to define structs and some helper functions.

  Using this module requires to prepare type modules for all struct fields.
  Each of per-field type module is expected to provide the following members:

  - required: `@type t`
  - required: `@spec valid?(term) :: boolean`
  - optional: `@spec default() :: t`
  - optional: `@spec new(term) :: Croma.Result.t(t)`

  Some helpers for defining such per-field type modules are available.

  - Wrappers of built-in types such as `Croma.String`, `Croma.Integer`, etc.
  - Utility modules such as `Croma.SubtypeOfString` to define "subtypes" of existing types.
  - Ad-hoc module generators defined in `Croma.TypeGen`.
  - This module, `Croma.Struct` itself for nested structs.
      - `:recursive_new?` option may come in handy when constructing a nested struct. See the section below.

  To define a struct, `use` this module with a keyword list where keys are field names and values are type modules:

      defmodule S do
        use Croma.Struct, fields: [field1_name: Field1Module, field2_name: Field2Module]
      end

  Then the above code is converted to `defstruct` along with `@type t`.

  This module also generates the following functions:

  - `@spec valid?(term) :: boolean`
  - `@spec new(term) :: Croma.Result.t(t)`
  - `@spec new!(term) :: t`
  - `@spec update(t, Dict.t) :: Croma.Result.t(t)`
  - `@spec update!(t, Dict.t) :: t`

  The functions listed above are all overridable, so you can
  for example implement your own validation rule that spans multiple fields.

  ## Examples
      iex> defmodule I do
      ...>   @type t :: integer
      ...>   def valid?(i), do: is_integer(i)
      ...>   def default(), do: 0
      ...> end

      ...> defmodule S do
      ...>   use Croma.Struct, fields: [i: I]
      ...> end

      ...> S.new(%{i: 5})
      {:ok, %S{i: 5}}

      ...> S.valid?(%S{i: "not_an_integer"})
      false

      ...> {:ok, s} = S.new(%{})
      {:ok, %S{i: 0}}

      ...> S.update(s, [i: 2])
      {:ok, %S{i: 2}}

      ...> S.update(s, %{"i" => "not_an_integer"})
      {:error, {:invalid_value, [S, I]}}

  ## Naming convention of field names (case of identifiers)

  When working with structured data (e.g. JSON) from systems with different naming conventions,
  it's convenient to adjust the names to your favorite convention in this layer.
  You can specify the acceptable naming schemes of data structures to be converted
  by `new/1` and `new!/1` using `:accept_case` option of `use Croma.Struct`.

  - `nil` (default): Accepts only the given field names.
  - `:lower_camel`: Accepts both the given field names and their lower camel variants.
  - `:upper_camel`: Accepts both the given field names and their upper camel variants.
  - `:snake`: Accepts both the given field names and their snake cased variants.
  - `:capital`: Accepts both the given field names and their variants where all characters are capital.

  ## Default value of each field

  You can specify default value of each struct field by

  1. giving `:default` option in per-field options
  2. defining `default/0` in the field's type module (which is evaluated at compile-time)

  If you specify both, (1) takes precedence over (2).
  Additionally, you can tell `Croma.Struct` not to use `default/0` by specifying `no_default?: true`.
  If no default value is provided for a field, then the field must be explicitly filled when constructing a new struct.

  As an example, suppose you have the following modules.
      defmodule I do
        use Croma.SubtypeOfInt, min: 0, default: 1
      end
      defmodule S do
        use Croma.Struct, fields: [
          a: Croma.Integer,
          b: I,
          c: {Croma.Integer, [default: 2]},
          d: {I            , [default: 3]},
          e: {Croma.Integer, [no_default?: true]},
          f: {I            , [no_default?: true]},
        ]
      end

  Note that `I` has `default/0` whereas `Croma.Integer` does not export `default/0`.
  Then,
  - `a`, `e` and `f` have no default values
  - Default value of `b` is `1`
  - Default value of `c` is `2`
  - Default value of `d` is `3`

  ## Nested struct and `:recursive_new?`

  When you make an instance of nested struct defined using `Croma.Struct`,
  it's convenient to recursively calling `new/1` for each sub-structs,
  so that whole data structure can be generated by just one invocation of `new/1` of the root struct.

  `:recursive_new?` option can be set to `true` for such case.

      iex> defmodule Leaf do
      ...>   use Croma.Struct, fields: [ns: Croma.TypeGen.nilable(Croma.String)]
      ...> end

      ...> defmodule Branch do
      ...>   use Croma.Struct, fields: [l: Leaf], recursive_new?: true
      ...> end

      ...> defmodule Root do
      ...>   use Croma.Struct, fields: [b: Branch], recursive_new?: true
      ...> end

      ...> Root.new(%{})
      {:ok, %Root{b: %Branch{l: %Leaf{ns: nil}}}}

  Note that if a field is missing, complementary functions will be called in order of
  `default/0` then `new/1` (with `nil` as input).

  Also, if a field has an invalid value, `new/1` will be called with that value as input.
  """

  import Croma.Defun
  require Croma.Result, as: R

  @doc false
  def field_default_value_pairs(fields) do
    Enum.map(fields, fn {f, {mod, field_opts}} ->
      {f, compute_default_value(f, mod, field_opts)}
    end)
  end

  defp compute_default_value(field, mod, field_opts) do
    case {Keyword.get(field_opts, :no_default?, false), Keyword.fetch(field_opts, :default)} do
      {true , {:ok, _}} -> raise "no_default?: true but :default option is also given for field '#{field}'"
      {true , :error  } -> :error
      {false, {:ok, d}} ->
        if !mod.valid?(d), do: raise "invalid default value is given to field '#{field}' with type #{inspect(mod)} : #{inspect(d)}"
        {:ok, d}
      {false, :error  } ->
        try do
          {:ok, mod.default()}
        rescue
          UndefinedFunctionError -> :error
        end
    end
  end

  @doc false
  def field_type_pairs(field_mod_pairs) do
    Enum.map(field_mod_pairs, fn {key, mod} ->
      {key, quote do: unquote(mod).t}
    end)
  end

  @doc false
  def fields_with_accept_case(field_mod_pairs, accept_case) do
    f =
      case accept_case do
        nil          -> fn a -> a end
        :snake       -> &Macro.underscore/1
        :lower_camel -> &lower_camelize/1
        :upper_camel -> &Macro.camelize/1
        :capital     -> &String.upcase/1
        _            -> raise ":accept_case option must be :lower_camel, :upper_camel, :snake or :capital"
      end
    fields2 =
      Enum.map(field_mod_pairs, fn {key, mod} ->
        key2 = Atom.to_string(key) |> f.() |> String.to_atom()
        {key, Enum.uniq([key, key2]), mod}
      end)
    accepted_keys = Enum.flat_map(fields2, fn {_, keys, _} -> keys end)
    if length(accepted_keys) != length(Enum.uniq(accepted_keys)) do
      raise "field names are not unique"
    end
    fields2
  end

  defp lower_camelize(s) do
    if byte_size(s) == 0 do
      ""
    else
      c = Macro.camelize(s)
      String.downcase(String.first(c)) <> String.slice(c, 1..-1)
    end
  end

  # This is named as `new_impl2/4` just for historical reason (there had been `new_impl/4`).
  @doc false
  def new_impl2(struct_mod, struct_fields_with_defaults, dict, recursive?) when is_list(dict) or is_map(dict) do
    Enum.map(struct_fields_with_defaults, fn {field, fields_to_fetch, field_mod, default} ->
      case dict_fetch2(dict, fields_to_fetch) do
        {:ok, v1} ->
          evaluate_existing_field(field_mod, v1, field, recursive?)
          |> case do
            {:ok, v2}                               -> {:ok, {field, v2}}
            {:error, {reason, [^field_mod | mods]}} -> {:error, {reason, [{field_mod, field} | mods]}}
            {:error, reason}                        -> {:error, reason}
          end
        :error ->
          case default do
            {:ok, d} -> {:ok, {field, d}}
            :error   -> {:error, {:value_missing, [{field_mod, field}]}}
          end
      end
    end)
    |> R.sequence()
    |> case do
      {:ok, kvs}       -> {:ok, struct_mod.__struct__(kvs)}
      {:error, reason} -> {:error, R.ErrorReason.add_context(reason, struct_mod)}
    end
  end
  def new_impl2(mod, _struct_fields_with_defaults, _not_a_dict, _recursive?) do
    {:error, {:invalid_value, [mod]}}
  end

  defp evaluate_existing_field(mod, value, field, false), do: wrap_if_valid(value, mod, field)
  defp evaluate_existing_field(mod, value, field, true ), do: wrap_if_valid(value, mod, field) |> R.or_else(try_new1_with_given_value(value, mod, field))

  defp wrap_if_valid(value, mod, field) do
    case mod.valid?(value) do
      true  -> {:ok, value}
      false -> {:error, {:invalid_value, [{mod, field}]}}
    end
  end

  defp try_new1_with_given_value(value, mod, field) do
    try do
      mod.new(value)
    rescue
      _ -> {:error, {:invalid_value, [{mod, field}]}}
    end
  end

  @doc false
  def update_impl(s, mod, struct_fields, dict) when is_list(dict) or is_map(dict) do
    Enum.map(struct_fields, fn {field, fields_to_fetch, mod} ->
      case dict_fetch2(dict, fields_to_fetch) do
        {:ok, v} -> wrap_if_valid(v, mod, field) |> R.map(&{field, &1})
        :error   -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> R.sequence()
    |> case do
      {:ok   , kvs   } -> {:ok, struct(s, kvs)}
      {:error, reason} -> {:error, R.ErrorReason.add_context(reason, mod)}
    end
  end

  defp dict_fetch2(dict, keys) do
    case keys do
      [key]        -> dict_fetch2_impl(dict, key)
      [key1, key2] ->
        case dict_fetch2_impl(dict, key1) do
          {:ok, _} = r -> r
          :error       -> dict_fetch2_impl(dict, key2)
        end
    end
  end
  defp dict_fetch2_impl(dict, key) when is_list(dict) do
    key_str = Atom.to_string(key)
    Enum.find_value(dict, :error, fn
      {k, v} when k == key or k == key_str -> {:ok, v}
      _                                    -> nil
    end)
  end
  defp dict_fetch2_impl(dict, key) when is_map(dict) do
    case Map.fetch(dict, key) do
      {:ok, _} = r -> r
      :error       -> Map.fetch(dict, Atom.to_string(key))
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      fields =
        Keyword.fetch!(opts, :fields)
        |> Enum.map(fn
          {f, {m, field_opts}} -> {f, {m, field_opts}}
          {f, m              } -> {f, {m, []}}
        end)
      field_default_pairs = Croma.Struct.field_default_value_pairs(fields)

      @croma_struct_field_mod_pairs      Enum.map(fields, fn {f, {m, _}} -> {f, m} end)
      @croma_struct_fields               Croma.Struct.fields_with_accept_case(@croma_struct_field_mod_pairs, opts[:accept_case])
      @croma_struct_fields_with_defaults Enum.zip(@croma_struct_fields, field_default_pairs) |> Enum.map(fn {{f, fs, m}, {f, d}} -> {f, fs, m, d} end)

      @enforce_keys Enum.filter(field_default_pairs, &match?({_, :error}, &1)) |> Enum.map(fn {f, _} -> f end)
      defstruct (
        Enum.map(field_default_pairs, fn
          {f, {:ok, d}} -> {f, d}
          {f, :error  } -> {f, nil}
        end)
      )
      @type t :: %__MODULE__{unquote_splicing(Croma.Struct.field_type_pairs(@croma_struct_field_mod_pairs))}

      if opts[:recursive_new?] do
        @doc """
        Creates a new instance of #{inspect(__MODULE__)} by using the given `dict`.

        Returns `{:ok, valid_struct}` or `{:error, reason}`.

        The values in the `dict` are validated by each field's `valid?/1` function.
        If the value was invalid, it will be passed to `new/1` of the field

        For missing fields, followings will be tried:
        - `default/0` of each field type
        - `new/1` of each field type, with empty map as input
        """
        defun new(dict :: term) :: R.t(t) do
          Croma.Struct.new_impl2(__MODULE__, @croma_struct_fields_with_defaults, dict, true)
        end
      else
        @doc """
        Creates a new instance of #{inspect(__MODULE__)} by using the given `dict`.

        For missing fields, `default/0` of each field type will be used.

        Returns `{:ok, valid_struct}` or `{:error, reason}`.
        The values in the `dict` are validated by each field's `valid?/1` function.
        """
        defun new(dict :: term) :: R.t(t) do
          Croma.Struct.new_impl2(__MODULE__, @croma_struct_fields_with_defaults, dict, false)
        end
      end

      @doc """
      A variant of `new/1` which returns `t` or raise if validation fails.

      In other words, `new/1` followed by `Croma.Result.get!/1`.
      """
      defun new!(dict :: term) :: t do
        new(dict) |> R.get!()
      end

      Enum.each(@croma_struct_field_mod_pairs, fn {name, mod} ->
        @doc """
        Type-aware getter for #{name}.
        """
        @spec unquote(name)(t) :: unquote(mod).t
        def unquote(name)(%__MODULE__{unquote(name) => field}) do
          field
        end

        @doc """
        Type-aware setter for #{name}.
        """
        @spec unquote(name)(t, unquote(mod).t) :: t
        def unquote(name)(s, field) do
          %__MODULE__{s | unquote(name) => field}
        end
      end)

      @doc """
      Checks if the given value belongs to `t:t/0` or not.
      """
      defun valid?(value :: term) :: boolean do
        %__MODULE__{} = s ->
          Enum.all?(@croma_struct_field_mod_pairs, fn {field, mod} ->
            mod.valid?(Map.fetch!(s, field))
          end)
        _ -> false
      end

      @doc """
      Updates an existing instance of #{inspect(__MODULE__)} with the given `dict`.
      The values in the `dict` are validated by each field's `valid?/1` function.
      Returns `{:ok, valid_struct}` or `{:error, reason}`.
      """
      defun update(%__MODULE__{} = s :: t, dict :: Dict.t) :: R.t(t) do
        Croma.Struct.update_impl(s, __MODULE__, @croma_struct_fields, dict)
      end

      @doc """
      A variant of `update/2` which returns `t` or raise if validation fails.
      In other words, `update/2` followed by `Croma.Result.get!/1`.
      """
      defun update!(s :: t, dict :: Dict.t) :: t do
        update(s, dict) |> R.get!()
      end

      defoverridable [valid?: 1, new: 1, new!: 1, update: 2, update!: 2]
    end
  end
end
