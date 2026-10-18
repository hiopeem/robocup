% library for creating graphical elements
:- use_module(library(pce)).

% --- Static Game Elements ---
% Defines fixed goal position for each team.
goal(team1, position(0, 25)).    % Team 1 defends left goal
goal(team2, position(100, 25)).  % Team 2 defends right goal

% --- Dynamic Game State ---
% Tracks the ball’s position, changing when it interacts with players.
:- dynamic ball/1.
ball(position(50, 25)).  % Ball starts at center of the field

% Tracks player states: team, role, position (X,Y), stamina, and facing angle (degrees).
:- dynamic player/5.
player(team1, forward1, position(40, 40), stamina(100), 0).
player(team1, forward2, position(35, 10), stamina(100), 0).
player(team1, defender1, position(30, 30), stamina(100), 0).
player(team1, defender2, position(25, 20), stamina(100), 0).
player(team1, goalkeeper, position(5, 25), stamina(100), 90).
player(team2, forward1, position(60, 10), stamina(100), 180).
player(team2, forward2, position(65, 40), stamina(100), 180).
player(team2, defender1, position(70, 20), stamina(100), 180).
player(team2, defender2, position(75, 30), stamina(100), 180).
player(team2, goalkeeper, position(95, 25), stamina(100), 90).

% Tracks scores for both teams, updated when goals are scored.
:- dynamic score/2.
score(team1, 0).
score(team2, 0).

% Check whether the simulation is stopped via the GUI button.
:- dynamic stopped/1.
stopped(false).

% --- Vision ---
% Defines the vision cone for players (90° total, 45° on each side of facing direction).
vision_angle(45).    % Half of the total cone angle

% --- Helper Predicates ---
% Determines if a player can see a target (ball or goal) within their vision cone.
see(Team, Role, TargetX, TargetY) :-
    player(Team, Role, position(X, Y), stamina(_), Facing),
    vision_angle(HalfAngle),
    DX is TargetX - X,
    DY is TargetY - Y,
    (DX = 0, DY = 0 -> AngleToTarget = Facing
    ; AngleToTarget is atan2(DY, DX) * 180 / pi),
    NormFacing is round(Facing) mod 360,
    NormTarget is round(AngleToTarget + 360) mod 360,
    AngleDiff is min((NormTarget - NormFacing + 360) mod 360, (NormFacing - NormTarget + 360) mod 360),
    AngleDiff =< HalfAngle.

% Checks if all players have zero stamina, if then, ending the game.
all_stamina_zero :-
    findall(Stamina, player(_, _, _, stamina(Stamina), _), Staminas),
    forall(member(S, Staminas), S = 0).

% Checks if only goalkeepers have stamina left, also ending the game.
only_goalkeepers_have_stamina :-
    findall(Stamina-Role, player(_, Role, _, stamina(Stamina), _), StaminaRoles),
    forall(member(Stamina-Role, StaminaRoles),
           (Role \= goalkeeper -> Stamina = 0 ; true)),
    player(team1, goalkeeper, _, stamina(S1), _), S1 > 0,
    player(team2, goalkeeper, _, stamina(S2), _), S2 > 0.

% --- GUI Setup ---
% Initializes the visualizations: field, goals, players, ball, score, and buttons.
init_gui :-
    new(Window, window('Soccer Simulation', size(500, 250))),
    send(Window, open),
    draw_field(Window),
    draw_goals(Window),
    draw_players(Window),
    draw_ball(Window),
    draw_score(Window),
    draw_buttons(Window),
    assertz(gui_window(Window)),
    retractall(stopped(_)),
    assertz(stopped(false)).

% Draws the soccer field (green background, midline, center circle).
draw_field(Window) :-
    send(Window, display, new(_, box(500, 250)), point(0, 0)),
    send(Window, background, colour('#00AB66')),
    new(Line, line(250, 0, 250, 250)),
    send(Line, colour, colour(white)),
    send(Window, display, Line, point(0, 0)),
    new(Circle, circle(90)),
    send(Circle, colour, colour(white)),
    send(Window, display, Circle, point(205, 80)).

