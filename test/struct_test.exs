defmodule Croma.StructTest do
  use ExUnit.Case

  defmodule EmptyStructShouldBeSuccessfullyCompiled do
    use Croma.Struct, fields: []
  end

  defmodule I1 do
    use Croma.SubtypeOfInt, min: 0, max: 10, default: 0
  end

  defmodule S1 do
    use Croma.Struct, fields: [field1: I1, field2: Croma.Boolean]

    # getter for compile-time typespec information
    type = Croma.TypeUtil.fetch_type_info_at_compile_time(__MODULE__, :type) |> Macro.escape()
    def type(), do: unquote(type)
  end

  test "Croma.Struct: new/1" do
    assert S1.new(nil) == {:error, {:invalid_value, [S1]}}

    assert S1.new( []                             ) == {:error, {:value_missing, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new(%{}                             ) == {:error, {:value_missing, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new( [ field1:    2]                ) == {:error, {:value_missing, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new(%{ field1:    2}                ) == {:error, {:value_missing, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new(%{"field1" => 2}                ) == {:error, {:value_missing, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new( [                 field2:    2]) == {:error, {:invalid_value, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new(%{                 field2:    2}) == {:error, {:invalid_value, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new(%{                "field2" => 2}) == {:error, {:invalid_value, [S1, {Croma.Boolean, :field2}]}}
    assert S1.new( [ field1:    -1,  field2:    2]) == {:error, {:invalid_value, [S1, {I1, :field1}]}}
    assert S1.new(%{ field1:    -1,  field2:    2}) == {:error, {:invalid_value, [S1, {I1, :field1}]}}
    assert S1.new(%{"field1" => -1, "field2" => 2}) == {:error, {:invalid_value, [S1, {I1, :field1}]}}

    assert S1.new( [                 field2:    true ]) == {:ok, %S1{field1: 0, field2: true }}
    assert S1.new(%{                 field2:    false}) == {:ok, %S1{field1: 0, field2: false}}
    assert S1.new(%{                "field2" => true }) == {:ok, %S1{field1: 0, field2: true }}
    assert S1.new( [ field1:     2,  field2:    false]) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.new(%{ field1:     2,  field2:    true }) == {:ok, %S1{field1: 2, field2: true }}
    assert S1.new(%{"field1" =>  2, "field2" => false}) == {:ok, %S1{field1: 2, field2: false}}

    assert S1.new!([field2: true]) == %S1{field1: 0, field2: true}
    catch_error S1.new!([])
  end

  test "Croma.Struct: getter and setter" do
    s1 = S1.new!(field1: 0, field2: true)
    assert S1.field1(s1) == 0
    assert S1.field2(s1) == true
    s2 = S1.field1(s1, 1)
    assert S1.field1(s2) == 1
    assert S1.field2(s2) == true
    s3 = S1.field2(s2, false)
    assert S1.field1(s3) == 1
    assert S1.field2(s3) == false
  end

  test "Croma.Struct: valid?/1" do
    refute S1.valid?( [                                 ])
    refute S1.valid?(%{                                 })
    refute S1.valid?( [ field1:    2                    ])
    refute S1.valid?(%{"field1" => 2                    })
    refute S1.valid?( [                 field2:    true ])
    refute S1.valid?(%{                "field2" => false})
    refute S1.valid?( [ field1:    -1,  field2:    true ])
    refute S1.valid?(%{"field1" => -1, "field2" => false})
    refute S1.valid?( [ field1:     1,  field2:    0    ])
    refute S1.valid?(%{"field1" =>  1, "field2" => 0    })
    refute S1.valid?(nil)
    refute S1.valid?("" )

    refute S1.valid?( [ field1:     1,  field2:    true ])
    refute S1.valid?(%{"field1" =>  1, "field2" => false})
    assert S1.valid?(S1.new!( [ field1:     1,  field2:    true ]))
    assert S1.valid?(S1.new!(%{"field1" =>  1, "field2" => false}))

    # struct itself should be valid
    s = S1.new!(field2: false)
    assert S1.valid?(s)

    assert S1.new!([field1: 1, field2: true]) == %S1{field1: 1, field2: true}
    catch_error S1.new!([])
  end

  test "Croma.Struct: update/2" do
    s = S1.new!(field1: 1, field2: false)
    assert S1.update(s,  []) == {:ok, s}
    assert S1.update(s, %{}) == {:ok, s}

    assert S1.update(s,  [ field1:    2                  ]) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.update(s, %{"field1" => 2                  }) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.update(s,  [                field2:    true]) == {:ok, %S1{field1: 1, field2: true }}
    assert S1.update(s, %{               "field2" => true}) == {:ok, %S1{field1: 1, field2: true }}
    assert S1.update(s,  [ field1:    2,  field2:    true]) == {:ok, %S1{field1: 2, field2: true }}
    assert S1.update(s, %{"field1" => 2, "field2" => true}) == {:ok, %S1{field1: 2, field2: true }}

    assert S1.update(s,  [ field1:    -1,                ]) == {:error, {:invalid_value, [S1, {I1, :field1}]}}
    assert S1.update(s, %{"field1" => -1,                }) == {:error, {:invalid_value, [S1, {I1, :field1}]}}
    assert S1.update(s,  [                 field2:    0  ]) == {:error, {:invalid_value, [S1, {Croma.Boolean, :field2}]}}
    assert S1.update(s, %{                "field2" => nil}) == {:error, {:invalid_value, [S1, {Croma.Boolean, :field2}]}}
    assert S1.update(s,  [ field1:    -1,  field2:    0  ]) == {:error, {:invalid_value, [S1, {I1, :field1}]}}
    assert S1.update(s, %{"field1" => -1, "field2" => nil}) == {:error, {:invalid_value, [S1, {I1, :field1}]}}

    assert S1.update(s, [nonexisting: 0]) == {:ok, s}

    # reject different type of struct
    catch_error S1.update(%{}, %{})
    catch_error S1.update(%Regex{}, %{})

    assert S1.update!(s, []) == s
    catch_error S1.update!(s, [field1: "hello"])
  end

  defmodule S2 do
    use Croma.Struct, fields: [int_field: I1, bool_field: Croma.Boolean], accept_case: :lower_camel
  end

  test "Croma.Struct with lower camel case" do
    assert S2.new(bool_field: true) == {:ok, %S2{int_field: 0, bool_field: true}}
    assert S2.new(boolField:  true) == {:ok, %S2{int_field: 0, bool_field: true}}
    assert S2.new(BoolField:  true) == {:error, {:value_missing, [S2, {Croma.Boolean, :bool_field}]}}
    assert S2.new(BOOL_FIELD: true) == {:error, {:value_missing, [S2, {Croma.Boolean, :bool_field}]}}
  end

  defmodule S3 do
    use Croma.Struct, fields: [int_field: I1, bool_field: Croma.Boolean], accept_case: :upper_camel
  end

  test "Croma.Struct with upper camel case" do
    assert S3.new(%{bool_field: true}) == {:ok, %S3{int_field: 0, bool_field: true}}
    assert S3.new(%{BoolField:  true}) == {:ok, %S3{int_field: 0, bool_field: true}}
    assert S3.new(%{boolField:  true}) == {:error, {:value_missing, [S3, {Croma.Boolean, :bool_field}]}}
    assert S3.new(%{BOOL_FIELD: true}) == {:error, {:value_missing, [S3, {Croma.Boolean, :bool_field}]}}
  end

  defmodule S4 do
    use Croma.Struct, fields: [intField: I1, boolField: Croma.Boolean], accept_case: :snake
  end

  test "Croma.Struct with snake case" do
    assert S4.new(%{"bool_field" => true}) == {:ok, %S4{intField: 0, boolField: true}}
    assert S4.new(%{"boolField"  => true}) == {:ok, %S4{intField: 0, boolField: true}}
    assert S4.new(%{"BoolField"  => true}) == {:error, {:value_missing, [S4, {Croma.Boolean, :boolField}]}}
    assert S4.new(%{"BOOL_FIELD" => true}) == {:error, {:value_missing, [S4, {Croma.Boolean, :boolField}]}}
  end

  defmodule S5 do
    use Croma.Struct, fields: [int_field: I1, bool_field: Croma.Boolean], accept_case: :capital
  end

  test "Croma.Struct with capital case" do
    assert S5.new(%{"bool_field" => true}) == {:ok, %S5{int_field: 0, bool_field: true}}
    assert S5.new(%{"BOOL_FIELD" => true}) == {:ok, %S5{int_field: 0, bool_field: true}}
    assert S5.new(%{"boolField"  => true}) == {:error, {:value_missing, [S5, {Croma.Boolean, :bool_field}]}}
    assert S5.new(%{"BoolField"  => true}) == {:error, {:value_missing, [S5, {Croma.Boolean, :bool_field}]}}
  end

  defmodule S6 do
    use Croma.Struct, fields: [int_field: I1]
  end

  defmodule S7 do
    use Croma.Struct, fields: [struct_field: S6]
  end

  defmodule S8 do
    use Croma.Struct, fields: [bool_field: Croma.Boolean, struct_field: S6]
  end

  test "Croma.Struct with fields' new/1 defined" do
    assert S7.new( [ struct_field:     [ int_field:    1]]) == {:ok, %S7{struct_field: %S6{int_field: 1}}}
    assert S7.new(%{"struct_field" => %{"int_field" => 1}}) == {:ok, %S7{struct_field: %S6{int_field: 1}}}
    assert S7.new(%{"struct_field" => %{}}                ) == {:ok, %S7{struct_field: %S6{int_field: 0}}}

    assert S7.new(%{}                                             ) == {:error, {:value_missing, [S7, {S6, :struct_field}]}}
    assert S7.new(%{"struct_field" => %{"int_field" => "non int"}}) == {:error, {:invalid_value, [S7, {S6, :struct_field}, {I1, :int_field}]}}
    assert S7.new(%{"struct_field" => "non_dict"}                 ) == {:error, {:invalid_value, [S7, {S6, :struct_field}]}}

    assert S8.new(%{"bool_field" => true, struct_field: %{"int_field" => 0}}) == {:ok, %S8{bool_field: true, struct_field: %S6{int_field: 0}}}
    assert S8.new(%{"bool_field" => true}                                   ) == {:error, {:value_missing, [S8, {S6, :struct_field}]}}
    assert S8.new(%{}                                                       ) == {:error, {:value_missing, [S8, {Croma.Boolean, :bool_field}]}}
  end

  defmodule S9 do
    defmodule A do
      use Croma.SubtypeOfAtom, values: [:a, :b]
    end
    use Croma.Struct, fields: [f: A]
  end

  test "Croma.Struct having field with `new/1` and value_missing" do
    assert S9.new([]) == {:error, {:value_missing, [S9, {S9.A, :f}]}}
  end

  defmodule S10 do
    defmodule I do
      use Croma.SubtypeOfInt, min: 0, default: 1
    end
    use Croma.Struct, fields: [
      a: Croma.Integer,
      b: I,
      c: {Croma.Integer, [default: 2]},
      d: {I            , [default: 3]},
      e: {Croma.Integer, [no_default?: true]},
      f: {I            , [no_default?: true]},
    ]
  end

  test "Croma.Struct should correctly use the given default value" do
    s10 = %S10{a: 0, b: 1, c: 2, d: 3, e: 4, f: 5}
    assert %S10{a: 0, e: 4, f: 5}       == s10
    assert S10.new(%{a: 0, e: 4, f: 5}) == {:ok, s10}

    catch_error S10.__struct__([])
    catch_error S10.__struct__([a: 0, e: 4      ])
    catch_error S10.__struct__([a: 0,       f: 5])
    catch_error S10.__struct__([      e: 4, f: 5])
  end

  test "Croma.Struct should reject invalid default value" do
    catch_error (
      defmodule S11 do
        use Croma.Struct, fields: [i: {Croma.Integer, [default: nil]}]
      end
    )
  end

  test "Croma.Struct should reject field having both :default and :no_default?" do
    catch_error (
      defmodule S12 do
        use Croma.Struct, fields: [i: {Croma.Integer, [default: 0, no_default?: true]}]
      end
    )
  end

  defmodule S13 do
    import Croma.TypeGen
    use Croma.Struct, fields: [
      f1: {union([fixed(:unset), fixed(nil), Croma.Integer]), [default: :unset]},
      f2: {union([fixed(:unset), nilable(Croma.Integer)]), [default: :unset]},
    ]
  end

  test "Croma.Struct with default :unset and nilable field" do
    assert S13.new(%{                }) == {:ok, %S13{f1: :unset, f2: :unset}}
    assert S13.new(%{f1: nil, f2: nil}) == {:ok, %S13{f1: nil   , f2: nil   }}
    assert S13.new(%{f1: 1  , f2: 2  }) == {:ok, %S13{f1: 1     , f2: 2     }}
  end
end
