import Croma.Defun
alias Croma.Result, as: R

defmodule Croma.SubtypeOfInt do
  @moduledoc """
  Helper module to define integer-based types.
  The following members are generated by `use Croma.SubtypeOfInt`:

  - `@type t`
  - `@spec valid?(term) :: boolean`

  Options:
  - `:min` - Minimum value of this type (inclusive).
  - `:max` - Maximum value of this type (inclusive).
  - `:default` - Default value for this type. Passing this option generates `default/0`.

  ## Examples
      defmodule MyInt do
        use Croma.SubtypeOfInt, min: 0, max: 10, default: 0
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [min: opts[:min], max: opts[:max], default: opts[:default]] do
      @min min
      @max max
      if !is_nil(@min) and !is_integer(@min), do: raise ":min must be either nil or integer"
      if !is_nil(@max) and !is_integer(@max), do: raise ":max must be either nil or integer"
      if is_nil(@min) and is_nil(@max)      , do: raise ":min and/or :max must be given"
      if @min && @max && @max < @min        , do: raise ":min must be smaller than :max"

      cond do
        is_nil(@min) ->
          cond do
            @max <= -1 -> @type t :: neg_integer
            true       -> @type t :: integer
          end
          defun valid?(term :: any) :: boolean do
            i when is_integer(i) and i <= @max -> true
            _                                  -> false
          end
        is_nil(@max) ->
          cond do
            1 <= @min -> @type t :: pos_integer
            0 == @min -> @type t :: non_neg_integer
            true      -> @type t :: integer
          end
          defun valid?(term :: any) :: boolean do
            i when is_integer(i) and @min <= i -> true
            _                                  -> false
          end
        true ->
          @type t :: unquote(min) .. unquote(max)
          defun valid?(term :: any) :: boolean do
            i when is_integer(i) and @min <= i and i <= @max -> true
            _                                                -> false
          end
      end

      if !is_nil(@min) do
        defun min() :: t, do: @min
      end
      if !is_nil(@max) do
        defun max() :: t, do: @max
      end

      if default do
        @default default
        if !is_integer(@default)            , do: raise ":default must be an integer"
        if !is_nil(@min) and @default < @min, do: raise ":default must be a valid value"
        if !is_nil(@max) and @max < @default, do: raise ":default must be a valid value"
        defun default() :: t, do: @default
      end
    end
  end
end

defmodule Croma.SubtypeOfFloat do
  @moduledoc """
  Helper module to define float-based types.
  The following members are generated by `use Croma.SubtypeOfFloat`:

  - `@type t`
  - `@spec valid?(term) :: boolean`

  Options:
  - `:min` - Minimum value of this type (inclusive).
  - `:max` - Maximum value of this type (inclusive).
  - `:default` - Default value for this type. Passing this option generates `default/0`.

  ## Examples
      defmodule MyFloat do
        use Croma.SubtypeOfFloat, min: 0.0, max: 5.0, default: 0.0
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [min: opts[:min], max: opts[:max], default: opts[:default]] do
      @min min
      @max max
      if !is_nil(@min) and !is_float(@min), do: raise ":min must be either nil or float"
      if !is_nil(@max) and !is_float(@max), do: raise ":max must be either nil or float"
      if is_nil(@min) and is_nil(@max)    , do: raise ":min and/or :max must be given"
      if @min && @max && @max < @min      , do: raise ":min must be smaller than :max"

      @type t :: float
      cond do
        is_nil(@min) ->
          defun valid?(term :: any) :: boolean do
            f when is_float(f) and f <= @max -> true
            _                                -> false
          end
        is_nil(@max) ->
          defun valid?(term :: any) :: boolean do
            f when is_float(f) and @min <= f -> true
            _                                -> false
          end
        true ->
          defun valid?(term :: any) :: boolean do
            f when is_float(f) and @min <= f and f <= @max -> true
            _                                              -> false
          end
      end

      if !is_nil(@min) do
        defun min() :: t, do: @min
      end
      if !is_nil(@max) do
        defun max() :: t, do: @max
      end

      if default do
        @default default
        if !is_float(@default)              , do: raise ":default must be a float"
        if !is_nil(@min) and @default < @min, do: raise ":default must be a valid value"
        if !is_nil(@max) and @max < @default, do: raise ":default must be a valid value"
        defun default() :: t, do: @default
      end
    end
  end
end

