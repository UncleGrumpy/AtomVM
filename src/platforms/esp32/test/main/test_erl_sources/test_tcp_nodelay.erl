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

-module(test_tcp_nodelay).
-export([start/0]).

% Tests for the {tcp, nodelay} socket option.
%
% On esp32 the socket NIFs use the BSD sockets implementation on top of
% lwIP's socket API, and lwIP rejects all IPPROTO_TCP options on listening
% sockets (sockets.c: "if (sock->conn->pcb.tcp->state == LISTEN) return
% EINVAL").  The lwIP (HAVE_LWIP_RAW) implementation, used e.g. on rp2,
% instead stores the listener's setting in the socket resource and applies
% it to accepted pcbs; that behavior is covered by
% tests/libs/estdlib/test_tcp_socket.erl (test_nodelay_listener).

start() ->
    try
        ok = test_socket_nodelay_connected(),
        ok = test_socket_nodelay_accepted(),
        ok = test_socket_opts(),
        ok = test_socket_nodelay_errors(),
        0
    catch
        Class:Reason:Stack ->
            % avm_test_case does not print crash reports on esp32; return the
            % failure so it is visible in the test output.
            io:format("test_tcp_nodelay failed: ~w:~w~n~w~n", [Class, Reason, Stack]),
            error
    end.

% Nodelay on a connected (client-side) socket
test_socket_nodelay_connected() ->
    {ok, ListenSocket} = socket:open(inet, stream, tcp),
    ok = socket:bind(ListenSocket, #{family => inet, addr => loopback, port => 0}),
    ok = socket:listen(ListenSocket),
    {ok, #{port := Port}} = socket:sockname(ListenSocket),

    {select, {select_info, accept, Ref}} = socket:accept(ListenSocket, nowait),
    {ok, ClientSocket} = socket:open(inet, stream, tcp),
    ok = socket:connect(ClientSocket, #{family => inet, addr => loopback, port => Port}),
    ok = wait_accept_select(ListenSocket, Ref),
    {ok, _AcceptedSocket} = socket:accept(ListenSocket, 0),

    % Nagle is enabled by default on a fresh connection
    {ok, false} = socket:getopt(ClientSocket, {tcp, nodelay}),
    ok = socket:setopt(ClientSocket, {tcp, nodelay}, true),
    {ok, true} = socket:getopt(ClientSocket, {tcp, nodelay}),
    ok = socket:setopt(ClientSocket, {tcp, nodelay}, false),
    {ok, false} = socket:getopt(ClientSocket, {tcp, nodelay}),

    ok = socket:close(ClientSocket),
    ok = socket:close(ListenSocket),
    ok.

% Nodelay on a socket returned by accept: the accepted socket is a connected
% (non-listening) netconn, so the option is available on it
test_socket_nodelay_accepted() ->
    {ok, ListenSocket} = socket:open(inet, stream, tcp),
    ok = socket:bind(ListenSocket, #{family => inet, addr => loopback, port => 0}),
    ok = socket:listen(ListenSocket),
    {ok, #{port := Port}} = socket:sockname(ListenSocket),

    {select, {select_info, accept, Ref}} = socket:accept(ListenSocket, nowait),
    {ok, ClientSocket} = socket:open(inet, stream, tcp),
    ok = socket:connect(ClientSocket, #{family => inet, addr => loopback, port => Port}),
    ok = wait_accept_select(ListenSocket, Ref),
    {ok, AcceptedSocket} = socket:accept(ListenSocket, 0),

    {ok, false} = socket:getopt(AcceptedSocket, {tcp, nodelay}),
    ok = socket:setopt(AcceptedSocket, {tcp, nodelay}, true),
    {ok, true} = socket:getopt(AcceptedSocket, {tcp, nodelay}),
    ok = socket:setopt(AcceptedSocket, {tcp, nodelay}, false),
    {ok, false} = socket:getopt(AcceptedSocket, {tcp, nodelay}),

    ok = socket:close(ClientSocket),
    ok = socket:close(AcceptedSocket),
    ok = socket:close(ListenSocket),
    ok.

test_socket_opts() ->
    {ok, ListenSocket} = socket:open(inet, stream, tcp),
    ok = socket:bind(ListenSocket, #{family => inet, addr => loopback, port => 0}),

    {ok, false} = socket:getopt(ListenSocket, {tcp, nodelay}),
    ok = socket:setopt(ListenSocket, {tcp, nodelay}, true),
    {ok, true} = socket:getopt(ListenSocket, {tcp, nodelay}),

    ok = socket:listen(ListenSocket),

    % lwIP rejects IPPROTO_TCP options on listening sockets
    {error, einval} = socket:getopt(ListenSocket, {tcp, nodelay}),
    {error, einval} = socket:setopt(ListenSocket, {tcp, nodelay}, false),

    ok = socket:close(ListenSocket),
    ok.

test_socket_nodelay_errors() ->
    % A closed socket reports {error, closed}
    {ok, Socket} = socket:open(inet, stream, tcp),
    ok = socket:close(Socket),
    {error, closed} = socket:getopt(Socket, {tcp, nodelay}),
    {error, closed} = socket:setopt(Socket, {tcp, nodelay}, true),

    % UDP sockets do not support the TCP nodelay option
    {ok, UDPSocket} = socket:open(inet, dgram, udp),
    {error, _} = socket:setopt(UDPSocket, {tcp, nodelay}, true),
    {error, _} = socket:getopt(UDPSocket, {tcp, nodelay}),
    ok = socket:close(UDPSocket),
    ok.

wait_accept_select(ListenSocket, Ref) ->
    receive
        {'$socket', ListenSocket, select, Ref} ->
            ok
    after 10000 ->
        throw({timeout, accept_select})
    end.
