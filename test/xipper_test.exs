defmodule XipperTest do
  use ExUnit.Case
  doctest Xipper, only: [:moduledoc, new: 4]

  setup do
    is_branch = &is_list/1
    children = &(&1)
    make_node = fn _, x -> x end
    root = [1,[2], [], [3, [4,5], 6], 7]

    zipper = Xipper.new(root, is_branch, children, make_node)
    {:ok, %{zipper: zipper, root: root}}
  end

  describe "append_child/2" do
    test "adds a child as the rightmost child of the current focus, without shifting focus", %{zipper: zipper} do
      z = Xipper.append_child(zipper, "8")

      assert z.focus == [1,[2],[],[3,[4,5],6],7,"8"]
    end

    test "returns an error when called on a leaf", %{zipper: zipper} do
      assert (zipper |> Xipper.next |> Xipper.append_child(3)) == {:error, :append_child_of_leaf}
    end
  end

  describe "is_branch/1" do
    test "returns true for a node with children", %{zipper: zipper} do
      assert Xipper.is_branch(zipper)
    end

    test "returns false for a node without children", %{zipper: zipper} do
      refute zipper |> Xipper.next |> Xipper.is_branch
    end
  end

  describe "children/1" do
    test "returns the children of a node as defined by the zipper initialization", %{zipper: zipper, root: root} do
      assert Xipper.children(zipper) == root

      assert (zipper |> Xipper.next |> Xipper.next |> Xipper.children) == [2]
    end

    test "a non-branch node returns an error", %{zipper: zipper} do
      assert (zipper |> Xipper.next |> Xipper.children) == {:error, :children_of_leaf}
    end
  end

  describe "down/1" do
    test "down from a branch moves to the leftmost child of the branch", %{zipper: zipper, root: root} do
      z = Xipper.down(zipper)
      assert z.focus == 1
      assert z.left == []
      assert z.right == [[2],[],[3,[4,5],6],7]
      assert z.parents == [[focus: root, left: [], right: []]]
    end

    test "returns an error when called on a leaf", %{zipper: zipper} do
      z = Xipper.down(zipper)

      assert Xipper.down(z) == {:error, :down_from_leaf}
    end
  end

  test "edit", %{zipper: zipper} do
    z = zipper |> Xipper.down |> Xipper.right |> Xipper.edit(fn x ->
      Enum.map(x, &(&1*&1))
    end) |> Xipper.root

    assert z.focus == [1, [4], [], [3,[4,5],6],7]
  end

  test "is_end/1", %{zipper: zipper} do
    refute Xipper.is_end(zipper)
    assert Enum.reduce(1..12, zipper, fn _, z ->
      Xipper.next(z)
    end) |> Xipper.is_end
  end

  describe "insert_child/2" do
    test "adds a child as the leftmost child of the current focus, without shifting focus", %{zipper: zipper} do
      z = Xipper.insert_child(zipper, "8")

      assert z.focus == ["8", 1,[2],[],[3,[4,5],6],7]
    end

    test "returns an error when called on a leaf", %{zipper: zipper} do
      assert zipper |> Xipper.next |> Xipper.insert_child("8") == {:error, :insert_child_of_leaf}
    end
  end

  describe "insert_left/2" do
    test "inserts a new node directly to the left of the current focus, without shifting focus", %{zipper: zipper} do
      z = zipper |> Xipper.down |> Xipper.insert_left(0) |> Xipper.root

      assert z.focus == [0, 1, [2], [], [3, [4,5], 6], 7]
    end

    test "returns an error when called on the root of a tree", %{zipper: zipper} do
      assert Xipper.insert_left(zipper, zipper) == {:error, :insert_left_of_root}
    end
  end

  describe "insert_right/2" do
    test "inserts a new node directly to the right of the current focus, without shifting focus", %{zipper: zipper} do
      z = zipper |> Xipper.down |> Xipper.insert_right(0) |> Xipper.root

      assert z.focus == [1, 0, [2], [], [3, [4,5], 6], 7]
    end

    test "returns an error when called on the root of a tree", %{zipper: zipper} do
      assert Xipper.insert_right(zipper, 0) == {:error, :insert_right_of_root}
    end
  end

  describe "left/1" do
    test "moves focus to the sibling directly to the left of the current focus", %{zipper: zipper, root: root} do
      z = zipper |> Xipper.down |> Xipper.right |> Xipper.right |> Xipper.right |> Xipper.left

      assert z.focus == []
      assert z.left == [[2], 1]
      assert z.right == [[3,[4,5],6],7]
      assert z.parents == [[focus: root, left: [], right: []]]
    end

    test "returns an error if called on the leftmost sibling", %{zipper: zipper} do
      assert zipper |> Xipper.down |> Xipper.left == {:error, :left_of_leftmost}
    end
  end

  describe "leftmost/1" do
    test "moves to the leftmost sibling of the current focus", %{zipper: zipper} do
      z = zipper |> Xipper.down |> Xipper.right |> Xipper.right |> Xipper.leftmost

      assert z.focus == 1
      assert z.left == []
      assert z.right == [[2], [], [3,[4,5],6],7]
    end
  end

  describe "lefts/1" do
    test "returns the left-hand siblings of the current focus", %{zipper: zipper} do
      z = zipper |> Xipper.down |> Xipper.right |> Xipper.right

      assert Xipper.lefts(z) == [1, [2]]
    end
  end

  describe "make_node/3" do
    test "returns a new node of the proper type for the zipper", %{zipper: zipper} do
      assert Xipper.make_node(zipper, zipper.focus, [1,2,3,4,5]) == [1,2,3,4,5]
    end
  end

  describe "next/1" do
    test "steps through the zipper via depth-first search", %{zipper: zipper, root: root} do
      z = Xipper.next(zipper)
      assert z.focus == 1
      z = Xipper.next(z)
      assert z.focus == [2]
      z = Xipper.next(z)
      assert z.focus == 2
      z = Xipper.next(z)
      assert z.focus == []
      z = Xipper.next(z)
      assert z.focus == [3,[4,5],6]
      z = Xipper.next(z)
      assert z.focus == 3
      z = Xipper.next(z)
      assert z.focus == [4,5]
      z = Xipper.next(z)
      assert z.focus == 4
      z = Xipper.next(z)
      assert z.focus == 5
      z = Xipper.next(z)
      assert z.focus == 6
      z = Xipper.next(z)
      assert z.focus == 7
      z = Xipper.next(z)
      assert z.focus == root
    end

    test "returns the root indefinitely once the step through has been completed", %{zipper: zipper, root: root} do
      z = Enum.reduce(1..12, zipper, fn _, z -> Xipper.next(z) end)
      assert z.focus == root
      z = Xipper.next(z)
      assert z.focus == root
      z = Xipper.next(z)
      assert z.focus == root
    end
  end

  test "node/1", %{zipper: zipper, root: root} do
    assert Xipper.focus(zipper) == root
  end

  test "path/1", %{zipper: zipper, root: root} do
    assert Xipper.path(zipper) == []

    z = Xipper.down(zipper)
    assert Xipper.path(z) == [root]

    z = zipper |> Xipper.down |> Xipper.right |> Xipper.down
    assert Xipper.path(z) == [root, [2]]
  end

  describe "prev/1" do
    test "moves backwards through the zipper via depth-first walk", %{zipper: zipper} do
      z = Enum.reduce(1..11, zipper, fn _, z -> Xipper.next(z) end)
      assert z.focus == 7
      z = Xipper.prev(z)
      assert z.focus == 6
    end

    test "returns the root endlessly if called on the end of the walk", %{zipper: zipper, root: root} do
      z = Enum.reduce(1..12, zipper, fn _, z -> Xipper.next(z) end)
      assert z.focus == root
      z = Xipper.prev(z)
      assert z.focus == root
    end
  end

  describe "remove/1" do
    test "removes the current focus and moves to the previous node in a depth-first walk", %{zipper: zipper} do
      z = zipper |> Xipper.down |> Xipper.remove

      assert z.focus == [[2], [], [3,[4,5],6],7]

      z = zipper |> Xipper.down |> Xipper.right |> Xipper.remove |> Xipper.root

      assert z.focus == [1, [], [3,[4,5],6],7]
    end
  end

  describe "replace/2" do
    test "replaces the current node with the given node, without shifting focus", %{zipper: zipper} do
      z = zipper |> Xipper.down |> Xipper.right |> Xipper.replace(:foo) |> Xipper.root

      assert z.focus == [1, :foo, [], [3,[4,5],6],7]
    end
  end

  describe "right/1" do
    test "returns the next sibling to the right of the current focus", %{zipper: zipper, root: root} do
      z = zipper |> Xipper.down |> Xipper.right

      assert z.focus == [2]
      assert z.left == [1]
      assert z.right == [[],[3,[4,5],6],7]
      assert z.parents == [[focus: root, left: [], right: []]]
    end

    test "returns an error if called on the rightmost sibling", %{zipper: zipper} do
      assert zipper |> Xipper.down |> Xipper.rightmost |> Xipper.right == {:error, :right_of_rightmost}
    end
  end

  test "rightmost/1", %{zipper: zipper} do
    z = Xipper.down(zipper) |> Xipper.rightmost

    assert z.focus == 7
    assert z.right == []
    assert z.left == [[3,[4,5],6], [], [2], 1]
  end

  describe "rights/1" do
    test "returns a list of the right-hand siblings of the current focus", %{zipper: zipper} do
      z = Xipper.down(zipper)

      assert Xipper.rights(z) == [[2], [], [3, [4,5],6],7]
    end
  end

  describe "root/1" do
    test "moves from the current node to the root of the zipper", %{zipper: zipper, root: root} do
      z = zipper |> Xipper.down |> Xipper.right |> Xipper.right |> Xipper.right |> Xipper.down

      assert z.focus == 3

      z = Xipper.root(z)

      assert z.focus == root
    end
  end

  describe "up/1" do
    test "shifts focus to the current node's parent", %{zipper: zipper, root: root} do
      z = zipper |> Xipper.down |> Xipper.right |> Xipper.right

      assert z.focus == []
      assert z.left == [[2], 1]
      assert z.right == [[3,[4,5],6],7]
      assert z.parents == [[focus: root, left: [], right: []]]

      z = z |> Xipper.up

      assert z.focus == root
      assert z.left == []
      assert z.right == []
      assert z.parents == []
    end
  end

  describe "new/4" do
    test "takes 3 functions and a root and returns a zipper focused on that root" do
      is_branch = &is_list/1
      children = &(&1)
      make_node = fn _, x -> x end
      root = [1,2,[:a, :b, [3], :c], :d]

      zipper = Xipper.new(root, is_branch, children, make_node)

      assert zipper.focus == root
      assert zipper.left == []
      assert zipper.right == []
      assert zipper.parents == []
    end
  end
end