% Draws goalpost on both ends of the field.
draw_goals(Window) :-
    send(Window, display, new(_, box(20, 60)), point(480, 95)),
    send(Window, display, new(_, box(20, 60)), point(0, 95)).

% Draws players as colored circle (blue for team1, red for team2).
draw_players(Window) :-
    retractall(player_object(_, _)),
    forall(player(Team, Role, position(X, Y), _, _),
           (((Team = team1, Colour = blue) ; (Team = team2, Colour = red)),
            ScaleX is X * 5, ScaleY is Y * 5,
            send(Window, display, new(P, circle(10)), point(ScaleX-5, ScaleY-5)),
            send(P, fill_pattern, colour(Colour)),
            atom_concat(Team, '_', Tmp),
            atom_concat(Tmp, Role, Id),
            assertz(player_object(Id, P)))),
    send(Window, flush).

% Draws the ball as a white circle.
draw_ball(Window) :-
    retractall(ball_object(_)),
    ball(position(X, Y)),
    ScaleX is X * 5, ScaleY is Y * 5,
    send(Window, display, new(B, circle(8)), point(ScaleX-4, ScaleY-4)),
    send(B, fill_pattern, colour(white)),
    assertz(ball_object(B)).

% Draws the score display (yellow text on a 0.5 transparent black background).
draw_score(Window) :-
    score(team1, S1),
    score(team2, S2),
    format(atom(ScoreText), '~w-~w', [S1, S2]),
    new(ScoreObj, text(ScoreText)),
    send(ScoreObj, font, font(times, bold, 18)),
    send(ScoreObj, colour, colour(yellow)),
    send(ScoreObj, compute),
    get(ScoreObj, size, size(Width, Height)),
    XPos is (500 - Width) / 2,
    YPos = 10,
    Padding = 5,
    BoxWidth is Width + 2 * Padding,
    BoxHeight is Height + 2 * Padding,
    BoxXPos is XPos - Padding,
    BoxYPos is YPos - Padding,
    new(ScoreBox, box(BoxWidth, BoxHeight)),
    send(ScoreBox, fill_pattern, colour(black)),
    send(ScoreBox, pen, 0),  % No border
    send(ScoreBox, fill_pattern, new(_, colour(black, 0.5))),
    send(Window, display, ScoreBox, point(BoxXPos, BoxYPos)),
    send(Window, display, ScoreObj, point(XPos, YPos)),
    assertz(score_object(ScoreObj)).

% Draws both the stop and reset buttons.
draw_buttons(Window) :-
    new(StopButton, button('Stop', message(@prolog, stop_simulation))),
    new(ResetButton, button('Reset', message(@prolog, reset_simulation))),
    send(Window, display, StopButton, point(430, 5)),
    send(Window, display, ResetButton, point(370, 5)).

% Stops the simulation when the stop button is clicked.
stop_simulation :-
    retractall(stopped(_)),
    assertz(stopped(true)),
    gui_window(Window),
    score(team1, S1), score(team2, S2),
    format('Simulation Stopped! Final score - Team1: ~w, Team2: ~w~n', [S1, S2]),
    send(Window, destroy),
    retractall(gui_window(_)).

