#
# This file is part of AtomVM.
#
# Copyright 2020 Davide Bettio <davide@uninstall.it>
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
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule Exavmlib.MixProject do
  use Mix.Project

  def project do
    [
      app: :exavmlib,
      version: "0.7.0",
      elixir: "~> 1.17",
      deps: deps(),
      docs: &docs/0,
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, ">= 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      files: [
        "mix.exs",
        "LICENSE",
        "lib/Access.ex",
        "lib/ArgumentError.ex",
        "lib/ArithmeticError.ex",
        "lib/AVMPort.ex",
        "lib/BadArityError.ex",
        "lib/BadBooleanError.ex",
        "lib/BadFunctionError.ex",
        "lib/BadMapError.ex",
        "lib/BadStructureError.ex",
        "lib/Base.ex",
        "lib/Bitwise.ex",
        "lib/CaseClauseError.ex",
        "lib/Code.ex",
        "lib/Collectable.ex",
        "lib/CollectableList.ex",
        "lib/CollectableMap.ex",
        "lib/CollectableMapSet.ex",
        "lib/CondClauseError.ex",
        "lib/Console.ex",
        "lib/Enum.ex",
        "lib/Enumerable.ex",
        "lib/EnumerableList.ex",
        "lib/EnumerableMap.ex",
        "lib/EnumerableMapSet.ex",
        "lib/EnumerableRange.ex",
        "lib/ErlangError.ex",
        "lib/Exception.ex",
        "lib/Function.ex",
        "lib/FunctionClauseError.ex",
        "lib/GenServer.ex",
        "lib/GPIO.ex",
        "lib/I2C.ex",
        "lib/Integer.ex",
        "lib/IO.ex",
        "lib/json.ex",
        "lib/Kernel.ex",
        "lib/KeyError.ex",
        "lib/Keyword.ex",
        "lib/LEDC.ex",
        "lib/List.Chars.Atom.ex",
        "lib/List.Chars.BitString.ex",
        "lib/List.Chars.ex",
        "lib/List.Chars.Float.ex",
        "lib/List.Chars.Integer.ex",
        "lib/List.Chars.List.ex",
        "lib/List.ex",
        "lib/Map.ex",
        "lib/MapSet.ex",
        "lib/MatchError.ex",
        "lib/Module.ex",
        "lib/Process.ex",
        "lib/Protocol.ex",
        "lib/Protocol.UndefinedError.ex",
        "lib/Range.ex",
        "lib/RuntimeError.ex",
        "lib/String.Chars.Atom.ex",
        "lib/String.Chars.BitString.ex",
        "lib/String.Chars.ex",
        "lib/String.Chars.Float.ex",
        "lib/String.Chars.Integer.ex",
        "lib/String.Chars.List.ex",
        "lib/Supervisor.Default.ex",
        "lib/Supervisor.ex",
        "lib/Supervisor.Spec.ex",
        "lib/System.ex",
        "lib/SystemLimitError.ex",
        "lib/TryClauseError.ex",
        "lib/Tuple.ex",
        "lib/UndefinedFunctionError.ex",
        "lib/WithClauseError.ex"
      ],
      description: "AtomVM Elixir library",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/atomvm/AtomVM"}
    ]
  end

  defp docs do
    []
  end
end
