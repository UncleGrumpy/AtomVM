%
% This file is part of AtomVM.
%
% Copyright 2018 Davide Bettio <davide@uninstall.it>
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

-module(test_regecho_driver).

-export([start/0, do_open_port/2, echo/1]).

start() ->
    Port = do_open_port("echo", []),
    true = is_port(Port),
    register(echo, Port),
    true = is_port(whereis(echo)),
    length(echo("Hello World")).

do_open_port(PortName, Param) ->
    open_port({spawn, PortName}, Param).

echo(SendValue) ->
    whereis(echo) ! {self(), SendValue},
    receive
        Value ->
            Value
    end.