defmodule Croma.SubtypeOfString do
  @moduledoc """
  Helper module to define string-based types.
  The following members are generated by `use Croma.SubtypeOfString`:

  - `@type t`
  - `@spec valid?(term) :: boolean`

  Options:
  - `:pattern` - A regex pattern to check whether a string is classified into this type or not.
  - `:default` - Default value for this type. Passing this option generates `default/0`.

  ## Examples
      defmodule MyString do
        use Croma.SubtypeOfString, pattern: ~r/^foo|bar$/, default: "foo"
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [pattern: opts[:pattern], default: opts[:default]] do
      @pattern pattern
      if !Regex.regex?(@pattern), do: raise ":pattern must be a regex"
      def pattern(), do: @pattern

      @type t :: String.t

      defun valid?(s :: term) :: boolean do
        s when is_binary(s) -> Regex.match?(@pattern, s)
        _                   -> false
      end

      if default do
        @default default
        if !Regex.match?(@pattern, @default), do: raise ":default must be a valid string"
        defun default() :: t, do: @default
      end
    end
  end
end

defmodule Croma.SubtypeOfAtom do
  @moduledoc """
  Helper module to define type whose members are a fixed set of atoms.
  The following members are generated by `use Croma.SubtypeOfAtom`:

  - `@type t`
  - `@spec valid?(term) :: boolean`
  - `@spec new(term) :: Croma.Result.t(t)` (tries to convert `String.t` to the given set of atoms)
  - `@spec new!(term) :: t`

  Options:
  - `:values` - List of atoms of possible values.
  - `:default` - Default value for this type. Passing this option generates `default/0`.

  ## Examples
      defmodule MyAtom do
        use Croma.SubtypeOfAtom, values: [:foo, :bar, :baz], default: :foo
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [values: opts[:values], default: opts[:default]] do
      @values values
      if is_nil(@values) or Enum.empty?(@values), do: raise ":values must be present"
      def values(), do: @values

      @value_strings Enum.map(@values, &Atom.to_string/1)

      @type t :: unquote(Croma.TypeUtil.list_to_type_union(@values))

      defun valid?(term :: any) :: boolean do
        a when is_atom(a) -> a in @values
        _                 -> false
      end

      defun new(term :: any) :: R.t(t) do
        a when is_atom(a) ->
          if a in @values do
            {:ok, a}
          else
            {:error, {:invalid_value, [__MODULE__]}}
          end
        s when is_binary(s) ->
          if s in @value_strings do
            {:ok, String.to_existing_atom(s)}
          else
            {:error, {:invalid_value, [__MODULE__]}}
          end
        _ -> {:error, {:invalid_value, [__MODULE__]}}
      end

      defun new!(term :: any) :: t do
        new(term) |> R.get!()
      end

      if default do
        @default default
        if !Enum.member?(@values, @default), do: raise ":default must be a valid atom"
        defun default() :: t, do: @default
      end
    end
  end
end

