-module(s).
-export([start/0]).


-define(GRAVITY, 0.4).
-define(AC, 0.2).
-define(ANGLE_AC, 0.002).
-define(FUEL_COST, 1.0).




%############################ SERVER START ################################################
start() ->
	startLogin(),
	serverStart().
startLogin() ->
	Contas = spawn(fun() -> loopContas(loadUsers()) end ),
	register(?MODULE, Contas).


loadUsers() ->
    case file:consult("users.dat") of
        {ok, [Data | _Rest]} -> Data;
        _ -> #{}
    end.

saveUsers(Map) ->
    File = "users.dat",
    io:format("~p~n", [Map]),
    ok = file:write_file(File, io_lib:format("~p.", [Map])).

serverStart() ->
	Room = spawn(fun() -> waitingRoom(#{}, []) end), 
	{ok, Lsock} = gen_tcp:listen(1, [ {packet, line}, {reuseaddr, true}]),
	spawn(fun() -> acceptor(Lsock, Room) end).

acceptor(Lsock, Room) ->
	try
		{ok, Sock} = gen_tcp:accept(Lsock),
		spawn(fun() -> acceptor(Lsock, Room) end),
		clientParser(Sock, Room, [])

	catch
		error:{badmatch,{error, closed}} ->
			ok
		end.



%############################################# PARSING DA INFORMAÇÃO RECEBIDA  #######################################################



clientParser(Socket, Room, MatchPid) ->

	receive
		{tcp, _, Data} ->
            String=string:trim(Data),
			case string:split(String, "#") of

                ["create_account", Info] ->
                    [User, Pass] = string:split(Info, " "),
					SelfPid = self(),
   					io:format("Current process PID: ~p~n", [SelfPid]),

					Tentativa = register_account(User, Pass),
					case Tentativa of
						ok ->
							Nivel = getLevel(User),
							Wstreak = getWstreak(User),
							NivelStr = integer_to_list(Nivel),
							WstreakStr = integer_to_list(Wstreak),
							gen_tcp:send(Socket,"new_acc " ++ NivelStr ++ " " ++ WstreakStr ++ "\n"),
							clientParser(Socket, Room, MatchPid);
						error ->
							gen_tcp:send(Socket, "error\n"),
							clientParser(Socket, Room, MatchPid)
					end;

	


                ["login", Info] ->
                    [User, Pass] = string:split(Info, " "),
					SelfPid = self(),
   					io:format("Current process PID: ~p~n", [SelfPid]),					

					Tentativa = login(User, Pass),
					case Tentativa of 
						ok ->
							Nivel = getLevel(User),
							Wstreak = getWstreak(User),
							NivelStr = integer_to_list(Nivel),
							WstreakStr = integer_to_list(Wstreak),
							gen_tcp:send(Socket,"logged_in " ++ NivelStr ++ " " ++ WstreakStr ++ "\n"),
							Room ! {user_connected, Socket, User},
							clientParser(Socket, Room, MatchPid);
						error ->
							gen_tcp:send(Socket, "error\n"),
							clientParser(Socket, Room, MatchPid)
					end;

				["scores", User] ->
							Nivel = getLevel(User),
							Wstreak = getWstreak(User),
							NivelStr = integer_to_list(Nivel),
							WstreakStr = integer_to_list(Wstreak),
							gen_tcp:send(Socket,"scores " ++ NivelStr ++ " " ++ WstreakStr ++ "\n"),
							clientParser(Socket, Room, MatchPid);



                ["logout", Info]->
                    [User|_] = string:split(Info, " "),
                    Tentativa = logout(User),
                    case Tentativa of 
						ok ->
							gen_tcp:send(Socket, "ok\n"),
							Room ! {user_disconnected, User},
							clientParser(Socket, Room, MatchPid);
						error ->
							gen_tcp:send(Socket, "error!\n"),
							clientParser(Socket, Room, MatchPid)
                    end;    

         
                ["play", Info] ->     
                    [User | _] = string:split(Info, " "),
					SelfPid = self(),
   					io:format("Current process PID: ~p~n", [SelfPid]),					
                    Room ! {play, User, getLevel(User), {Socket, self(),Room}},
				    clientParser(Socket, Room, []);

                
                ["remove", Info]->
                    [User , Pass] = string:split(Info, " "),
                    Tentativa =remove_account(User, Pass),
					case Tentativa of
						ok ->
							gen_tcp:send(Socket, "ok\n"),
							Room ! {user_disconnected, Socket, User},
							clientParser(Socket, Room, MatchPid);
						error ->
							gen_tcp:send(Socket, "error\n"),
							clientParser(Socket, Room, MatchPid)
					end;     



				["won", User] ->         
					SelfPid = self(),
					io:format("Current process PID: ~p~n", [SelfPid]),

					Tentativa = won_game(User),
					case Tentativa of
						ok ->
							gen_tcp:send(Socket, "vitoria adicionada\n"),
							clientParser(Socket, Room, []);
						error ->
							gen_tcp:send(Socket, "error\n"),
							clientParser(Socket, Room, [])
					end;	

				["lost", User] ->
					SelfPid = self(),
   					io:format("Current process PID: ~p~n", [SelfPid]),

					Tentativa = lost_game(User),
					case Tentativa of
						ok ->
							gen_tcp:send(Socket, "derrota adicionada\n"),
							clientParser(Socket, Room, []);
						error ->
							gen_tcp:send(Socket, "error\n"),
							clientParser(Socket, Room, [])
					end;


				["leaderboard", Info] ->
                    [User, Pass] = string:split(Info, " "),
					SelfPid = self(),
   					io:format("Current process PID: ~p~n", [SelfPid]),

					Tentativa = leaderboard(User, Pass),
					case Tentativa of
						{ok, Str} ->
							gen_tcp:send(Socket, Str++"\n"),
							clientParser(Socket, Room, []);
						error ->
							gen_tcp:send(Socket, "error\n"),
							clientParser(Socket, Room, [])
					end;				



				["move", Key]->
					case MatchPid of
						[]->
							clientParser(Socket, Room, MatchPid);
						_->
							MatchPid ! {move,Key, Socket},
							clientParser(Socket, Room, MatchPid)
					end;
					



				_->
					io:format("Unknown message ~n"),
					clientParser(Socket, Room, MatchPid)


			end;

		{game_over, MatchPid}->
			io:format("Game Over~n"),
			clientParser(Socket, Room, []);

		{gamePid, Match} ->
			io:format("Room received!~n"),
			clientParser(Socket, Room, Match);
		
		{tcp_closed, Socket} ->
            io:format("Socket closed unexpectedly. Terminating process.~n"),
            exit(normal);

        {error, Socket, Reason} ->
            io:format("Socket error: ~p. Terminating process.~n", [Reason]),
            exit(normal);

		_->
			io:format("Unknown message~n"),
			clientParser(Socket, Room, MatchPid)

	end.
	

%############################### WAITING ROOM ###################################################

waitingRoom(Users, Warmups) ->
	io:format("Warmup Rooms: ~p ~n", [Warmups]),
	receive 
		{user_connected, Sock, User} ->
			io:format("User " ++ User ++ " logged in! \n"),
			waitingRoom(maps:put(User, Sock, Users), Warmups);

		{user_disconnected, User} ->
			io:format("User " ++ User ++ " logged out!\n"),
			waitingRoom(maps:remove(User, Users), Warmups);

		{clear_room,Room} ->
			io:format("Clearing room ~n"),
			WarmupRoom = searchRoom(Warmups, Room),
			case WarmupRoom of
				null -> io:format("Not a valid room ~n");
				FullRoom -> waitingRoom(Users, Warmups -- [FullRoom])
			end;

		{play, User, Level, {Socket,From,WaitingRoomPid}} -> 
			MatchMaking = matchmaking(Warmups, {User, Level}),
			case MatchMaking of
				null ->  % se recebe null, cria nova sala de Warmup com aquele User e põe a sua média com o nivel do User
					io:format("Creating new warmup room!~n"),
					Warmup = spawn(fun() -> warmup(Level,[{User, Level, Socket,From}],null,WaitingRoomPid) end),
					Tuple = {Level,[{User,Level,Socket,From}], Warmup}, % {Media,[{Username, Level, Id Socket, Id Warmup room}]}
					NewWarmups = insertWarmup(Tuple,Warmups),
					io:format("~nUser ~p in new room: ~p ~n~n",[User,Warmup]),
					waitingRoom(Users, NewWarmups);
				
				{WarmupRoom} -> % se recebe uma sala, manda mensagem à sala para inserir lá dentro
					Room = searchRoom(Warmups, WarmupRoom),
					Players = element(2,Room),
					NewPlayers = Players ++ [{User,Level,Socket,From}],
					NewWarmups = updateRoom(Warmups,WarmupRoom,NewPlayers),
					WarmupRoom ! {new_player, {User, Level, Socket, From,WarmupRoom,WaitingRoomPid}}, % enviar o From para ter o PID do Cliente atual (veio do Client parser)
					io:format("User entering~n"),
					waitingRoom(Users, NewWarmups)
				end
		end.

% Aux para encontrar a sala corresponde ao Pid
searchRoom([], _) -> null;
searchRoom([{Media,Lista, Warmup} | _], WarmupPid) when Warmup == WarmupPid -> {Media,Lista,Warmup};
searchRoom([_| Warmups], WarmupPid) -> searchRoom(Warmups, WarmupPid).

% Aux para inserir novo jogador na Warmup respectiva
updateRoom([],_,_) -> null;
updateRoom([{Media,_,Warmup} | Tail], WarmupPid, Players) when (Warmup == WarmupPid) ->
	[{Media,Players,Warmup}|Tail];
updateRoom([_|Tail], WarmupPid, Players) -> 
	updateRoom(Tail,WarmupPid,Players).

% Aux para inserir uma Warmup na lista de todas as Warmups
insertWarmup(Tuple,[]) -> [Tuple];
insertWarmup(Tuple,Warmups) -> [Warmups | Tuple].



% ################################# MATCHMAKING E WARMUP ##########################################

% matchmaking :: [Warmups] -> User -> {Media, Lista}
matchmaking([],_) -> null;
matchmaking([{Media, Players, WarmupRoom}| _], {_,Level}) when (length(Players) =< 3) and (abs(Media - Level) =< 1)-> 
	{WarmupRoom}; % {Pid Warmup Room}
matchmaking(Warmups, User) -> matchmaking(tl(Warmups), User).


% warmup :: Float -> [Users] -> Msgs
warmup(Media, Players, TimerPid, WaitingRoomPid) ->
	% qd o warmup começa, começa timer de 5 sec
	receive
		{new_player, {User,Level,Socket,From,WarmupRoom,_}} ->
			case length(Players) of					
				1 ->
					Avg = newAvg(Media, length(Players), Level),
					io:format("~nUser ~p in room ~p ~n~n",[User,WarmupRoom]),
					NewPlayers = Players ++ [{User,Level,Socket,From}],
					TimePid = spawn(fun() -> timeHandler(WarmupRoom) end),
					warmup(Avg, NewPlayers,TimePid, WaitingRoomPid);

				_ ->
					Avg = newAvg(Media, length(Players), Level),
					io:format("~nUser ~p in room ~p ~n~n",[User,WarmupRoom]),
					NewPlayers = Players ++ [{User,Level,Socket,From}],
					TimerPid ! {reset},
					warmup(Avg, NewPlayers,TimerPid,WaitingRoomPid)
				end;
		
		{start_game} ->
			io:format("Starting game~n"),
			Users = [element(1, Player) || Player <- Players],
			Sockets = [element(3, Player) || Player <- Players],
			Froms = [element(4, Player) || Player <- Players],
			WaitingRoomPid ! {clear_room,self()},
			initGame(Sockets, Users, Froms)
	end.

timeHandler(From) ->
	io:format("Timer start: 5s ~n"),
	TimePid = timer:send_interval(5000, From, {start_game}),
	receive {reset} ->
		io:format("Timer reset: 5s ~n"),
		timer:cancel(TimePid),
		timeHandler(From)
	end.


newAvg(Media, N, Level) ->
	((Media * N) + Level) / (N+1).


%############################################## ESTADO INICIAL E COMEÇO DE JOGO ###################################################


initGame(Sockets, Users, Froms) ->
	[gen_tcp:send(Socket, "start\n") || Socket <- Sockets],
	PlayersState = initPlayerState(Sockets),
	Planetas= createPlanets(),
	PlanetsList = maps:to_list(Planetas),
	N=length(PlanetsList),
	[gen_tcp:send(S, "GAME "++integer_to_list(N)++"\n") || S<-Sockets],
	io:format("~p~n", [PlanetsList]),
	MatchPid = spawn(fun() -> match(PlayersState, Users, Sockets,[],Planetas,true)end),
	timer:send_interval(21, MatchPid, {update}),
	[F ! {gamePid,MatchPid} || F <-Froms],
	timer:send_after(120000, MatchPid, time_out),
	io:format("Game Starting~n").


createPlanets() ->
    Number = rand:uniform(2) + 2,
    Sun = #{1 => {773.0, 418.0, 50.0, 0.0 ,0.0, 0.0}}, % Sun  x - y - raio - distancia - vel_factor- angulo
	initPlanets(Number, Sun).

initPlanets(0, Planets) ->
    Planets;
initPlanets(N, Planets)->

	RandInt = rand:uniform(40 - 10 + 1) - 1,   % raio aleatorio
    RandFloat = rand:uniform(),
    Radius= 10 + RandInt + RandFloat,

	RandInt2 = rand:uniform(400 - 125) - 1,    % distancia aleatoria
    RandFloat2 = rand:uniform(),
    Dist = 125 + RandInt2 + RandFloat2,

    Speed = 0.3 + rand:uniform() * (1.5 - 0.3),  % velocidade aleatoria

    Angle = round(360), 
    
    PositionX = 500.0 + Dist * math:cos(Angle),
    PositionY = 500.0 + Dist * math:sin(Angle),
    
    FloatPositionX = float(PositionX),
    FloatPositionY = float(PositionY),

    NewPlanet = #{N+1 => {FloatPositionX, FloatPositionY, Radius, Dist,Speed,0.0}},
    
    NewPlanets = maps:merge(Planets, NewPlanet),
    
    initPlanets(N - 1, NewPlanets).



%%	______     posx
%%	______     posy
%%    0.0,     angle
%%    0.0,     anglespeed
%%    0.0,     speed
%%    100.0,   fuel

initPlayerState([]) ->					 			                        
	#{};
initPlayerState([Sock1,Sock2]) ->
	#{Sock1 => {75.0, 761.0, 0.0, 0.0, 0.0, 1000.0}, Sock2 => {1471.0, 761.0, 0.0, 0.0, 0.0, 1000.0}};
initPlayerState([Sock1,Sock2,Sock3]) ->
	#{Sock1 => {75.0, 761.0, 0.0, 0.0, 0.0, 1000.0}, Sock2 => {1471.0, 761.0, 0.0, 0.0, 0.0, 1000.0}, Sock3 => {75.0, 75.0, 0.0, 0.0, 0.0, 1000.0}};
initPlayerState([Sock1,Sock2,Sock3,Sock4]) ->
	#{Sock1 => {75.0, 761.0, 0.0, 0.0, 0.0, 1000.0}, Sock2 => {1471.0, 761.0, 0.0, 0.0, 0.0, 1000.0}, Sock3 => {75.0, 75.0, 0.0, 0.0, 0.0, 1000.0}, Sock4 => {1471.0, 75.0, 0.0, 0.0, 0.0, 1000.0}}.




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Envio de informação para os jogadores %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sendGameInfo(PlayersState, [Socket1,Socket2],Str) -> 
	gen_tcp:send(Socket1, list_to_binary("playerUpdate " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket2, PlayersState) ++ " " ++ Str ++ "\n")),
	gen_tcp:send(Socket2, list_to_binary("playerUpdate " ++ buildPlayer(Socket2, PlayersState) ++ " " ++ buildPlayer(Socket1, PlayersState) ++" " ++ Str ++ "\n"));

sendGameInfo(PlayersState, [Socket1,Socket2,Socket3],Str) ->
	gen_tcp:send(Socket1, list_to_binary("playerUpdate " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket2, PlayersState) ++ " " ++ buildPlayer(Socket3, PlayersState) ++" " ++ Str ++ "\n")),
	gen_tcp:send(Socket2, list_to_binary("playerUpdate " ++ buildPlayer(Socket2, PlayersState) ++  " " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket3, PlayersState) ++" " ++ Str ++ "\n")),
	gen_tcp:send(Socket3, list_to_binary("playerUpdate " ++ buildPlayer(Socket3, PlayersState) ++  " " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket2, PlayersState) ++" " ++ Str ++ "\n"));

