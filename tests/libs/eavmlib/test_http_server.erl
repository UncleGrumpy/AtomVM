%
% This file is part of AtomVM.
%
% Copyright 2024 Paul Guyot <pguyot@kallisys.net>
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

-module(test_http_server).
-export([test/0, handle_req/3]).

test() ->
    ok = test_chunk(),
    ok = test_chunk_nodelay(inet),
    ok = test_chunk_nodelay(socket),
    ok = test_binary_false(),
    ok = test_unsupported_options(),
    ok.

test_chunk() ->
    Router = [
        {"*", ?MODULE, []}
    ],
    Pid = http_server:start_server(8080, Router),
    try
        {ok, Conn} = connect_client(8080, 5),
        {ok, Conn2, _Ref} = ahttp_client:request(Conn, <<"GET">>, <<"/">>, [], undefined),
        ok = loop_passive(Conn2, [])
    after
        ahttp_client:close(Conn2),
        case is_pid(Pid) of
            true -> exit(Pid, kill);
            false -> ok
        end
    end,
    ok.

% Uses a distinct port: the listen socket opened by start_server/2 above is owned by
% this test process (gen_tcp_inet sets {controlling_process, self()} at listen time)
% and is NOT released by exit(Pid, kill), which only kills the spawned acceptor. 8080
% therefore cannot be rebound within the same run; SO_REUSEADDR does not help because
% it covers TIME_WAIT, not an actively listening socket.
% Each backend gets its own port: as above, the listen socket opened for a
% backend is not released by exit(Pid, kill) within the same run, so the
% socket-backend server cannot bind 8081 after the inet-backend sub-test.
test_chunk_nodelay(Backend) ->
    Port =
        case Backend of
            inet -> 8081;
            socket -> 8082
        end,
    Router = [
        {"*", ?MODULE, []}
    ],
    % No `list` option: start_server/3 must add it itself, since the socket
    % backend would otherwise deliver binaries (its default without `list`).
    Pid = http_server:start_server(Port, Router, [{nodelay, true}, {inet_backend, Backend}]),
    try
        true = is_pid(Pid),
        {ok, Conn} = connect_client(Port, 5),
        {ok, Conn2, _Ref} = ahttp_client:request(Conn, <<"GET">>, <<"/">>, [], undefined),
        ok = loop_passive(Conn2, [])
    after
        ahttp_client:close(Conn2),
        case is_pid(Pid) of
            true -> exit(Pid, kill);
            false -> ok
        end
    end,
    ok.

% {binary, false} is a valid AtomVM option meaning list mode (the form does not exist on OTP),
% so start_server/3 must accept it and still serve requests as lists.
test_binary_false() ->
    Router = [
        {"*", ?MODULE, []}
    ],
    Pid = http_server:start_server(8084, Router, [{binary, false}]),
    true = is_pid(Pid),
    {ok, Conn} = connect_client(8084, 5),
    {ok, Conn2, _Ref} = ahttp_client:request(Conn, <<"GET">>, <<"/">>, [], undefined),
    ok = loop_passive(Conn2, []),
    exit(Pid, kill),
    ok.

% Options are validated before listen, so no socket is bound here and the port is arbitrary.
test_unsupported_options() ->
    Router = [
        {"*", ?MODULE, []}
    ],
    % binary in every form
    {error, {unsupported, [binary]}} = http_server:start_server(8083, Router, [
        {nodelay, true}, binary
    ]),
    {error, {unsupported, [{binary, true}]}} = http_server:start_server(8083, Router, [
        {binary, true}
    ]),
    % passive in every form
    {error, {unsupported, [{active, false}]}} = http_server:start_server(8083, Router, [
        {active, false}
    ]),
    {error, {unsupported, [{active, once}]}} = http_server:start_server(8083, Router, [
        {active, once}
    ]),
    % every unsupported form is reported, in order; valid options are untouched
    {error, {unsupported, [binary, {active, false}]}} = http_server:start_server(8083, Router, [
        binary, {nodelay, true}, {active, false}
    ]),
    {error, {unsupported, [{binary, true}, {active, once}]}} = http_server:start_server(
        8083,
        Router,
        [{binary, true}, {active, once}]
    ),
    ok.

connect_client(Port, Retries) when Retries > 0 ->
    ConnectResult = ahttp_client:connect(http, "localhost", Port, [{active, false}]),
    case ConnectResult of
        {ok, Conn} ->
            {ok, Conn};
        {error, _} = ConnectError ->
            io:format("Request failed: ~p~n", [ConnectError]),
            connect_client(Port, Retries - 1)
    end.

handle_req("GET", [], Conn) ->
    Socket = proplists:get_value(socket, Conn),
    % The listener may or may not set nodelay; toggle from whatever the
    % accepted socket inherited.
    {ok, [{nodelay, Initial}]} = inet:getopts(Socket, [nodelay]),
    ok = inet:setopts(Socket, [{nodelay, not Initial}]),
    {ok, [{nodelay, Toggled}]} = inet:getopts(Socket, [nodelay]),
    Toggled = not Initial,
    ok = inet:setopts(Socket, [{nodelay, Initial}]),
    {ok, [{nodelay, Initial}]} = inet:getopts(Socket, [nodelay]),
    Body = [34, <<"hello">>],
    http_server:reply(200, Body, Conn).

% http_server doesn't send Content-Length, so ahttp_client doesn't know when it's done and reports closed connection
loop_passive(Conn, AccResp) ->
    case ahttp_client:recv(Conn, 0) of
        {ok, UpdatedConn, Responses} ->
            loop_passive(UpdatedConn, lists:reverse(Responses, AccResp));
        {error, {gen_tcp, closed}} ->
            [{data, _DataRef, <<"\"hello">>}, {status, _StatusRef, 200}] = AccResp,
            ok
    end.