% Resets the simulation scores when the reset button is clicked.
% Resets the simulation to the initial state (scores, ball, and player positions) when the reset button is clicked.
reset_simulation :-
    % Reset scores
    retractall(score(_, _)),
    assertz(score(team1, 0)),
    assertz(score(team2, 0)),
    
    % Reset ball position
    retractall(ball(_)),
    assertz(ball(position(50, 25))),
    
    % Reset all player positions, stamina, and facing angles to initial state
    retractall(player(_, _, _, _, _)),
    assertz(player(team1, forward1, position(40, 40), stamina(100), 0)),
    assertz(player(team1, forward2, position(35, 10), stamina(100), 0)),
    assertz(player(team1, defender1, position(30, 30), stamina(100), 0)),
    assertz(player(team1, defender2, position(25, 20), stamina(100), 0)),
    assertz(player(team1, goalkeeper, position(5, 25), stamina(100), 90)),
    assertz(player(team2, forward1, position(60, 10), stamina(100), 180)),
    assertz(player(team2, forward2, position(65, 40), stamina(100), 180)),
    assertz(player(team2, defender1, position(70, 20), stamina(100), 180)),
    assertz(player(team2, defender2, position(75, 30), stamina(100), 180)),
    assertz(player(team2, goalkeeper, position(95, 25), stamina(100), 90)),
    
    % Update the GUI
    gui_window(Window),
    send(Window, clear),  % Clear the current GUI
    retractall(player_object(_, _)), 
    retractall(ball_object(_)),       
    retractall(score_object(_)),      
    draw_field(Window),
    draw_goals(Window),
    draw_players(Window),
    draw_ball(Window),
    draw_score(Window),
    draw_buttons(Window),
    
    format('Simulation reset to initial state: scores 0-0, players and ball repositioned~n').

% --- GUI Updates ---
% Moves the player graphic to a new position
update_player_gui(Team, Role, NewX, NewY) :-
    atom_concat(Team, '_', Tmp),
    atom_concat(Tmp, Role, Id),
    player_object(Id, Obj),
    ScaleX is NewX * 5, ScaleY is NewY * 5,
    send(Obj, move, point(ScaleX-5, ScaleY-5)).

% Moves the ball graphic to a new position.
update_ball_gui(NewX, NewY) :-
    ball_object(Obj),
    ScaleX is NewX * 5, ScaleY is NewY * 5,
    send(Obj, move, point(ScaleX-4, ScaleY-4)).

% Displays a goal message on the screen (blue text for team1, red text for team2).
display_goal_message(Window, Team) :-
    score(team1, S1),
    score(team2, S2),
    format(atom(Message), 'GOAL! ~w scores! (~w-~w)', [Team, S1, S2]),
    new(Text, text(Message)),
    send(Text, font, font(times, bold, 24)),
    (Team = team1 -> send(Text, colour, colour(blue)) ; send(Text, colour, colour(red))),
    send(Text, compute),
    get(Text, size, size(Width, Height)),
    Padding = 10,
    BoxWidth is Width + 2 * Padding,
    BoxHeight is Height + 2 * Padding,
    XPos is (500 - Width) / 2,
    YPos = 110,
    BoxXPos is XPos - Padding,
    BoxYPos is YPos - Padding,
    new(Background, box(BoxWidth, BoxHeight)),
    send(Background, fill_pattern, colour(gray90)),
    send(Window, display, Background, point(BoxXPos, BoxYPos)),
    send(Window, display, Text, point(XPos, YPos)),
    assertz(goal_message_object(Text)).

% --- Player Actions ---
% player moves toward the ball if they have stamina, then adjusting their facing angle.
move_toward_ball(Team, Role) :-
    player(Team, Role, position(X, Y), stamina(Stamina), Facing),
    (Stamina > 0 ->
        ball(position(BallX, BallY)),
        random(-2, 3, RandX),
        random(-2, 3, RandY),
        (see(Team, Role, BallX, BallY) ->
            NewX is round(X + (BallX - X) / 5 + RandX),
            NewY is round(Y + (BallY - Y) / 5 + RandY),
            DX is BallX - X,
            DY is BallY - Y,
            NewFacing is atan2(DY, DX) * 180 / pi
        ;   NewX is round(X + (50 - X) / 10 + RandX),
            NewY is round(Y + (25 - Y) / 10 + RandY),
            DX is NewX - X,
            DY is NewY - Y,
            NewFacing is atan2(DY, DX) * 180 / pi),
        clamp(NewX, 0, 100, ClampedX),
        clamp(NewY, 0, 50, ClampedY),
        NewStamina is max(0, Stamina - 1),
        retract(player(Team, Role, position(X, Y), stamina(Stamina), Facing)),
        assertz(player(Team, Role, position(ClampedX, ClampedY), stamina(NewStamina), NewFacing)),
        update_player_gui(Team, Role, ClampedX, ClampedY),
        format('~w ~w moves to (~w, ~w), facing ~w°, stamina: ~w~n',
               [Team, Role, ClampedX, ClampedY, NewFacing, NewStamina])
    ;   format('~w ~w does nothing (no stamina)~n', [Team, Role])).