sendGameInfo(PlayersState, [Socket1, Socket2, Socket3, Socket4],Str) ->
    gen_tcp:send(Socket1, list_to_binary("playerUpdate " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket2, PlayersState) ++ " " ++ buildPlayer(Socket3, PlayersState) ++ " " ++ buildPlayer(Socket4, PlayersState) ++" " ++ Str ++ "\n")),
	gen_tcp:send(Socket2, list_to_binary("playerUpdate " ++ buildPlayer(Socket2, PlayersState) ++ " " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket3, PlayersState) ++ " " ++ buildPlayer(Socket4, PlayersState) ++ " " ++ Str ++"\n")),
	gen_tcp:send(Socket3, list_to_binary("playerUpdate " ++ buildPlayer(Socket3, PlayersState) ++ " " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket2, PlayersState) ++ " " ++ buildPlayer(Socket4, PlayersState) ++ " " ++ Str ++"\n")),
	gen_tcp:send(Socket4, list_to_binary("playerUpdate " ++ buildPlayer(Socket4, PlayersState) ++ " " ++ buildPlayer(Socket1, PlayersState) ++ " " ++ buildPlayer(Socket2, PlayersState) ++ " " ++ buildPlayer(Socket3, PlayersState) ++ " " ++ Str ++"\n")).



