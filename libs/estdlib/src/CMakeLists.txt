##
## Copyright (c) 2018 Fred Dushin <fred@dushin.net>
##

project(estdlib)

include(BuildErlang)

set(ERLANG_MODULES
    calendar
    gen_server
    gen_statem
    gen_udp
    gen_tcp
    inet
    io_lib
    io
    lists
    proplists
    string
    timer
    erlang
)

pack_archive(estdlib ${ERLANG_MODULES})

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/estdlib.avm DESTINATION lib/AtomVM/ebin)