% Kicks the ball toward the opponent’s goal if the player is within the kicking range and has stamina left.
kick_ball(Team, Role) :-
    player(Team, Role, position(X, Y), stamina(Stamina), Facing),
    (Stamina > 0 ->
        ball(position(BallX, BallY)),
        see(Team, Role, BallX, BallY),
        Distance is sqrt((X - BallX)^2 + (Y - BallY)^2),
        Distance =< 5,
        (Team = team1 -> goal(team2, position(GoalX, GoalY)) ; goal(team1, position(GoalX, GoalY))),
        DistanceToGoal is sqrt((BallX - GoalX)^2 + (BallY - GoalY)^2),
        (DistanceToGoal =< 20, see(Team, Role, GoalX, GoalY) -> KickFactor = 1.5 ; KickFactor = 6),
        random(-3, 4, RandX),
        random(-3, 4, RandY),
        NewBallX is round(BallX + (GoalX - BallX) / KickFactor + RandX),
        NewBallY is round(BallY + (GoalY - BallY) / KickFactor + RandY),
        clamp(NewBallX, 0, 100, ClampedBallX),
        clamp(NewBallY, 0, 50, ClampedBallY),
        random(-1, 2, RandPX),
        random(-1, 2, RandPY),
        NewPlayerX is round(X + (ClampedBallX - X) / 2 + RandPX),
        NewPlayerY is round(Y + (ClampedBallY - Y) / 2 + RandPY),
        clamp(NewPlayerX, 0, 100, ClampedPlayerX),
        clamp(NewPlayerY, 0, 50, ClampedPlayerY),
        DX is ClampedBallX - X,
        DY is ClampedBallY - Y,
        NewFacing is atan2(DY, DX) * 180 / pi,
        NewStamina is max(0, Stamina - 2),
        retract(ball(position(BallX, BallY))),
        retract(player(Team, Role, position(X, Y), stamina(Stamina), Facing)),
        assertz(ball(position(ClampedBallX, ClampedBallY))),
        assertz(player(Team, Role, position(ClampedPlayerX, ClampedPlayerY), stamina(NewStamina), NewFacing)),
        update_ball_gui(ClampedBallX, ClampedBallY),
        update_player_gui(Team, Role, ClampedPlayerX, ClampedPlayerY),
        format('~w ~w kicks ball to (~w, ~w), moves to (~w, ~w), facing ~w°, stamina: ~w~n',
               [Team, Role, ClampedBallX, ClampedBallY, ClampedPlayerX, ClampedPlayerY, NewFacing, NewStamina])
    ;   format('~w ~w does nothing (no stamina)~n', [Team, Role])).