game_over([],_,[])->
	ok;

game_over([Sock | Sockets], Losers, [U | Users]) ->   %atualiza os niveis e wins dos jogadores, diz aos users se perderam ou ganharam
	case lists:member(Sock, Losers) of
		false ->
			gen_tcp:send(Sock, list_to_binary("WON\n")),won_game(U),game_over(Sockets,Losers,Users);
		true ->
			gen_tcp:send(Sock, list_to_binary("LOST\n")),lost_game(U),game_over(Sockets,Losers,Users)
	end.


time_over(Sockets,Losers,Users) ->                 %se o tempo acabou e existe um jogador sobrevivente, esse ganha, se nao, perdem todos
	case length(Losers)==length(Sockets)-1 of
		true->game_over(Sockets,Losers,Users);

		false->game_over(Sockets,Sockets,Users)
	end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       JOGO       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


match(PlayersState, Users, Sockets,Losers,Planets,Flag) ->

	case (length(Losers)==length(Sockets)) of
		true->game_over(Sockets,Sockets,Users);

		false->
			case (length(Losers)==length(Sockets)-1) and (Flag==true) of
				true->
					timer:send_after(5000, finish),
					io:format("5s to end ~n~n"),
					match(PlayersState, Users, Sockets, Losers,Planets,false);


				false->
					receive

						finish ->
							io:format("Timer received~n~n"),
							game_over(Sockets,Losers,Users);

						time_out->
							time_over(Sockets,Losers,Users);

						{move,Key,Sock}->
							case lists:member(Sock, Losers) of
								true -> match(PlayersState,Users, Sockets, Losers,Planets,Flag);
								false -> 
									match(movimento(Key, PlayersState, Sock), Users, Sockets, Losers,Planets,Flag)
							end;


						{update} ->

							{PlayersState2,Losers2}=checkBorders(PlayersState,Sockets,Losers),
							{PlayersState3,Losers3}=checkPlanets(PlayersState2,Sockets, Planets, Losers2),
							Planets2 = movePlanets(Planets),
							PlayersState4=movePlayers(PlayersState3,Losers3),
							PlayersState5=playerCol(PlayersState4),
							sendGameInfo(PlayersState5,Sockets,buildPlanets(Planets2)),
							match(PlayersState5,Users, Sockets, Losers3,Planets2,Flag);

						_->
							io:format("Unknown Message~n"),
							match(PlayersState,Users, Sockets, Losers,Planets,Flag)
					end
				end
			end.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Deteção de colisao para jogadores, planetas e bordas  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

