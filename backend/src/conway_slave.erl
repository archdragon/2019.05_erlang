%%% @author zofiapolkowska
%%% @copyright (C) 2019, zofiapolkowska
%%% @doc
%%%
%%% @end
%%% Created : 2019-06-04 18:06:41.713061

-module(conway_slave).

-behaviour(gen_server).

%% API
-export([start_link/0,
         init_state/5]).

%% Callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).
-define(PRINT(Var), io:format("DEBUG: ~p:~p - ~p~n~n ~p~n~n", [?MODULE, ?LINE, ??Var, Var])).

-record(state, {
  rect = null,
  current_gen = 0,
  max_gen = 1,
  node_name = ""
}).

%%% API

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init_state(Node, StartingRect, Gens, _Slaves, _W) ->
  io:format("Init State~n", []),
  gen_server:call({?MODULE, Node}, {init_state, Node, StartingRect, Gens}),
  gen_server:cast({?MODULE, Node}, {tick}).

%%% gen_server callbacks

init([]) ->
    io:format("Slave initialized~n", []),
    conway_master_worker:register_slave(node()),

    {ok, #state{}}.

handle_call({init_state, NodeName, StartingRect, Gens}, _From, State) ->
    Rect = [],
    NewState = #state{
        rect = StartingRect,
        current_gen = 0,
        max_gen = Gens,
        node_name = NodeName
    },
    {reply, ok, NewState}.

handle_cast({tick}, #state{max_gen = MaxGen, current_gen = CurrentGen} = State) when CurrentGen >= MaxGen ->
    {noreply, State};
handle_cast({tick}, State) ->
    % TODO: Pattern match
    NewGen = State#state.current_gen + 1,

    %Fields = rect:map(fun(x, y, value) -> update_cell(x, y, value, State#state.rect) end, State#state.rect),
    NewRect = rect:map(fun update_cell/3, State#state.rect),
    %NewRect = map:put(fields, Fields, State#state.rect),

    NewState = State#state{
        current_gen = NewGen,
        rect = NewRect},

    conway_master_worker:update_state(
        NewState#state.node_name,
        NewState#state.rect,
        NewState#state.current_gen),

    io:format("Tick: Generation ~p ~n", [current_gen]),

    timer:sleep(500),
    gen_server:cast({?MODULE, State#state.node_name}, {tick}),

    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
        {ok, State}.

%%% Internal functions

update_cell(X, Y, _Value) ->
    {{X, Y}, true}.