% Goalkeeper action: clear ball away (long kick with KickFactor=1.5) if it is within the kicking range (<=3 unit).
% Otherwise, if the ball closes (<=20 unit) moves towards ball, else guards goal.
protect_goal(Team, Role) :-
    player(Team, Role, position(X, Y), stamina(Stamina), Facing),
    (Stamina > 0 ->
        ball(position(BallX, BallY)),
        goal(Team, position(GoalX, GoalY)),
        DistanceToBall is sqrt((X - BallX)^2 + (Y - BallY)^2),
        DistanceBallToGoal is sqrt((BallX - GoalX)^2 + (BallY - GoalY)^2),
        (DistanceBallToGoal =< 20, DistanceToBall =< 3 ->
            CenterX = 50,
            CenterY = 25,
            KickFactor = 1.5,
            random(-3, 4, RandX),
            random(-3, 4, RandY),
            NewBallX is round(BallX + (CenterX - BallX) / KickFactor + RandX),
            NewBallY is round(BallY + (CenterY - BallY) / KickFactor + RandY),
            clamp(NewBallX, 0, 100, ClampedBallX),
            clamp(NewBallY, 0, 50, ClampedBallY),
            random(-1, 2, RandPX),
            random(-1, 2, RandPY),
            NewPlayerX is round(X + (ClampedBallX - X) / 2 + RandPX),
            NewPlayerY is round(Y + (ClampedBallY - Y) / 2 + RandPY),
            clamp(NewPlayerX, 0, 100, ClampedPlayerX),
            clamp(NewPlayerY, 0, 50, ClampedPlayerY),
            DX is ClampedBallX - X,
            DY is ClampedBallY - Y,
            NewFacing is atan2(DY, DX) * 180 / pi,
            NewStamina is max(0, Stamina - 2),
            retract(ball(position(BallX, BallY))),
            retract(player(Team, Role, position(X, Y), stamina(Stamina), Facing)),
            assertz(ball(position(ClampedBallX, ClampedBallY))),
            assertz(player(Team, Role, position(ClampedPlayerX, ClampedPlayerY), stamina(NewStamina), NewFacing)),
            update_ball_gui(ClampedBallX, ClampedBallY),
            update_player_gui(Team, Role, ClampedPlayerX, ClampedPlayerY),
            format('~w ~w kicks ball to (~w, ~w), moves to (~w, ~w), stamina: ~w~n',
                   [Team, Role, ClampedBallX, ClampedBallY, ClampedPlayerX, ClampedPlayerY, NewStamina])
        ; DistanceBallToGoal =< 20 ->
            random(-1, 2, RandX),
            random(-1, 2, RandY),
            NewX is round(X + (BallX - X) / 5 + RandX),
            NewY is round(Y + (BallY - Y) / 5 + RandY),
            (Team = team1 -> clamp(NewX, 0, 98, ClampedX) ; clamp(NewX, 2, 100, ClampedX)),
            clamp(NewY, 21, 29, ClampedY),
            DX is BallX - X,
            DY is BallY - Y,
            NewFacing is atan2(DY, DX) * 180 / pi,
            NewStamina is max(0, Stamina - 1),
            retract(player(Team, Role, position(X, Y), stamina(Stamina), Facing)),
            assertz(player(Team, Role, position(ClampedX, ClampedY), stamina(NewStamina), NewFacing)),
            update_player_gui(Team, Role, ClampedX, ClampedY),
            format('~w ~w moves towards ball to (~w, ~w), stamina: ~w~n',
                   [Team, Role, ClampedX, ClampedY, NewStamina])
        ;   (Team = team1 -> TargetX is GoalX + 5 ; TargetX is GoalX - 5),
            random(-1, 2, RandX),
            random(-1, 2, RandY),
            NewX is round(X + (TargetX - X) / 5 + RandX),
            NewY is round(Y + (GoalY - Y) / 5 + RandY),
            (Team = team1 -> clamp(NewX, 0, 98, ClampedX) ; clamp(NewX, 2, 100, ClampedX)),
            clamp(NewY, 21, 29, ClampedY),
            NewStamina is max(0, Stamina - 1),
            retract(player(Team, Role, position(X, Y), stamina(Stamina), Facing)),
            assertz(player(Team, Role, position(ClampedX, ClampedY), stamina(NewStamina), Facing)),
            update_player_gui(Team, Role, ClampedX, ClampedY),
            format('~w ~w guards goal at (~w, ~w), stamina: ~w~n',
                   [Team, Role, ClampedX, ClampedY, NewStamina])
        )
    ;   format('~w ~w does nothing (no stamina)~n', [Team, Role])).