playerCol(Map) ->
    Keys = maps:keys(Map),
    UpdatedMap = check_collisions(Keys, Map),
    UpdatedMap.


check_collisions([], Map) -> 
    Map;

check_collisions([Key1 | RestKeys], Map) ->
    UpdatedMap = lists:foldl(fun(Key2, AccMap) ->
        check_and_update(Key1, Key2, AccMap)
    end, Map, RestKeys),
    check_collisions(RestKeys, UpdatedMap).


check_and_update(Key1, Key2, Map) ->
    {X1, Y1, A1, As1, V1, F1} = maps:get(Key1, Map),
    {X2, Y2, A2, As2, V2, F2} = maps:get(Key2, Map),
    Distance = math:sqrt(math:pow(X1 - X2, 2) + math:pow(Y1 - Y2, 2)),
    case Distance < 50 of
        true ->
            Map1 = maps:update(Key1, {X1, Y1, A1 + 180, As1, V2, F1}, Map),
            maps:update(Key2, {X2, Y2, A2 + 180, As2, V1, F2}, Map1);
        false ->
            Map
    end.



checkBorders(PlayerState, [], LostAcc) -> {PlayerState, LostAcc};

checkBorders(PlayerState, [Socket1 | Socks], LostAcc) ->
    {X, Y, E1, E2, E3, E4} = maps:get(Socket1, PlayerState),
    case lists:member(Socket1, LostAcc) of
        true ->
            checkBorders(PlayerState, Socks, LostAcc);
        false ->
            case (Y < 25) orelse (Y > 811) orelse (X < 25) orelse (X > 1521) of
                true ->
                    UpdatedPlayerState = maps:put(Socket1, {-100.0, -100.0, E1, E2, E3, E4}, PlayerState),
                    checkBorders(UpdatedPlayerState, Socks, LostAcc ++ [Socket1]);
                false ->
                    checkBorders(PlayerState, Socks, LostAcc)
            end
    end.




