#
# This file is part of elixir-lang.
#
# Copyright 2012-2018 Elixir Contributors
# https://github.com/elixir-lang/elixir/commits/v1.7.4/lib/elixir/lib/collectable.ex
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defprotocol Collectable do
  @moduledoc """
  A protocol to traverse data structures.

  The `Enum.into/2` function uses this protocol to insert an
  enumerable into a collection:

      iex> Enum.into([a: 1, b: 2], %{})
      %{a: 1, b: 2}

  ## Why Collectable?

  The `Enumerable` protocol is useful to take values out of a collection.
  In order to support a wide range of values, the functions provided by
  the `Enumerable` protocol do not keep shape. For example, passing a
  map to `Enum.map/2` always returns a list.

  This design is intentional. `Enumerable` was designed to support infinite
  collections, resources and other structures with fixed shape. For example,
  it doesn't make sense to insert values into a range, as it has a fixed
  shape where just the range limits are stored.

  The `Collectable` module was designed to fill the gap left by the
  `Enumerable` protocol. `into/1` can be seen as the opposite of
  `Enumerable.reduce/3`. If `Enumerable` is about taking values out,
  `Collectable.into/1` is about collecting those values into a structure.

  ## Examples

  To show how to manually use the `Collectable` protocol, let's play with its
  implementation for `MapSet`.

      iex> {initial_acc, collector_fun} = Collectable.into(MapSet.new())
      iex> updated_acc = Enum.reduce([1, 2, 3], initial_acc, fn elem, acc ->
      ...>   collector_fun.(acc, {:cont, elem})
      ...> end)
      iex> collector_fun.(updated_acc, :done)
      #MapSet<[1, 2, 3]>

  To show how the protocol can be implemented, we can take again a look at the
  implementation for `MapSet`. In this implementation "collecting" elements
  simply means inserting them in the set through `MapSet.put/2`.

      defimpl Collectable do
        def into(original) do
          collector_fun = fn
            set, {:cont, elem} -> MapSet.put(set, elem)
            set, :done -> set
            _set, :halt -> :ok
          end

          {original, collector_fun}
        end
      end

  """

  @type command :: {:cont, term} | :done | :halt

  @doc """
  Returns an initial accumulator and a "collector" function.

  The returned function receives a term and a command and injects the term into
  the collectable on every `{:cont, term}` command.

  `:done` is passed as a command when no further values will be injected. This
  is useful when there's a need to close resources or normalizing values. A
  collectable must be returned when the command is `:done`.

  If injection is suddenly interrupted, `:halt` is passed and the function
  can return any value as it won't be used.

  For examples on how to use the `Collectable` protocol and `into/1` see the
  module documentation.
  """
  @spec into(t) :: {term, (term, command -> t | term)}
  def into(collectable)
end