defmodule Croma.SubtypeOfList do
  @moduledoc """
  Helper module to define list-based types.
  The following members are generated by `use Croma.SubtypeOfList`:

  - `@type t`
  - `@spec valid?(term) :: boolean`
  - If `elem_module` exports `new/1`,
      - `@spec new(term) :: Croma.Result.t(t)`
      - `@spec new!(term) :: t`

  Options:
  - `:elem_module` - A type module for elements.
  - `:min_length` - Minimum length of valid values of this type (inclusive).
  - `:max_length` - Maximum length of valid values of this type (inclusive).
  - `:default` - Default value for this type. Passing this option generates `default/0`.

  ## Examples
      defmodule MyList do
        use Croma.SubtypeOfList, elem_module: MyInt, default: []
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [mod: opts[:elem_module], min: opts[:min_length], max: opts[:max_length], default: opts[:default]] do
      @mod mod
      @type t :: [unquote(@mod).t]

      @min min
      @max max
      cond do
        is_nil(@min) and is_nil(@max) ->
          defmacrop valid_length?(_), do: true
        is_nil(@min) ->
          defmacrop valid_length?(len) do
            quote do: unquote(len) <= @max
          end
        is_nil(@max) ->
          defmacrop valid_length?(len) do
            quote do: @min <= unquote(len)
          end
        true ->
          defmacrop valid_length?(len) do
            quote do: @min <= unquote(len) and unquote(len) <= @max
          end
      end

      defun valid?(term :: any) :: boolean do
        l when is_list(l) and valid_length?(length(l)) -> Enum.all?(l, fn v -> @mod.valid?(v) end)
        _                                              -> false
      end

      # Invoking `module_info/1` on `mod` automatically compiles and loads the module if necessary.
      if {:new, 1} in @mod.module_info(:exports) do
        defun new(term :: any) :: R.t(t) do
          l when is_list(l) and valid_length?(length(l)) ->
            result = Enum.map(l, &@mod.new/1) |> R.sequence()
            case result do
              {:ok, _}         -> result
              {:error, reason} -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
            end
          _ -> {:error, {:invalid_value, [__MODULE__]}}
        end

        defun new!(term :: any) :: t do
          new(term) |> R.get!()
        end
      end

      if !is_nil(@min) do
        defun min_length() :: non_neg_integer, do: @min
      end
      if !is_nil(@max) do
        defun max_length() :: non_neg_integer, do: @max
      end

      if default do
        @default default
        if Enum.any?(@default, fn e -> !@mod.valid?(e) end), do: raise ":default must be a valid list"
        len = length(@default)
        if !is_nil(@min) and len < @min, do: raise ":default is shorter than the given :min_length #{Integer.to_string(@min)}"
        if !is_nil(@max) and @max < len, do: raise ":default is longer than the given :max_length #{Integer.to_string(@max)}"
        defun default() :: t, do: @default
      end
    end
  end
end

defmodule Croma.SubtypeOfMap do
  @moduledoc """
  Helper module to define map-based types.
  The following members are generated by `use Croma.SubtypeOfMap`:

  - `@type t`
  - `@spec valid?(term) :: boolean`
  - If `key_module` and/or `value_module` exports `new/1`,
      - `@spec new(term) :: Croma.Result.t(t)`
      - `@spec new!(term) :: t`

  Options:
  - `:key_module` - A type module for keys.
  - `:value_module` - A type module for values.
  - `:min_size` - Minimum size of valid values of this type (inclusive).
  - `:max_size` - Maximum size of valid values of this type (inclusive).
  - `:default` - Default value for this type. Passing this option generates `default/0`.

  ## Examples
      defmodule MyMap do
        use Croma.SubtypeOfMap, key_module: MyString, value_module: MyInt, default: %{}
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [key_module: opts[:key_module], value_module: opts[:value_module], min_size: opts[:min_size], max_size: opts[:max_size], default: opts[:default]] do
      @key_module   key_module
      @value_module value_module
      if is_nil(@key_module  ), do: raise ":key_module must be given"
      if is_nil(@value_module), do: raise ":value_module must be given"

      @type t :: %{unquote(@key_module).t => unquote(@value_module).t}

      @min min_size
      @max max_size
      cond do
        is_nil(@min) and is_nil(@max) ->
          defmacrop valid_size?(_), do: true
        is_nil(@min) ->
          defmacrop valid_size?(size) do
            quote do: unquote(size) <= @max
          end
        is_nil(@max) ->
          defmacrop valid_size?(size) do
            quote do: @min <= unquote(size)
          end
        true ->
          defmacrop valid_size?(size) do
            quote do: @min <= unquote(size) and unquote(size) <= @max
          end
      end

      defun valid?(term :: term) :: boolean do
        m when is_map(m) and valid_size?(map_size(m)) -> Enum.all?(m, fn {k, v} -> @key_module.valid?(k) and @value_module.valid?(v) end)
        _                                             -> false
      end

      # Invoking `module_info/1` automatically compiles and loads the module if necessary.
      module_flag_pairs = Enum.uniq([@key_module, @value_module]) |> Enum.map(fn m -> {m, {:new, 1} in m.module_info(:exports)} end)
      if Enum.any?(module_flag_pairs, fn {_, has_new1} -> has_new1 end) do
        Enum.each(module_flag_pairs, fn {mod, has_new1} ->
          if has_new1 do
            defp __call_new_or_validate(unquote(mod), v) do
              unquote(mod).new(v)
            end
          else
            defp __call_new_or_validate(unquote(mod), v) do
              Croma.Result.wrap_if_valid(v, unquote(mod))
            end
          end
        end)

        defun new(term :: term) :: R.t(t) do
          m when is_map(m) and valid_size?(map_size(m)) ->
            Enum.map(m, fn {k0, v0} ->
              __call_new_or_validate(@key_module, k0) |> R.bind(fn k ->
                __call_new_or_validate(@value_module, v0) |> R.map(fn v ->
                  {k, v}
                end)
              end)
            end)
            |> R.sequence()
            |> case do
              {:ok   , kvs   } -> {:ok, Map.new(kvs)}
              {:error, reason} -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
            end
          _ -> {:error, {:invalid_value, [__MODULE__]}}
        end

        defun new!(term :: any) :: t do
          new(term) |> R.get!()
        end
      end

      if !is_nil(@min) do
        defun min_size() :: non_neg_integer, do: @min
      end
      if !is_nil(@max) do
        defun max_size() :: non_neg_integer, do: @max
      end

      if default do
        @default default
        if !is_map(@default), do: raise ":default must be a map"
        size = map_size(@default)
        if !is_nil(@min) and size < @min, do: raise "items in :default is less than the given :min_size #{Integer.to_string(@min)}"
        if !is_nil(@max) and @max < size, do: raise "items in :default is more than the given :max_size #{Integer.to_string(@max)}"
        any_kv_invalid? =
          !Enum.all?(@default, fn {k, v} ->
            @key_module.valid?(k) and @value_module.valid?(v)
          end)
        if any_kv_invalid?, do: raise ":default must be a valid value of #{inspect(__MODULE__)}"
        defun default() :: t, do: @default
      end
    end
  end
