defmodule Croma.ResultTest do
  use Croma.TestCase, alias_as: R
  use ExCheck
  require R

  defp int2result(i) do
    if rem(i, 2) == 0, do: {:ok, i}, else: {:error, i}
  end

  test "Result as Monad" do
    assert R.pure(1) == {:ok, 1}

    assert R.bind({:ok   , 0   }, &int2result/1) == {:ok   , 0   }
    assert R.bind({:ok   , 1   }, &int2result/1) == {:error, 1   }
    assert R.bind({:error, :foo}, &int2result/1) == {:error, :foo}
  end

  test "Result as Functor" do
    assert {:ok   , 1   } |> R.map(&(&1 + 1)) == {:ok   , 2   }
    assert {:error, :foo} |> R.map(&(&1 + 1)) == {:error, :foo}
  end

  test "Result as Applicative" do
    rf = R.pure(fn x -> x + 1 end)
    assert R.ap({:ok   , 1   }, rf) == {:ok   , 2   }
    assert R.ap({:error, :foo}, rf) == {:error, :foo}
  end

  test "Haskell-like do-notation" do
    require R
    r1 = {:ok   , 1   }
    r2 = {:ok   , 2   }
    re = {:error, :foo}

    r = R.m do
    end
    assert r == nil

    r = R.m do
      pure 10
    end
    assert r == {:ok, 10}

    r = R.m do
      a <- r1
      b <- r2
      pure a + b
    end
    assert r == {:ok, 3}

    r = R.m do
      a <- r1
      e <- re
      b <- r2
      pure a + e + b
    end
    assert r == re
  end

  property :sequence do
    for_all l in list(int) do
      result = Enum.map(l, &int2result/1) |> R.sequence
      if Enum.all?(l, &(rem(&1, 2) == 0)) do
        result == {:ok, l}
      else
        result |> elem(0) == :error
      end
    end
  end

  test "get/1 and get/2" do
    assert R.get({:ok   , 1   }) == 1
    assert R.get({:error, :foo}) == nil

    assert R.get({:ok   , 1   }, 0) == 1
    assert R.get({:error, :foo}, 0) == 0
  end

  test "ok?/1 and error?/1" do
    assert  R.ok?({:ok   , 1   })
    assert !R.ok?({:error, :foo})

    assert !R.error?({:ok   , 1   })
    assert  R.error?({:error, :foo})
  end

  test "try/1" do
    f1 = fn -> 1 end
    fe = fn -> raise "foo" end
    assert R.try(f1) == {:ok   , 1}
    assert R.try(fe) == {:error, {%RuntimeError{message: "foo"}, [:try]}}
  end

  test "or_else/2" do
    o1 = {:ok, 1}
    o2 = {:ok, 2}
    e1 = {:error, :foo}
    e2 = {:error, :bar}
    assert R.or_else(o1, o2) == o1
    assert R.or_else(o1, e2) == o1
    assert R.or_else(e1, o2) == o2
    assert R.or_else(e1, e2) == e2

    fo = fn -> send(self, :fo_called); o2 end
    fe = fn -> send(self, :fe_called); e2 end
    assert R.or_else(o1, fo.()) == o1
    refute_receive(_)
    assert R.or_else(o1, fe.()) == o1
    refute_receive(_)
    assert R.or_else(e1, fo.()) == o2
    assert_receive(_)
    assert R.or_else(e1, fe.()) == e2
    assert_receive(_)
  end

  defmodule Bang do
    use Croma
    def f do
      {:ok, 1}
    end
    defun g :: R.t(integer) do
      {:ok, 1}
    end
    defun h(a :: integer) :: R.t(integer) do
      if rem(a, 2) == 0, do: {:ok, a}, else: {:error, :odd}
    end
    defun i :: {:ok, integer} do
      f
    end
    defun j(a :: integer \\ 0) :: {:ok, integer} | {:error, atom} do
      h(a)
    end
    def k do
      {:ok, 1}
    end

    R.define_bang_version_of(f: 0, g: 0, h: 1, i: 0, j: 0, j: 1)
  end

  test "define_bang_version_of" do
    assert      Bang.f! == 1
    assert      Bang.g! == 1
    assert      Bang.h!(2) == 2
    catch_error Bang.h!(1)
    assert      Bang.i! == 1
    assert      Bang.j! == 0
    assert      Bang.j!(2) == 2
    catch_error Bang.j!(1)
    catch_error Bang.k!
  end
end
