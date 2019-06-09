defmodule ResponseTest do
  use ExUnit.Case
  alias Modbus.Response

  test "Response pack and parse test" do
    pp(<<0x22, 0x01, 0x01, 0x00>>, {:rc, 0x22, 0x2324, 1}, [0])
    pp(<<0x22, 0x01, 0x01, 0x01>>, {:rc, 0x22, 0x2324, 1}, [1])
    pp(<<0x22, 0x02, 0x01, 0x00>>, {:ri, 0x22, 0x2324, 1}, [0])
    pp(<<0x22, 0x02, 0x01, 0x01>>, {:ri, 0x22, 0x2324, 1}, [1])
    pp(<<0x22, 0x03, 0x02, 0x25, 0x26>>, {:rhr, 0x22, 0x2324, 1}, [0x2526])
    pp(<<0x22, 0x04, 0x02, 0x25, 0x26>>, {:rir, 0x22, 0x2324, 1}, [0x2526])
    pp(<<0x22, 0x05, 0x23, 0x24, 0x00, 0x00>>, {:fc, 0x22, 0x2324, 0}, nil)
    pp(<<0x22, 0x05, 0x23, 0x24, 0xFF, 0x00>>, {:fc, 0x22, 0x2324, 1}, nil)
    pp(<<0x22, 0x06, 0x23, 0x24, 0x25, 0x26>>, {:phr, 0x22, 0x2324, 0x2526}, nil)
    pp(<<0x22, 0x0F, 0x23, 0x24, 0x00, 0x01>>, {:fc, 0x22, 0x2324, [0]}, nil)
    pp(<<0x22, 0x10, 0x23, 0x24, 0x00, 0x01>>, {:phr, 0x22, 0x2324, [0x2526]}, nil)
    # corner cases
    pp(<<0x22, 0x01, 0x01, 0x96>>, {:rc, 0x22, 0x2324, 8}, [0, 1, 1, 0, 1, 0, 0, 1])
    pp(<<0x22, 0x01, 0x02, 0x96, 0x01>>, {:rc, 0x22, 0x2324, 9}, [0, 1, 1, 0, 1, 0, 0, 1, 1])

    pp(<<0x22, 0x01, 0x02, 0x96, 0xC3>>, {:rc, 0x22, 0x2324, 16}, [
      0,
      1,
      1,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      0,
      0,
      1,
      1
    ])

    pp(<<0x22, 0x01, 0x03, 0x96, 0xC3, 0x01>>, {:rc, 0x22, 0x2324, 17}, [
      0,
      1,
      1,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      0,
      0,
      1,
      1,
      1
    ])

    pp(<<0x22, 0x01, 0xFF>> <> l2b1(bls(2040)), {:rc, 0x22, 0x2324, 2040}, bls(2040))
    pp(<<0x22, 0x02, 0x01, 0x96>>, {:ri, 0x22, 0x2324, 8}, [0, 1, 1, 0, 1, 0, 0, 1])
    pp(<<0x22, 0x02, 0x02, 0x96, 0x01>>, {:ri, 0x22, 0x2324, 9}, [0, 1, 1, 0, 1, 0, 0, 1, 1])

    pp(<<0x22, 0x02, 0x02, 0x96, 0xC3>>, {:ri, 0x22, 0x2324, 16}, [
      0,
      1,
      1,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      0,
      0,
      1,
      1
    ])

    pp(<<0x22, 0x02, 0x03, 0x96, 0xC3, 0x01>>, {:ri, 0x22, 0x2324, 17}, [
      0,
      1,
      1,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      0,
      0,
      1,
      1,
      1
    ])

    pp(<<0x22, 0x02, 0xFF>> <> l2b1(bls(2040)), {:ri, 0x22, 0x2324, 2040}, bls(2040))
    pp(<<0x22, 0x03, 0xFE>> <> l2b16(rls(127)), {:rhr, 0x22, 0x2324, 127}, rls(127))
    pp(<<0x22, 0x04, 0xFE>> <> l2b16(rls(127)), {:rir, 0x22, 0x2324, 127}, rls(127))
    # invalid cases
    assert <<0x22, 0x01, 0x00>> <> l2b1(bls(2041)) == Response.pack({:rc, 0x22, 0x2324, 2041}, bls(2041))
    assert <<0x22, 0x02, 0x00>> <> l2b1(bls(2041)) == Response.pack({:ri, 0x22, 0x2324, 2041}, bls(2041))
    assert <<0x22, 0x03, 0x00>> <> l2b16(rls(128)) == Response.pack({:rhr, 0x22, 0x2324, 128}, rls(128))
    assert <<0x22, 0x04, 0x00>> <> l2b16(rls(128)) == Response.pack({:rir, 0x22, 0x2324, 128}, rls(128))
  end

  defp pp(packet, cmd, vals) do
    assert packet == Response.pack(cmd, vals)
    assert Response.length(cmd) == byte_size(packet)
    assert vals == Response.parse(cmd, packet)
  end

  defp bls(size) do
    for i <- 1..size do
      rem(i, 2)
    end
  end

  defp rls(size) do
    for i <- 1..size do
      i
    end
  end

  defp l2b1(list) do
    lists = Enum.chunk(list, 8, 8, [0, 0, 0, 0, 0, 0, 0, 0])

    list =
      for [v0, v1, v2, v3, v4, v5, v6, v7] <- lists do
        <<v7::1, v6::1, v5::1, v4::1, v3::1, v2::1, v1::1, v0::1>>
      end

    :erlang.iolist_to_binary(list)
  end

  defp l2b16(list) do
    list2 =
      for i <- list do
        <<i::16>>
      end

    :erlang.iolist_to_binary(list2)
  end
end