end

defmodule Croma.SubtypeOfTuple do
  @moduledoc """
  Helper module to define tuple-based types.
  The following members are generated by `use Croma.SubtypeOfTuple`:

  - `@type t`
  - `@spec valid?(term) :: boolean`
  - If any of `:elem_modules` exports `new/1`,
      - `@spec new(term) :: Croma.Result.t(t)`
      - `@spec new!(term) :: t`

  Options:
  - `:elem_modules` - A list of type modules for tuple elements.
  - `:default` - Default value for this type. Passing this option generates `default/0`.

  ## Examples
      defmodule MyTuple do
        use Croma.SubtypeOfTuple, elem_modules: [MyInt, MyString]
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [elem_modules: opts[:elem_modules], default: opts[:default]] do
      @elem_modules elem_modules
      if !is_list(@elem_modules), do: raise ":elem_modules must be a list"
      @size length(@elem_modules)

      @type t :: {unquote_splicing(Enum.map(@elem_modules, fn m -> (quote do: unquote(m).t) end))}

      defun valid?(term :: any) :: boolean do
        t when is_tuple(t) and tuple_size(t) == @size -> Enum.zip(Tuple.to_list(t), @elem_modules) |> Enum.all?(fn {elem, mod} -> mod.valid?(elem) end)
        _                                             -> false
      end

      # Invoking `module_info/1` automatically compiles and loads the module if necessary.
      module_flag_pairs = Enum.uniq(@elem_modules) |> Enum.map(fn m -> {m, {:new, 1} in m.module_info(:exports)} end)
      if Enum.any?(module_flag_pairs, fn {_, has_new1} -> has_new1 end) do
        Enum.each(module_flag_pairs, fn {mod, has_new1} ->
          if has_new1 do
            defp __call_new_or_validate(unquote(mod), v) do
              unquote(mod).new(v)
            end
          else
            defp __call_new_or_validate(unquote(mod), v) do
              Croma.Result.wrap_if_valid(v, unquote(mod))
            end
          end
        end)

        defun new(term :: any) :: R.t(t) do
          t when is_tuple(t) and tuple_size(t) == @size ->
            Enum.zip(Tuple.to_list(t), @elem_modules)
            |> Enum.map(fn {elem, mod} -> __call_new_or_validate(mod, elem) end)
            |> R.sequence()
            |> case do
              {:ok   , l     } -> {:ok, List.to_tuple(l)}
              {:error, reason} -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
            end
          _ -> {:error, {:invalid_value, [__MODULE__]}}
        end

        defun new!(term :: any) :: t do
          new(term) |> R.get!()
        end
      end

      if default do
        @default default
        if !is_tuple(@default), do: raise ":default must be a tuple"
        if tuple_size(@default) != @size, do: raise "tuple size of :default is different from the length of :elem_modules"
        any_elem_invalid? =
          Enum.zip(Tuple.to_list(@default), @elem_modules)
          |> Enum.any?(fn {elem, mod} -> !mod.valid?(elem) end)
        if any_elem_invalid?, do: raise ":default must be a valid value of #{inspect(__MODULE__)}"
        defun default() :: t, do: @default
      end
    end
  end
end
