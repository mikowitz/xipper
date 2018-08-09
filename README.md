# Xipper

An Elixir implementation of [Huet's Zipper](https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf),
with gratitude to Rich Hickey's [Clojure implementation](https://clojure.github.io/clojure/clojure.zip-api.html).

Zippers provide an elegant solution for traversing a tree-like data structure,
while maintaining enough state data to reconstruct the entire tree from any
of its child nodes.

All that is required to create a zipper for a data structure is the data structure
itself and a set of functions that define behaviours around nodes of the data structure.
See below and the documentation for `Xipper.new/4` for details.

## Basic Usage and API Reference

For more complete documentation and examples, see the documentation for `Xipper` either inline
in the file [here](https://github.com/mikowitz/xipper/blob/master/lib/xipper.ex),
or on [hexdocs.pm](https://hexdocs.pm/xipper/).

### Creating a zipper

* `Xipper.new/4` creates a new zipper and is probably the most involved function
in the API. It takes as its arguments a root data structure for the zipper and
three functions that define behaviours around nodes of that data structure.

#### For a nested list data structure

    zipper = Xipper.new(
      # root data structure
      [1, 2, [3, [4, 5], 6], [], 7],

      # function for determining whether a node is a branch
      &is_list/1,

      # function for returning a branch node's children
      fn branch_node -> branch_node end,

      # function for creating a new node from an existing node and a list of children
      fn _node, children -> children end
    )

#### For a map data structure

    zipper = Xipper.new(
      %{name: "a", children: [%{name: "b"}, %{name: "c"}]},

      fn branch -> is_map(branch) && Map.has_key?(branch, :children) end,

      fn branch -> Map.get(branch, :children) end,

      fn
        node = %{children: _}, children -> %{node | children: children}
        node, children -> Map.put(node, :children, children)
      end
    )


### Querying a zipper

* `Xipper.focus/1` returns the current focus of the zipper
* `Xipper.children/1` returns the children of the current focus
* `Xipper.is_branch/1` returns true if the current focus is a branch node (i.e. it has or can have children)
* `Xipper.is_end/1` returns true if a depth-first walk through the zipper (see `next/1` and `prev/1`) has been completed
* `Xipper.lefts/1` returns the left-hand siblings of the current focus
* `Xipper.rights/1` returns the right-hand siblings of the current focus
* `Xipper.path/1` returns a list consisting of the parent, grandparent, etc. nodes of the current focus

### Navigating a zipper

* `Xipper.down/1` shifts focus to the leftmost child of the current focus
* `Xipper.up/1` shifts focus to the parent of the current focus
* `Xipper.left/1` shifts focus to the immediate left-hand sibling of the current focus
* `Xipper.right/1` shifts focus to the immediate right-hand sibling of the current focus
* `Xipper.leftmost/1` shifts to the leftmost sibling of the current focus
* `Xipper.rightmost/1` shifts to the rightmost sibling of the current focus
* `Xipper.next/1` shifts focus to the next node in a depth-first walk of the zipper
* `Xipper.prev/1` shifts focus to the previous node in a depth-first walk of the zipper
* `Xipper.root/1` shifts focus to the topmost root of the zipper

### Modifying a zipper

* `Xipper.edit/2` replaces the current node with the result of calling a given function on the current node
* `Xipper.replace/2` replaces the current node with the passed replacement value
* `Xipper.remove/1` removes the current focus, and shifts focus to the previous (via depth-first walk) node
* `Xipper.insert_child/2` inserts the given child node as the first child of the current node without shifting focus
* `Xipper.append_child/2` appends the given child node as the last child of the current node without shifting focus
* `Xipper.insert_left/2` inserts the given node immediately to the left of the current node without shifting focus
* `Xipper.insert_right/2` inserts the given node immediately to the right of the current node without shifting focus
* `Xipper.make_node/3` takes a zipper, a node, and a set of children and returns a new node based on the user defined function passed into the zipper constructor. (**NB** this does not modify the zipper, but returns a value that could be used to modify it)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `xipper` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:xipper, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/xipper](https://hexdocs.pm/xipper).