checkPlanets(PlayersState, Sockets, Planets, Lost) ->
    lists:foldl(
        fun(Socket, {PState, LAcc}) -> checkPlanetsaux(PState, Socket, Planets, LAcc) end,
        {PlayersState, Lost},
        Sockets
    ).


checkPlanetsaux(PlayerState, Socket, Planets, LostAcc) ->
    case lists:member(Socket, LostAcc) of
        true ->
            {PlayerState, LostAcc};
        false ->
            {X, Y, E1, E2, E3, E4} = maps:get(Socket, PlayerState),
            lists:foldl(
                fun({_Key, {PX, PY, PR, _, _, _}}, {PS, LA}) ->
                    Dist = math:sqrt(math:pow(PX - X, 2) + math:pow(PY - Y, 2)),
                    case Dist < 25.5 + PR of
                        true ->
                            io:format("Colision - Planet~n"),
                            UpdatedPlayerState = maps:put(Socket, {-100.0, -100.0, E1, E2, E3, E4}, PS),
                            {UpdatedPlayerState, LA ++ [Socket]};
                        false ->
                            {PS, LA}
                    end
                end,
                {PlayerState, LostAcc},
                maps:to_list(Planets)
            )
    end.






%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% movimentação de jogadores e planetas %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



movePlanets(Map)->
	case maps:size(Map) of
		6->movePlanets6(Map);
		5->movePlanets5(Map);
		4->movePlanets4(Map);
		3->movePlanets3(Map)
	end.	

movePlanets3(Map) -> %x - y - raio - distancia - vel_factor- angulo
    CenterX = 773.0, 
    CenterY = 418.0, 
    #{1 := {X1, Y1, R1, D1, V1, Angle1}, 
      2 := {X2, Y2, R2, D2, V2, Angle2}, 
      3 := {X3, Y3, R3, D3, V3, Angle3}} = Map,

    NewAngle2 = Angle2 + (0.01*V2),
    NewAngle3 = Angle3 + (0.01*V3),

    TranslatedX2 = X2 - CenterX,
    TranslatedY2 = Y2 - CenterY,
    TranslatedX3 = X3 - CenterX,
    TranslatedY3 = Y3 - CenterY,

    NewX2 = CenterX + math:cos(NewAngle2) * TranslatedX2 - math:sin(NewAngle2) * TranslatedY2,
    NewY2 = CenterY + math:sin(NewAngle2) * TranslatedX2 + math:cos(NewAngle2) * TranslatedY2,
    NewX3 = CenterX + math:cos(NewAngle3) * TranslatedX3 - math:sin(NewAngle3) * TranslatedY3,
    NewY3 = CenterY + math:sin(NewAngle3) * TranslatedX3 + math:cos(NewAngle3) * TranslatedY3,

    #{1 => {X1, Y1, R1, D1,V1, Angle1}, 
      2 => {NewX2, NewY2, R2, D2, V2, Angle2}, 
      3 => {NewX3, NewY3, R3, D3, V3, Angle3}}.



movePlanets4(Map) ->
    CenterX = 773.0,
    CenterY = 418.0, 
    #{1 := {X1, Y1, R1, D1, V1, Angle1}, 
      2 := {X2, Y2, R2, D2, V2, Angle2}, 
      3 := {X3, Y3, R3, D3, V3, Angle3},
      4 := {X4, Y4, R4, D4, V4, Angle4}} = Map,

    NewAngle2 = Angle2 + (0.01 * V2),
    NewAngle3 = Angle3 + (0.01 * V3),
    NewAngle4 = Angle4 + (0.01 * V4),

    TranslatedX2 = X2 - CenterX,
    TranslatedY2 = Y2 - CenterY,
    TranslatedX3 = X3 - CenterX,
    TranslatedY3 = Y3 - CenterY,
    TranslatedX4 = X4 - CenterX,
    TranslatedY4 = Y4 - CenterY,

    NewX2 = CenterX + math:cos(NewAngle2) * TranslatedX2 - math:sin(NewAngle2) * TranslatedY2,
    NewY2 = CenterY + math:sin(NewAngle2) * TranslatedX2 + math:cos(NewAngle2) * TranslatedY2,
    NewX3 = CenterX + math:cos(NewAngle3) * TranslatedX3 - math:sin(NewAngle3) * TranslatedY3,
    NewY3 = CenterY + math:sin(NewAngle3) * TranslatedX3 + math:cos(NewAngle3) * TranslatedY3,
    NewX4 = CenterX + math:cos(NewAngle4) * TranslatedX4 - math:sin(NewAngle4) * TranslatedY4,
    NewY4 = CenterY + math:sin(NewAngle4) * TranslatedX4 + math:cos(NewAngle4) * TranslatedY4,

    #{1 => {X1, Y1, R1, D1, V1, Angle1}, 
      2 => {NewX2, NewY2, R2, D2, V2, Angle2}, 
      3 => {NewX3, NewY3, R3, D3, V3, Angle3},
      4 => {NewX4, NewY4, R4, D4, V4, Angle4}}.