% --- Core Game Logic ---
% Checks if the ball enters a goal area, then update the score.
detect_goal :-
    ball(position(X, Y)),
    format('Ball at (~w, ~w)~n', [X, Y]),
    (between(96, 100, X), between(19, 31, Y) ->
        format('Right goal hit, awarding point to team1~n'),
        update_score(team1)
    ; between(0, 4, X), between(19, 31, Y) ->
        format('Left goal hit, awarding point to team2~n'),
        update_score(team2)
    ; true).

% Update the score, increases each player stamina by 30 (max 100), and reset the field.
update_score(Team) :-
    ball(position(BallX, BallY)),
    score(Team, S),
    NewS is S + 1,
    retract(score(Team, S)),
    assertz(score(Team, NewS)),
    format('GOAL! ~w scores at (~w, ~w). New score: ~w~n', [Team, BallX, BallY, NewS]),
    gui_window(Window),
    display_goal_message(Window, Team),
    retract(score_object(OldScoreObj)),
    send(OldScoreObj, destroy),
    draw_score(Window),
    % Increases all players’ stamina by +30 (capped at 100) after a goal.
    findall([T, R, X, Y, Stamina, F], player(T, R, position(X, Y), stamina(Stamina), F), Players),
    retractall(player(_, _, _, _, _)),
    forall(member([T, R, X, Y, Stamina, F], Players),
           (NewStamina is min(100, Stamina + 30),
            assertz(player(T, R, position(X, Y), stamina(NewStamina), F)))),
    send(Window, flush),
    sleep(2),
    reset_positions.

% Reset ball and player positions after a goal, keep the updated stamina.
reset_positions :-
    retractall(ball(_)), assertz(ball(position(50, 25))),  % Reset ball to center
    % Preserves stamina from update_score while resetting positions and facing.
    findall([T, R, Stamina, F], player(T, R, _, stamina(Stamina), F), Players),
    retractall(player(_, _, _, _, _)),  % Clear current player states
    member([team1, forward1, S1, _], Players), assertz(player(team1, forward1, position(40, 40), stamina(S1), 0)),
    member([team1, forward2, S2, _], Players), assertz(player(team1, forward2, position(35, 10), stamina(S2), 0)),
    member([team1, defender1, S3, _], Players), assertz(player(team1, defender1, position(30, 30), stamina(S3), 0)),
    member([team1, defender2, S4, _], Players), assertz(player(team1, defender2, position(25, 20), stamina(S4), 0)),
    member([team1, goalkeeper, S5, _], Players), assertz(player(team1, goalkeeper, position(5, 25), stamina(S5), 90)),
    member([team2, forward1, S6, _], Players), assertz(player(team2, forward1, position(60, 10), stamina(S6), 180)),
    member([team2, forward2, S7, _], Players), assertz(player(team2, forward2, position(65, 40), stamina(S7), 180)),
    member([team2, defender1, S8, _], Players), assertz(player(team2, defender1, position(70, 20), stamina(S8), 180)),
    member([team2, defender2, S9, _], Players), assertz(player(team2, defender2, position(75, 30), stamina(S9), 180)),
    member([team2, goalkeeper, S10, _], Players), assertz(player(team2, goalkeeper, position(95, 25), stamina(S10), 90)),
    gui_window(Window), send(Window, clear),  % Clear GUI
    retractall(player_object(_, _)), retractall(ball_object(_)),  % Clear object references
    draw_field(Window), draw_goals(Window), draw_players(Window), draw_ball(Window),
    draw_score(Window), draw_buttons(Window).  % Redraw all elements including buttons

