%
% This file is part of AtomVM.
%
% Copyright 2022 Paul Guyot <pguyot@kallisys.net>
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

%%-----------------------------------------------------------------------------
%% @doc PICO-specific APIs
%%
%% This module contains functions that are specific to the PICO platform.
%% @end
%%-----------------------------------------------------------------------------
-module(pico).

-export([
    rtc_set_datetime/1
]).

%%-----------------------------------------------------------------------------
%% @doc     Set the datetime on the RTC.
%%          The datetime can be obtained through bif erlang:localtime()
%% @end
%%-----------------------------------------------------------------------------
-spec rtc_set_datetime(calendar:datetime()) -> ok.
rtc_set_datetime(_Datetime) ->
    throw(nif_error).
