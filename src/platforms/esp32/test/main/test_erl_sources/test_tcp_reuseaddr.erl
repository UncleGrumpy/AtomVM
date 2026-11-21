%
% This file is part of AtomVM.
%
% Copyright 2026 Winford (UncleGrumpy)
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

-module(test_tcp_reuseaddr).
-export([start/0]).

% Tests for the {reuseaddr, true} gen_tcp:listen/2 option and for eaddrinuse
% reporting on bind failures.
%
% Listen-only semantics: no IP address or peer is required, so this test
% runs whether or not an interface is up.

start() ->
    try
        ok = test_eaddrinuse(inet),
        % test_main.c expects this to differ by ESP-IDF version (>= 5.4 vs
        % older): 0 = {reuseaddr, true} worked, 1 = it was rejected with badarg.
        test_reuseaddr_rebind(inet)
    catch
        Class:Reason:Stack ->
            % avm_test_case does not print crash reports on esp32; return the
            % failure so it is visible in the test output.
            io:format("test_tcp_reuseaddr failed: ~w:~w~n~w~n", [Class, Reason, Stack]),
            error
    end.

% A second listener on a port that is actively listened on fails with
% eaddrinuse, as on OTP.
test_eaddrinuse(Backend) ->
    {ok, LS} = gen_tcp:listen(0, [binary, {active, false}, {inet_backend, Backend}]),
    {ok, {_Address, Port}} = inet:sockname(LS),
    {error, eaddrinuse} = gen_tcp:listen(Port, [binary, {active, false}, {inet_backend, Backend}]),
    ok = gen_tcp:close(LS),
    ok.

% {reuseaddr, true} allows re-listening on the port after close, as on OTP.
%
% On the inet backend, {reuseaddr, true} requires the synchronous tcp/ip
% callback of the lwIP shipped with ESP-IDF >= 5.4; older ESP-IDF rejects
% it with badarg (see socket_driver.c).  Return which outcome was seen (0 =
% option worked, 1 = option rejected), for test_main.c to check against the
% ESP-IDF version it was built with.  The socket backend supports the option
% on all ESP-IDF versions.
test_reuseaddr_rebind(socket) ->
    rebind_listening_port(socket);
test_reuseaddr_rebind(inet) ->
    case listen_with_reuseaddr(0, inet) of
        {error, badarg} ->
            1;
        {ok, LS1} ->
            {ok, {_Address, Port}} = inet:sockname(LS1),
            ok = gen_tcp:close(LS1),
            {ok, LS2} = listen_with_reuseaddr(Port, inet),
            ok = gen_tcp:close(LS2),
            0
    end.

listen_with_reuseaddr(Port, Backend) ->
    gen_tcp:listen(Port, [binary, {active, false}, {inet_backend, Backend}, {reuseaddr, true}]).

rebind_listening_port(Backend) ->
    {ok, LS1} = listen_with_reuseaddr(0, Backend),
    {ok, {_Address, Port}} = inet:sockname(LS1),
    ok = gen_tcp:close(LS1),
    {ok, LS2} = listen_with_reuseaddr(Port, Backend),
    ok = gen_tcp:close(LS2),
    ok.