% Run one cycle of the game: all players take turns, then check for goals.
game_cycle :-
    findall([Team, Role], player(Team, Role, _, _, _), Players),
    format('Players in cycle: ~w~n', [Players]),
    maplist(play_turn, Players),
    detect_goal,
    gui_window(Window),
    send(Window, flush),
    true.

% Determines a player’s action.
% (Goalkeeper: protect_goal, others: move / kick).
play_turn([Team, Role]) :-
    (Role = goalkeeper ->
        protect_goal(Team, Role)
    ;   kick_ball(Team, Role) ->
        true
    ;   move_toward_ball(Team, Role) ->
        true
    ;   format('~w ~w does nothing~n', [Team, Role])),
    true.

% Control values to stay within field boundaries.
clamp(Value, Min, Max, Clamped) :-
    Clamped is max(Min, min(Max, Value)).

% --- Simulation Control ---
% Run the game loop, checking for end conditions (no stamina left) or manual stop.
simulate :-
    stopped(true), !.
simulate :-
    (all_stamina_zero ->
        score(team1, S1), score(team2, S2),
        format('Game Over: All players exhausted! Final score - Team1: ~w, Team2: ~w~n', [S1, S2]),
        gui_window(Window),
        send(Window, destroy),
        retractall(gui_window(_))
    ; only_goalkeepers_have_stamina ->
        score(team1, S1), score(team2, S2),
        format('Game Over: Only goalkeepers remain active! Final score - Team1: ~w, Team2: ~w~n', [S1, S2]),
        gui_window(Window),
        send(Window, destroy),
        retractall(gui_window(_))
    ;   findall([Team, Role, Stamina], player(Team, Role, _, stamina(Stamina), _), PlayerStaminas),
        format('Player stamina: ~w~n', [PlayerStaminas]),
        game_cycle,
        nl,
        sleep(0.5),
        simulate
    ).
% Resets the simulation to the initial state when called from the prompt (?- reset).
reset :-
    % Reset scores
    retractall(score(_, _)),
    assertz(score(team1, 0)),
    assertz(score(team2, 0)),
    
    % Reset ball position
    retractall(ball(_)),
    assertz(ball(position(50, 25))),
    
    % Reset all player positions, stamina, and facing angles to initial state
    retractall(player(_, _, _, _, _)),
    assertz(player(team1, forward1, position(40, 40), stamina(100), 0)),
    assertz(player(team1, forward2, position(35, 10), stamina(100), 0)),
    assertz(player(team1, defender1, position(30, 30), stamina(100), 0)),
    assertz(player(team1, defender2, position(25, 20), stamina(100), 0)),
    assertz(player(team1, goalkeeper, position(5, 25), stamina(100), 90)),
    assertz(player(team2, forward1, position(60, 10), stamina(100), 180)),
    assertz(player(team2, forward2, position(65, 40), stamina(100), 180)),
    assertz(player(team2, defender1, position(70, 20), stamina(100), 180)),
    assertz(player(team2, defender2, position(75, 30), stamina(100), 180)),
    assertz(player(team2, goalkeeper, position(95, 25), stamina(100), 90)),
    
    % Update the GUI if it exists
    (gui_window(Window) ->
        send(Window, clear),  % Clear the current GUI
        retractall(player_object(_, _)), 
        retractall(ball_object(_)),       
        retractall(score_object(_)),     
        draw_field(Window),
        draw_goals(Window),
        draw_players(Window),
        draw_ball(Window),
        draw_score(Window),
        draw_buttons(Window),
        format('Simulation reset to initial: scores 0-0, players and ball repositioned~n')
    ;   format('Simulation reset to initial: scores 0-0, players and ball repositioned~n')),
    
    % Ensure simulation is not stopped
    retractall(stopped(_)),
    assertz(stopped(false)).

% Starts the simulation.
% (Initializes the GUI, then running game loops).
start :-
    init_gui,
    simulate.