movePlanets5(Map) ->
    CenterX = 773.0,
    CenterY = 418.0, 

    #{1 := {X1, Y1, R1, D1, V1, Angle1}, 
      2 := {X2, Y2, R2, D2, V2, Angle2}, 
      3 := {X3, Y3, R3, D3, V3, Angle3},
      4 := {X4, Y4, R4, D4, V4, Angle4},
      5 := {X5, Y5, R5, D5, V5, Angle5}} = Map,

    NewAngle2 = Angle2 + (0.01 * V2),
    NewAngle3 = Angle3 + (0.01 * V3),
    NewAngle4 = Angle4 + (0.01 * V4),
    NewAngle5 = Angle5 + (0.01 * V5),

    TranslatedX2 = X2 - CenterX,
    TranslatedY2 = Y2 - CenterY,
    TranslatedX3 = X3 - CenterX,
    TranslatedY3 = Y3 - CenterY,
    TranslatedX4 = X4 - CenterX,
    TranslatedY4 = Y4 - CenterY,
    TranslatedX5 = X5 - CenterX,
    TranslatedY5 = Y5 - CenterY,

    NewX2 = CenterX + math:cos(NewAngle2) * TranslatedX2 - math:sin(NewAngle2) * TranslatedY2,
    NewY2 = CenterY + math:sin(NewAngle2) * TranslatedX2 + math:cos(NewAngle2) * TranslatedY2,
    NewX3 = CenterX + math:cos(NewAngle3) * TranslatedX3 - math:sin(NewAngle3) * TranslatedY3,
    NewY3 = CenterY + math:sin(NewAngle3) * TranslatedX3 + math:cos(NewAngle3) * TranslatedY3,
    NewX4 = CenterX + math:cos(NewAngle4) * TranslatedX4 - math:sin(NewAngle4) * TranslatedY4,
    NewY4 = CenterY + math:sin(NewAngle4) * TranslatedX4 + math:cos(NewAngle4) * TranslatedY4,
    NewX5 = CenterX + math:cos(NewAngle5) * TranslatedX5 - math:sin(NewAngle5) * TranslatedY5,
    NewY5 = CenterY + math:sin(NewAngle5) * TranslatedX5 + math:cos(NewAngle5) * TranslatedY5,

    #{1 => {X1, Y1, R1, D1, V1, Angle1}, 
      2 => {NewX2, NewY2, R2, D2, V2, Angle2}, 
      3 => {NewX3, NewY3, R3, D3, V3, Angle3},
      4 => {NewX4, NewY4, R4, D4, V4, Angle4},
      5 => {NewX5, NewY5, R5, D5, V5, Angle5}}.


movePlanets6(Map) ->
    CenterX = 773.0,
    CenterY = 418.0,

    #{1 := {X1, Y1, R1, D1, V1, Angle1}, 
      2 := {X2, Y2, R2, D2, V2, Angle2}, 
      3 := {X3, Y3, R3, D3, V3, Angle3},
      4 := {X4, Y4, R4, D4, V4, Angle4},
      5 := {X5, Y5, R5, D5, V5, Angle5},
      6 := {X6, Y6, R6, D6, V6, Angle6}} = Map,

    NewAngle2 = Angle2 + (0.01 * V2),
    NewAngle3 = Angle3 + (0.01 * V3),
    NewAngle4 = Angle4 + (0.01 * V4),
    NewAngle5 = Angle5 + (0.01 * V5),
    NewAngle6 = Angle6 + (0.01 * V6),

    TranslatedX2 = X2 - CenterX,
    TranslatedY2 = Y2 - CenterY,
    TranslatedX3 = X3 - CenterX,
    TranslatedY3 = Y3 - CenterY,
    TranslatedX4 = X4 - CenterX,
    TranslatedY4 = Y4 - CenterY,
    TranslatedX5 = X5 - CenterX,
    TranslatedY5 = Y5 - CenterY,
    TranslatedX6 = X6 - CenterX,
    TranslatedY6 = Y6 - CenterY,

    NewX2 = CenterX + math:cos(NewAngle2) * TranslatedX2 - math:sin(NewAngle2) * TranslatedY2,
    NewY2 = CenterY + math:sin(NewAngle2) * TranslatedX2 + math:cos(NewAngle2) * TranslatedY2,
    NewX3 = CenterX + math:cos(NewAngle3) * TranslatedX3 - math:sin(NewAngle3) * TranslatedY3,
    NewY3 = CenterY + math:sin(NewAngle3) * TranslatedX3 + math:cos(NewAngle3) * TranslatedY3,
    NewX4 = CenterX + math:cos(NewAngle4) * TranslatedX4 - math:sin(NewAngle4) * TranslatedY4,
    NewY4 = CenterY + math:sin(NewAngle4) * TranslatedX4 + math:cos(NewAngle4) * TranslatedY4,
    NewX5 = CenterX + math:cos(NewAngle5) * TranslatedX5 - math:sin(NewAngle5) * TranslatedY5,
    NewY5 = CenterY + math:sin(NewAngle5) * TranslatedX5 + math:cos(NewAngle5) * TranslatedY5,
    NewX6 = CenterX + math:cos(NewAngle6) * TranslatedX6 - math:sin(NewAngle6) * TranslatedY6,
    NewY6 = CenterY + math:sin(NewAngle6) * TranslatedX6 + math:cos(NewAngle6) * TranslatedY6,

    #{1 => {X1, Y1, R1, D1, V1, Angle1}, 
      2 => {NewX2, NewY2, R2, D2, V2, Angle2}, 
      3 => {NewX3, NewY3, R3, D3, V3, Angle3},
      4 => {NewX4, NewY4, R4, D4, V4, Angle4},
      5 => {NewX5, NewY5, R5, D5, V5, Angle5},
      6 => {NewX6, NewY6, R6, D6, V6, Angle6}}.




