defmodule Xipper do
  @moduledoc """
  An Elixir implementation of [Huet's Zipper](https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf), with gratitude to Rich Hickey's
  [Clojure implementation](https://clojure.github.io/clojure/clojure.zip-api.html).

  Zippers provide an elegant solution for traversing a tree-like data structure,
  while maintaining enough state data to reconstruct the entire tree from any
  of its child nodes.

  All that is required to create a zipper for a data structure is the data structure
  itself and a set of functions that define behaviours around nodes of the data structure.
  See `Xipper.new/4` for details.

  For the sake of brevity, the documentation for this module's functions will
  assume the following code has been run before each example:

      iex> zipper = Xipper.new(
      ...>   [1, 2, [3, 4], 5],
      ...>   &is_list/1,
      ...>   fn node -> node end,
      ...>   fn _node, children -> children end
      ...> )
      iex> zipper.focus
      [1, 2, [3, 4], 5]

  Again, see `new/4` for an explanation of the functions passed as arguments here.
  """

  defstruct [
    focus: nil,
    left: [],
    right: [],
    parents: [],
    is_end: false,
    functions: [
      is_branch: nil,
      children: nil,
      make_node: nil
    ]
  ]

  @type is_branch_function :: (any -> boolean)
  @type children_function :: (any -> [any])
  @type make_node_function :: (any, any, any -> any)
  @type functions :: [
    is_branch: __MODULE__.is_branch_function,
    children: __MODULE__.children_function,
    make_node: __MODULE__.make_node_function
  ]
  @type parent :: [
    focus: any,
    left: any,
    right: any
  ]
  @type t :: %__MODULE__{
    focus: any,
    left: [any],
    right: [any],
    parents: [__MODULE__.parent],
    is_end: boolean,
    functions: __MODULE__.functions
  }
  @type error :: {:error, atom}
  @type maybe_zipper :: __MODULE__.t | __MODULE__.error

  @doc """
  Creates a new zipper.

  Creating a zipper requires four arguments. The first argument is the data
  structure to be traversed by the zipper, and the final three arguments are
  functions. In order, these functions are:

  1. a function that takes a node from the data structure and returns true if it
  is a branch node (that is, it has children or can have children), and false
  otherwise
  1. a function that takes a node from the data structure and returns its children
  if it is a branch node
  1. a function that takes a node and a list of children and returns a new node
  with those children

  As an example, the following code returns a zipper for a nested list.

  ## Example

      iex> zipper = Xipper.new(
      ...>   [1, 2, [3, 4], 5],
      ...>   &is_list/1,
      ...>   fn node -> node end,
      ...>   fn _node, children -> children end
      ...> )
      iex> zipper.focus
      [1, 2, [3, 4], 5]

  The given arguments are
  1. the root list
  1. a function for defining a branch node -- in this case whether a node is a list
  1. a function for returing a node's children -- since a branch node is simply a list, this returns the node itself
  1. a function for creating a new node -- since a branch is just a list of its children, this function returns the list of children as the new node
  """
  @spec new(any, __MODULE__.is_branch_function, __MODULE__.children_function, __MODULE__.make_node_function) :: __MODULE__.t
  def new(root, is_branch_fn, children_fn, make_node_fn) do
    %__MODULE__{
      focus: root,
      functions: [
        is_branch: is_branch_fn,
        children: children_fn,
        make_node: make_node_fn
      ]
    }
  end

  @doc """
  Returns the current focus of the zipper.

  ## Example

      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]

      iex> zipper |> Xipper.down |> Xipper.focus
      1

  """
  @spec focus(__MODULE__.t) :: any
  def focus(%{focus: focus}), do: focus

  @doc """
  Returns true if the current focus of the zipper is a branch node, false
  otherwise.

  ## Example

      iex> Xipper.is_branch(zipper)
      true

      iex> zipper |> Xipper.down |> Xipper.is_branch
      false

  """
  @spec is_branch(__MODULE__.t) :: boolean
  def is_branch(zipper = %__MODULE__{focus: focus}) do
    zipper.functions[:is_branch].(focus)
  end

  @doc """
  Returns a node's children if called on a branch node, an error tuple
  otherwise.

  ## Example

      iex> Xipper.children(zipper)
      [1, 2, [3, 4], 5]

      iex> zipper |> Xipper.down |> Xipper.children
      {:error, :children_of_leaf}

  """
  @spec children(__MODULE__.t) :: __MODULE__.maybe_zipper
  def children(zipper = %__MODULE__{focus: focus}) do
    case is_branch(zipper) do
      true -> zipper.functions[:children].(focus)
      false -> {:error, :children_of_leaf}
    end
  end

  @doc """
  Takes a zipper, a node, and a list of child nodes and returns a new node
  constructed from the node and children via the user-defined `make_node` function
  passed in to `Xipper.new/4`.

  In the case of our example zipper, since a list node's children are simply the
  list itself, in this context this function will return the list of children passed
  as the third argument.

  ## Example

      iex> Xipper.make_node(zipper, [1,2,3], [4,5,6])
      [4, 5, 6]

  """
  @spec make_node(__MODULE__.t, any, [any]) :: any
  def make_node(zipper, node, children) do
    zipper.functions[:make_node].(node, children)
  end

  @doc """
  Shifts the zipper's focus down to the leftmost child node of the current focus.

  This function returns an error tuple if the current focus is a leaf node, or a
  branch node with no children.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> Xipper.focus(zipper)
      1
      iex> Xipper.down(zipper)
      {:error, :down_from_leaf}

  """
  @spec down(__MODULE__.t) :: __MODULE__.maybe_zipper
  def down(zipper = %__MODULE__{}) do
    case is_branch(zipper) do
      false -> {:error, :down_from_leaf}
      true ->
        case children(zipper) do
          [] -> {:error, :down_from_empty_branch}
          [new_focus|right] ->
            %__MODULE__{zipper |
              focus: new_focus,
              left: [],
              right: right,
              parents: [generate_parent_element(zipper) | zipper.parents]
            }
        end
    end
  end

  defp generate_parent_element(zipper) do
    zipper |> Map.take([:focus, :left, :right]) |> Enum.into([], &(&1))
  end

  @doc """
  Shifts the zipper's focus to the sibling node directly to the right of the current focus.

  This function returns an error tuple if the current focus is the rightmost
  of its siblings.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> zipper |> Xipper.right |> Xipper.focus
      2
      iex> zipper = Xipper.rightmost(zipper)
      iex> Xipper.focus(zipper)
      5
      iex> Xipper.right(zipper)
      {:error, :right_of_rightmost}

  """
  @spec right(__MODULE__.t) :: __MODULE__.maybe_zipper
  def right(%__MODULE__{right: []}), do: {:error, :right_of_rightmost}
  def right(zipper = %__MODULE__{}) do
    [new_focus|new_right] = zipper.right
    %__MODULE__{zipper |
      focus: new_focus,
      right: new_right,
      left: [zipper.focus|zipper.left]
    }
  end

  @doc """
  Shifts the zipper's focus to the sibling node directly to the left of the current focus.

  This function returns an error tuple if the current focus is the leftmost
  of its siblings.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> zipper |> Xipper.left
      {:error, :left_of_leftmost}
      iex> zipper = zipper |> Xipper.rightmost |> Xipper.left
      iex> Xipper.focus(zipper)
      [3, 4]

  """
  @spec left(__MODULE__.t) :: __MODULE__.maybe_zipper
  def left(%__MODULE__{left: []}), do: {:error, :left_of_leftmost}
  def left(zipper = %__MODULE__{}) do
    [new_focus|new_left] = zipper.left
    %__MODULE__{zipper |
      focus: new_focus,
      left: new_left,
      right: [zipper.focus|zipper.right]
    }
  end

  @doc """
  Shifts the zipper's focus to the current focus's parent.

  This function returns an error if the current focus is the root of the zipper.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> Xipper.focus(zipper)
      1
      iex> zipper = Xipper.up(zipper)
      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]

      iex> Xipper.up(zipper)
      {:error, :up_from_root}

  """
  @spec up(__MODULE__.t) :: __MODULE__.maybe_zipper
  def up(%__MODULE__{parents: []}), do: {:error, :up_from_root}
  def up(zipper = %__MODULE__{}) do
    [[focus: new_focus, left: new_left, right: new_right]|new_parents] = zipper.parents
    new_children = Enum.reverse(zipper.left) ++ [zipper.focus|zipper.right]
    new_focus = make_node(zipper, new_focus, new_children)
    %__MODULE__{zipper |
      focus: new_focus,
      left: new_left,
      right: new_right,
      parents: new_parents
    }
  end

  @doc """
  Returns all right-hand siblings of a node.

  ## Example

      iex> zipper |> Xipper.down |> Xipper.rights
      [2, [3, 4], 5]

  """
  @spec rights(__MODULE__.t) :: [any]
  def rights(%__MODULE__{right: rights}), do: rights

  @doc """
  Returns all left-hand siblings of a node.

  ## Example

      iex> zipper |> Xipper.down |> Xipper.lefts
      []

      iex> zipper |> Xipper.down |> Xipper.rightmost |> Xipper.lefts
      [1, 2, [3, 4]]

  """
  @spec lefts(__MODULE__.t) :: [any]
  def lefts(%__MODULE__{left: lefts}), do: Enum.reverse(lefts)

  @doc """
  Traverses a zipper upwards to the root of the zipper.

  This function has no effect if the current focus is already the root.

  ## Example

      iex> zipper = Xipper.root(zipper)
      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]

      iex> zipper = zipper |> Xipper.down |> Xipper.right |> Xipper.right |> Xipper.down
      iex> Xipper.focus(zipper)
      3
      iex> zipper = Xipper.root(zipper)
      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]

  """
  @spec root(__MODULE__.t) :: __MODULE__.t
  def root(zipper = %__MODULE__{parents: []}), do: zipper
  def root(zipper = %__MODULE__{}), do: zipper |> up |> root

  @doc """
  Moves focus to the rightmost sibling of the current focus.

      iex> zipper = zipper |> Xipper.down |> Xipper.rightmost
      iex> Xipper.focus(zipper)
      5

  """
  @spec rightmost(__MODULE__.t) :: __MODULE__.t
  def rightmost(zipper = %__MODULE__{right: []}), do: zipper
  def rightmost(zipper = %__MODULE__{}), do: zipper |> right |> rightmost

  @doc """
  Moves focus to the leftmost sibling of the current focus.

      iex> zipper = zipper |> Xipper.down |> Xipper.right |> Xipper.right
      iex> Xipper.focus(zipper)
      [3 ,4]
      iex> zipper = Xipper.leftmost(zipper)
      iex> Xipper.focus(zipper)
      1

  """
  @spec leftmost(__MODULE__.t) :: __MODULE__.t
  def leftmost(zipper = %__MODULE__{left: []}), do: zipper
  def leftmost(zipper = %__MODULE__{}), do: zipper |> left |> leftmost

  @doc """
  Moves to the next node in a depth-first walk through the zipper.

  `next/1` will attempt to move `down/1`, then `right/1`, and then seek back up
  the zipper until it finds a right-hand sibling to move to. Once it reaches the
  end of the walk it will return the root of the zipper indefinitely.

  ## Example

      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]
      iex> zipper = Xipper.next(zipper)
      iex> Xipper.focus(zipper)
      1
      iex> zipper = Xipper.next(zipper)
      iex> Xipper.focus(zipper)
      2
      iex> zipper = Xipper.next(zipper)
      iex> Xipper.focus(zipper)
      [3, 4]
      iex> zipper = Xipper.next(zipper)
      iex> Xipper.focus(zipper)
      3
      iex> zipper = Xipper.next(zipper)
      iex> Xipper.focus(zipper)
      4
      iex> zipper = Xipper.next(zipper)
      iex> Xipper.focus(zipper)
      5
      iex> zipper = Xipper.next(zipper)
      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]

  """
  @spec next(__MODULE__.t) :: __MODULE__.t
  def next(zipper) do
    case is_end(zipper) do
      true -> zipper
      false ->
        case {down(zipper), right(zipper)} do
          {{:error, _}, {:error, _}} -> _next(zipper)
          {{:error, _}, right_z} -> right_z
          {down_z, _} -> down_z
        end
    end
  end

  defp _next(zipper) do
    case up(zipper) do
      {:error, _} -> %{zipper | is_end: true}
      next_zipper ->
        case right(next_zipper) do
          {:error, _} -> _next(next_zipper)
          new_zipper -> new_zipper
        end
    end
  end

  @doc """
  Moves to the previous node in a depth-first walk through the zipper.

  `prev/1` will attempt to move `left/1`, then recuse down through its left siblings
  children, then `up/1`, until it reaches the root of the zipper. Calling
  `prev/1` on a zipper that has reached the end of its depth-first walk
  (for which `is_end/1` returns true), will return the same zipper indefinitely.

  ## Example

      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]
      iex> zipper = zipper |> Xipper.down |> Xipper.rightmost
      iex> Xipper.focus(zipper)
      5
      iex> zipper = Xipper.prev(zipper)
      iex> Xipper.focus(zipper)
      4
      iex> zipper = Xipper.prev(zipper)
      iex> Xipper.focus(zipper)
      3
      iex> zipper = Xipper.prev(zipper)
      iex> Xipper.focus(zipper)
      [3, 4]
      iex> zipper = Xipper.prev(zipper)
      iex> Xipper.focus(zipper)
      2
      iex> zipper = Xipper.prev(zipper)
      iex> Xipper.focus(zipper)
      1
      iex> zipper = Xipper.prev(zipper)
      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]

      iex> zipper = zipper |> Xipper.down |> Xipper.rightmost |> Xipper.next
      iex> zipper = Xipper.prev(zipper)
      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5]

  """
  @spec prev(__MODULE__.t) :: __MODULE__.t
  def prev(zipper) do
    case is_end(zipper) do
      true -> zipper
      false ->
        case left(zipper) do
          {:error, _} -> up(zipper)
          left_zipper -> _prev(left_zipper)
        end
    end
  end

  defp _prev(zipper) do
    case down(zipper) do
      {:error, _} -> zipper
      down_zipper -> down_zipper |> rightmost |> _prev
    end
  end

  @doc """
  Returns true if the zipper has reached the end of a depth-first walk, false
  otherwise.

  ## Example

      iex> Xipper.is_end(zipper)
      false

      iex> zipper |> Xipper.down |> Xipper.rightmost |> Xipper.next |> Xipper.is_end
      true

  """
  @spec is_end(__MODULE__.t) :: boolean
  def is_end(%__MODULE__{is_end: true}), do: true
  def is_end(%__MODULE__{is_end: _}), do: false

  @spec path(__MODULE__.t) :: [any]
  def path(zipper = %__MODULE__{}) do
    zipper.parents
    |> Enum.reverse
    |> Enum.map(&(&1[:focus]))
  end

  @doc """
  Inserts the given node as the immediate left-hand sibling of the current focus,
  without shifting focus.

  This function returns an error tuple if called on the root of a zipper.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> zipper = Xipper.insert_left(zipper, -10)
      iex> zipper |> Xipper.root |> Xipper.focus
      [-10, 1, 2, [3, 4], 5]

  """
  @spec insert_left(__MODULE__.t, any) :: __MODULE__.maybe_zipper
  def insert_left(%__MODULE__{parents: []}, _), do: {:error, :insert_left_of_root}
  def insert_left(zipper = %__MODULE__{}, new_sibling) do
    %{ zipper | left: [new_sibling|zipper.left]}
  end

  @doc """
  Inserts the given node as the immediate right-hand sibling of the current focus,
  without shifting focus.

  This function returns an error tuple if called on the root of a zipper.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> zipper = Xipper.insert_right(zipper, 1.5)
      iex> zipper |> Xipper.root |> Xipper.focus
      [1, 1.5, 2, [3, 4], 5]

  """
  @spec insert_right(__MODULE__.t, any) :: __MODULE__.maybe_zipper
  def insert_right(%__MODULE__{parents: []}, _), do: {:error, :insert_right_of_root}
  def insert_right(zipper = %__MODULE__{}, new_sibling) do
    %{ zipper | right: [new_sibling|zipper.right]}
  end

  @doc """
  Replaces the currently focused node with the result of applying the given
  function to that node.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> Xipper.focus(zipper)
      1
      iex> zipper = Xipper.edit(zipper, &to_string/1)
      iex> Xipper.focus(zipper)
      "1"

  """
  @spec edit(__MODULE__.t, (any -> any)) :: __MODULE__.t
  def edit(zipper = %__MODULE__{}, func) do
    %__MODULE__{zipper | focus: func.(zipper.focus)}
  end

  @doc """
  Replaces the current focus with the node passed as the second argument.

  ## Example

      iex> zipper = Xipper.down(zipper)
      iex> Xipper.focus(zipper)
      1
      iex> zipper = Xipper.replace(zipper, 42)
      iex> Xipper.focus(zipper)
      42

  """
  @spec replace(__MODULE__.t, any) :: __MODULE__.t
  def replace(zipper = %__MODULE__{}, new_focus) do
    edit(zipper, fn _ -> new_focus end)
  end

  @doc """
  Appends the given child as the right-most child of the current focus, if it is
  a branch node, without shifting focus.

  This function returns an error if trying to insert a child into a leaf node.

  ## Example

      iex> zipper = Xipper.append_child(zipper, [6, 7])
      iex> Xipper.focus(zipper)
      [1, 2, [3, 4], 5, [6, 7]]

      iex> zipper |> Xipper.down |> Xipper.append_child(1.5)
      {:error, :append_child_of_leaf}

  """
  @spec append_child(__MODULE__.t, any) :: __MODULE__.maybe_zipper
  def append_child(zipper = %__MODULE__{}, new_child) do
    case is_branch(zipper) do
      false -> {:error, :append_child_of_leaf}
      true -> %{zipper |
        focus: make_node(zipper, zipper.focus, children(zipper) ++ [new_child])
      }
    end
  end

  @doc """
  Inserts the given child as the left-most child of the current focus, if it is
  a branch node, without shifting focus.

  This function returns an error if trying to insert a child into a leaf node.

  ## Example

      iex> zipper = Xipper.insert_child(zipper, 0)
      iex> Xipper.focus(zipper)
      [0, 1, 2, [3, 4], 5]

      iex> zipper |> Xipper.down |> Xipper.insert_child(0)
      {:error, :insert_child_of_leaf}

  """
  @spec insert_child(__MODULE__.t, any) :: __MODULE__.maybe_zipper
  def insert_child(zipper = %__MODULE__{}, new_child) do
    case is_branch(zipper) do
      false -> {:error, :insert_child_of_leaf}
      true -> %{zipper |
        focus: make_node(zipper, zipper.focus, [new_child|children(zipper)])
      }
    end
  end

  @doc """
  Removes the current focus of the zipper and shifts focus to where the previous
  node in a depth-first walk would be.

  This function returns an error if trying to remove the root of the zipper.

  ## Example

      iex> Xipper.remove(zipper)
      {:error, :remove_of_root}

      iex> zipper = zipper |> Xipper.down |> Xipper.remove
      iex> Xipper.focus(zipper)
      [2, [3, 4], 5]

      iex> zipper = zipper |> Xipper.down |> Xipper.right |> Xipper.remove
      iex> Xipper.focus(zipper)
      1
      iex> Xipper.rights(zipper)
      [[3, 4], 5]

  """
  @spec remove(__MODULE__.t) :: __MODULE__.maybe_zipper
  def remove(zipper = %__MODULE__{}) do
    case left(zipper) do
      {:error, _} ->
        case up(zipper) do
          {:error, _} -> {:error, :remove_of_root}
          up_zipper ->
            [_|new_children] = children(up_zipper)
            %{up_zipper | focus: make_node(up_zipper, up_zipper.focus, new_children)}
        end
      left_zipper ->
        [_|new_right] = left_zipper.right
        %{left_zipper | right: new_right}
    end
  end
end
