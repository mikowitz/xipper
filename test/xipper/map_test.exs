defmodule Xipper.MapTest do
  use ExUnit.Case, async: true

  setup do
    is_branch = fn x -> is_map(x) && Map.has_key?(x, :children) end
    children = fn x -> x[:children] end
    make_node = fn
      x = %{children: _}, children -> %{x | children: children}
      x, children -> Map.put(x, :children, children)
    end
    root = %{name: "a", children: [
      %{name: "b"},
      %{name: "c", children: [
        %{name: "d"},
        %{name: "e"}
      ]}
    ]}
    zipper = Xipper.new(root, is_branch, children, make_node)
    {:ok, %{zipper: zipper, root: root}}
  end

  describe "new/4" do
    test "takes 3 functions and a root and returns a zipper focused on that root", %{zipper: zipper, root: root} do
      assert zipper.focus == root
      assert zipper.left == []
      assert zipper.right == []
      assert zipper.parents == []
    end
  end

  test "down/1", %{zipper: zipper, root: root} do
    z = Xipper.down(zipper)
    assert z.focus == %{name: "b"}
    assert z.left == []
    assert z.right == [%{name: "c", children: [%{name: "d"}, %{name: "e"}]}]
    assert z.parents == [[focus: root, left: [], right: []]]
  end

  test "up/1", %{zipper: zipper, root: root} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.down |> Xipper.right

    assert z.focus == %{name: "e"}

    z = Xipper.up(z)

    assert z.focus[:name] == "c"
    assert z.left == [%{name: "b"}]
    assert z.right == []
    assert z.parents == [[focus: root, left: [], right: []]]
  end

  test "root/1", %{zipper: zipper, root: root} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.down |> Xipper.right

    assert z.focus == %{name: "e"}

    z = Xipper.root(z)

    assert z.focus == root
  end

  test "rights/1", %{zipper: zipper} do
    z = Xipper.down(zipper)

    assert Xipper.rights(z) == [%{name: "c", children: [%{name: "d"}, %{name: "e"}]}]
  end

  test "append_child/2", %{zipper: zipper} do
    z = Xipper.append_child(zipper, %{name: "f"})

    assert z.focus == %{name: "a", children: [
      %{name: "b"},
      %{name: "c", children: [
        %{name: "d"},
        %{name: "e"}
      ]},
      %{name: "f"}
    ]}
  end

  test "is_branch/1", %{zipper: zipper} do
    assert Xipper.is_branch(zipper)

    refute zipper |> Xipper.next |> Xipper.is_branch
  end

  test "children/1", %{zipper: zipper} do
    assert Xipper.children(zipper) |> Enum.map(&(&1[:name])) == ["b", "c"]

    assert (zipper |> Xipper.next |> Xipper.next |> Xipper.children) == [
      %{name: "d"}, %{name: "e"}
    ]
  end

  test "edit", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.edit(fn x = %{children: children} ->
      %{x | children: Enum.map(children, fn c = %{name: name} -> %{c | name: String.upcase(name)} end)}
    end) |> Xipper.root

    assert z.focus == %{name: "a", children: [
      %{name: "b"},
      %{name: "c", children: [
        %{name: "D"},
        %{name: "E"}
      ]}
    ]}
  end

  test "is_end/1", %{zipper: zipper} do
    refute Xipper.is_end(zipper)
    assert Enum.reduce(1..5, zipper, fn _, z ->
      Xipper.next(z)
    end) |> Xipper.is_end
  end

  test "insert_child/2", %{zipper: zipper} do
    z = Xipper.insert_child(zipper, %{name: "Z"})

    assert z.focus == %{name: "a", children: [
      %{name: "Z"},
      %{name: "b"},
      %{name: "c", children: [
        %{name: "d"},
        %{name: "e"}
      ]}
    ]}
  end

  test "insert_left/2", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.insert_left(%{name: "Z"}) |> Xipper.root

    assert z.focus == %{name: "a", children: [
      %{name: "Z"},
      %{name: "b"},
      %{name: "c", children: [
        %{name: "d"},
        %{name: "e"}
      ]}
    ]}
  end

  test "insert_right/2", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.insert_right(%{name: "Z"}) |> Xipper.root

    assert z.focus == %{name: "a", children: [
      %{name: "b"},
      %{name: "Z"},
      %{name: "c", children: [
        %{name: "d"},
        %{name: "e"}
      ]}
    ]}
  end

  test "left/1", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.down |> Xipper.right |> Xipper.left

    assert z.focus == %{name: "d"}
    assert z.left == []
    assert z.right == [%{name: "e"}]
    assert Enum.map(z.parents, &(&1[:focus][:name])) == ["c", "a"]
  end

  test "leftmost/1", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.leftmost

    assert z.focus == %{name: "b"}
  end

  test "lefts/1", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right

    assert Xipper.lefts(z) == [%{name: "b"}]
  end

  test "make_node/3", %{zipper: zipper} do
    assert Xipper.make_node(zipper, %{name: "Z"}, [%{name: "Y"}, %{name: "X"}]) == %{
      name: "Z",
      children: [
        %{name: "Y"},
        %{name: "X"}
      ]
    }
  end

  test "next/1", %{zipper: zipper} do
    z = Xipper.next(zipper)
    assert z.focus == %{name: "b"}
    z = Xipper.next(z)
    assert z.focus[:name] == "c"
    z = Xipper.next(z)
    assert z.focus == %{name: "d"}
    z = Xipper.next(z)
    assert z.focus == %{name: "e"}
  end

  test "focus/1", %{zipper: zipper, root: root} do
    assert Xipper.focus(zipper) == root
  end

  test "path/1", %{zipper: zipper, root: root} do
    assert Xipper.path(zipper) == []

    z = Xipper.down(zipper)
    assert Xipper.path(z) == [root]

    z = zipper |> Xipper.down |> Xipper.right |> Xipper.down
    assert Xipper.path(z) == [root, %{name: "c", children: [%{name: "d"}, %{name: "e"}]}]
  end

  test "prev/1", %{zipper: zipper} do
    z = Enum.reduce(1..4, zipper, fn _, z -> Xipper.next(z) end)
    assert z.focus == %{name: "e"}
    refute Xipper.is_end(z)
    z = Xipper.prev(z)
    assert z.focus == %{name: "d"}
    z = Xipper.prev(z)
    assert z.focus == %{name: "c", children: [%{name: "d"}, %{name: "e"}]}
    z = Xipper.prev(z)
    assert z.focus == %{name: "b"}
  end

  test "remove/1", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.remove

    assert z.focus == %{name: "a", children: [
      %{name: "c", children: [
        %{name: "d"},
        %{name: "e"}
      ]}
    ]}

    z = zipper |> Xipper.down |> Xipper.right |> Xipper.remove |> Xipper.root

    assert z.focus == %{name: "a", children: [
      %{name: "b"}
    ]}
  end

  test "replace/2", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.replace(%{name: "f"}) |> Xipper.root

    assert z.focus == %{name: "a", children: [
      %{name: "b"},
      %{name: "f"}
    ]}
  end

  test "right/1", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.down |> Xipper.right

    assert z.focus == %{name: "e"}
    assert z.left == [%{name: "d"}]
    assert z.right == []
    assert Enum.map(z.parents, &(&1[:focus][:name])) == ["c", "a"]
  end

  test "rightmost/1", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.append_child(%{name: "f"}) |> Xipper.down |> Xipper.rightmost

    assert z.focus == %{name: "f"}
    assert z.left == [%{name: "e"}, %{name: "d"}]
    assert z.right == []
  end
end