incMovimento(Sock, PlayersState) ->
	case maps:get(Sock, PlayersState) of
		{X,Y, Angle, AngleSpeed, Speed, Fuel} ->
			maps:update(Sock, {X, Y, Angle, AngleSpeed, Speed+?AC, Fuel -?FUEL_COST}, PlayersState);

		_ ->
			PlayersState
	end.

rotateRight(Sock, PlayersState) ->         
	case maps:get(Sock, PlayersState) of
		{X,Y, Angle, AngleSpeed, Speed, Fuel} ->
			maps:update(Sock, {X, Y, Angle,  AngleSpeed-?ANGLE_AC, Speed,Fuel-?FUEL_COST }, PlayersState);
			
		_ ->
			PlayersState
	end.

rotateLeft(Sock, PlayersState) ->               
	case maps:get(Sock, PlayersState) of
		{X,Y, Angle, AngleSpeed, Speed, Fuel} ->
			maps:update(Sock, {X, Y, Angle, AngleSpeed+?ANGLE_AC, Speed, Fuel-?FUEL_COST}, PlayersState);

		_ ->
			PlayersState
	end.





movimento(Key, PlayersState, Sock) ->

	{X,Y, Angle, AngleSpeed, Speed, Fuel} = maps:get(Sock, PlayersState),
	case Fuel < ?FUEL_COST of
		true-> maps:update(Sock, {X,Y,Angle,AngleSpeed,Speed,0.0},PlayersState);
		false->	
			case Key of
				"front" ->
					incMovimento(Sock, PlayersState);
				"right" ->
					rotateRight(Sock, PlayersState);
				"left" ->
					rotateLeft(Sock, PlayersState)
			end
	end.

	
movePlayers(PlayersState, Losers) ->
    PlayerList = maps:to_list(PlayersState),
    
    UpdatedPlayerList = lists:map(
        fun({Key, Value}) ->
            case lists:member(Key, Losers) of
                true -> 
                    {Key, Value}; 
                false -> 
                    {Key, movePlayer(Value)} 
            end
        end,
        PlayerList),
    
    UpdatedPlayersState = maps:from_list(UpdatedPlayerList),
    UpdatedPlayersState.


movePlayer({X,Y,Angle,AngleSpeed,Speed,Fuel})-> 
	if 
		(X > 773.0) and (Y > 418.0) ->
			{(round(10 * (X + Speed * math:cos(Angle)-?GRAVITY)) / 10),(round(10 * (Y + Speed * math:sin(Angle)-?GRAVITY)) / 10),Angle + AngleSpeed,AngleSpeed,Speed,Fuel};

		(X < 773.0) and (Y > 418.0) ->
			{(round(10 * (X + Speed * math:cos(Angle)+?GRAVITY)) / 10),(round(10 * (Y + Speed * math:sin(Angle)-?GRAVITY)) / 10),Angle + AngleSpeed,AngleSpeed,Speed,Fuel};

		(X < 773.0) and (Y < 418.0) ->
			{(round(10 * (X + Speed * math:cos(Angle)+?GRAVITY)) / 10),(round(10 * (Y + Speed * math:sin(Angle)+?GRAVITY)) / 10),Angle + AngleSpeed,AngleSpeed,Speed,Fuel};

		true ->
			{(round(10 * (X + Speed * math:cos(Angle)-?GRAVITY)) / 10),(round(10 * (Y + Speed * math:sin(Angle)+?GRAVITY)) / 10),Angle + AngleSpeed,AngleSpeed,Speed,Fuel}
	end.







%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  converter o estado do jogo em string para enviar aos users %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


buildPlanets(Map) ->
    buildPlanets_aux(Map, maps:keys(Map), "").

buildPlanets_aux(_, [], Acc) ->
    string:trim(Acc);

buildPlanets_aux(Map, [Key | RestKeys], Acc) ->
    {X, Y, R, _, _, _} = maps:get(Key, Map),
    NewAcc = Acc ++ "P " ++ float_to_list(X, [{decimals, 1}]) ++ " " ++ float_to_list(Y, [{decimals, 1}]) ++ " " ++ float_to_list(R, [{decimals, 1}]) ++ " ",
    buildPlanets_aux(Map, RestKeys, NewAcc).



buildPlayer(Sock, PlayersState) ->
	case maps:get(Sock, PlayersState) of
		{X,Y,Angle,_, _, _} ->
			(float_to_list(X,[{decimals,1}]) ++ " " ++ float_to_list(Y,[{decimals,1}]) ++ " " ++ 
				float_to_list(Angle,[{decimals,1}]));
		_ -> true
	end.



%############################################### MAPA DE CONTAS ######################################################################
	
loopContas(Map) ->
	receive
		{{register, User, Pass}, From} ->
			case maps:is_key(User, Map) of
			 	true -> From ! {?MODULE, error}, loopContas(Map);
			 	false -> 
					From ! {?MODULE, ok},                                % user -> pass, on/off, level, win
					NewMap = maps:put(User,{Pass,online, 1, 0},Map), 
					saveUsers(NewMap),
					loopContas(NewMap)			

			end;
		{{remove, User, Pass}, From} ->
			case maps:find(User, Map) of
				{ok, {Pass, _, _, _}} -> 
					From ! {?MODULE, ok},
					NewMap = maps:remove(User,Map),
					saveUsers(NewMap),
					loopContas(NewMap);
				_ -> From ! {?MODULE, error},loopContas(Map)
			end;
		{{login, User, Pass}, From} ->
			case maps:find(User, Map) of
				{ok, {Pass, offline, Level, Wstreak}} -> 
					From ! {?MODULE, ok},
					NewMap = maps:update(User,{Pass,online, Level, Wstreak},Map),
					saveUsers(NewMap),
					loopContas(NewMap);			
				_ -> From ! {?MODULE, error}, loopContas(Map)
			end;
		{{logout, User}, From} ->                                       
			case maps:find(User, Map) of
				{ok, {Pass, online, Level, Wstreak}} -> 
					From ! {?MODULE, ok},
					NewMap = maps:update(User,{Pass,offline, Level, Wstreak},Map),
					saveUsers(NewMap),
					loopContas(NewMap);				
				_ -> From ! {?MODULE, error}, loopContas(Map)
			end;

		{{won, User}, From}->
			case maps:find(User,Map) of 
				{ok, {Pass, online, Level, Wstreak}} -> 
					From ! {?MODULE, ok},

				NewWstreak = 
					case Wstreak =< 0 of
						true -> 1;
						false -> Wstreak + 1
					end,
					
				NewMap= maps:update(User,{Pass,online, Level, NewWstreak},Map),
				io:format("New Victory~n"),


				FinalMap =
					case NewWstreak == Level of
						true -> 
							maps:update(User,{Pass,online, Level+1,0},NewMap);
						false->
							NewMap
					end,

				saveUsers(FinalMap),
				loopContas(FinalMap);						

				_ -> From ! {?MODULE, error}, loopContas(Map)
			end;	


		{{lost, User}, From}->
			case maps:find(User,Map) of 
				{ok, {Pass, online, Level, Wstreak}} -> 
					From ! {?MODULE, ok},

					NewWstreak = 
						case Wstreak =< 0 of
							true -> Wstreak-1;
							false -> -1
						end,

					NewMap= maps:update(User,{Pass,online, Level, NewWstreak},Map),

					FinalMap =
						case (((-NewWstreak == (Level div 2) +1) and (Level rem 2 /= 0)) or ((-NewWstreak == (Level div 2)) and (Level rem 2 == 0))) and (Level>1) of
							true -> 
								maps:update(User,{Pass,online, Level-1,0},NewMap);
							false->
								NewMap
						end,	

					saveUsers(FinalMap),
					loopContas(FinalMap);

				_ -> From ! {?MODULE, error}, loopContas(Map)
			end;



		{{leaderboard, User, Pass}, From}->
			case maps:find(User,Map) of 
				{ok, {Pass, online, _, _}} -> 
					Str = getTopTen(Map),
					From ! {?MODULE, {ok,Str}},
					loopContas(Map);




				_ -> From ! {?MODULE, error}, loopContas(Map)
			end;							


		
		{{getlevel, User}, From} ->
			case maps:find(User, Map) of
				{ok, {_, _, Level, _}} -> From ! {?MODULE, Level}, loopContas(Map);
				_ -> From ! {?MODULE, error}, loopContas(Map)
			end;

		{{getWstreak, User}, From} ->
			case maps:find(User, Map) of
				{ok, {_, _,_, W}} -> From ! {?MODULE, W}, loopContas(Map);
				_ -> From ! {?MODULE, error}, loopContas(Map)
			end


	end.



convert(Map) ->
    maps:fold(fun(Key, ValueTuple, Acc) ->
        List = [Key | tuple_to_list(ValueTuple)],
        [List | Acc]
    end, [], Map).

getTopTen(Map) ->
    List = convert(Map),
    
    Comp2 = fun([_, _, _, Level1,_], [_, _, _, Level2,_]) -> Level1 >= Level2 end,
	Comp1 = fun([_, _, _, _,W1], [_, _, _, _,W2]) -> W1 >= W2 end,
    
    Sort1 = lists:sort(Comp1, List),
	Sort2 = lists:sort(Comp2, Sort1),
	TopTen = lists:sublist(Sort2, 10),

	Str = getTopTenStr(TopTen),
	Str.

getTopTenStr([]) ->
    ""; 

getTopTenStr([[U, _, _, Level, W] | Elems]) ->
    Str = io_lib:format("~p ~p ~p", [U, Level, W]),
    Str ++ " " ++ getTopTenStr(Elems).




% operações de contas %

request(Msg) ->
	?MODULE ! {Msg, self()},
	receive
		{?MODULE, Tentativa} -> Tentativa
	end.

won_game(Username)->
	request({won, Username}).

lost_game(Username)->
	request({lost, Username}).

register_account(Username, Pass) ->
	request({register, Username, Pass}).

remove_account(Username, Pass) ->
	request({remove, Username, Pass}).

login(Username, Pass) -> 
	request({login, Username, Pass}).

logout(Username) -> 
	request({logout, Username}).


leaderboard(Username,Pass)->
	request({leaderboard, Username, Pass}).


getLevel(Username) -> 
	request({getlevel, Username}).

getWstreak(Username) ->
	request({getWstreak, Username}).