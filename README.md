# RoboCup Soccer Simulation in Prolog

A 5-vs-5 soccer simulation inspired by RoboCup, written in SWI-Prolog. It draws the match live with XPCE, SWI-Prolog's built-in graphics library. Each player is a simple rule-based agent: it can only see what falls inside its vision cone, it uses up stamina as it acts, and it picks an action based on its role.

## Features

- **Two teams of five:** each team has 2 forwards, 2 defenders and 1 goalkeeper. Team 1 is blue and attacks the right goal. Team 2 is red and attacks the left goal.
- **Vision cone:** each player sees 90° (45° to either side of the direction it faces). It can only chase or kick the ball, or aim at the goal, when the target is inside this cone.
- **Stamina:**
  - Every player starts with 100 stamina.
  - Moving costs 1 and kicking costs 2.
  - After each goal, every player gets +30 stamina, up to a maximum of 100.
- **Role-based behaviour:**
  - **Forwards and defenders** kick the ball when it is visible and within 5 units. Otherwise they move toward the ball, or toward the centre of the field when they can't see it.
  - **Goalkeepers** clear the ball toward midfield when it is within 3 units and near their goal. They move toward the ball when it comes within 20 units of their goal, and otherwise stay in front of the goal mouth.
- **Kicking:** players take a short dribble-kick when they are far from the goal. They take a strong shot when they are within 20 units of the goal and can see it. Small random offsets make each match play out differently.
- **Scoring:** a goal is scored when the ball enters the goal area. The score updates, a "GOAL!" banner appears, and players and ball go back to their starting positions.
- **Live GUI:** the window shows the field, centre line and circle, goals, players, ball, scoreboard, and **Stop** / **Reset** buttons.
- **End conditions:** the match ends when every player has run out of stamina, or when only the two goalkeepers have stamina left.

## Requirements

- [SWI-Prolog](https://www.swi-prolog.org/Download.html) with XPCE. The standard installers include XPCE.
  - On macOS, XPCE needs an X11 server such as [XQuartz](https://www.xquartz.org/), unless your SWI-Prolog build ships a native GUI.

## Getting Started

```bash
git clone https://github.com/hiopeem/robocup.git
cd robocup
swipl robocup.pl
```

Then at the Prolog prompt:

```prolog
?- start.
```

A window opens and the match begins. The console prints every action, position, stamina value and goal.

### Commands

| Command     | Description                                                                 |
|-------------|-----------------------------------------------------------------------------|
| `?- start.` | Opens the GUI and starts the simulation loop.                                |
| `?- reset.` | Sets scores to 0-0 and returns all players and the ball to their starting state. |

### GUI Buttons

- **Stop:** halts the simulation, prints the final score and closes the window.
- **Reset:** returns scores, players and ball to their starting state.

## How It Works

### Field and coordinates

The field is a **100 × 50** unit grid, drawn at 5× scale in a 500 × 250 pixel window.

| Element             | Position                 |
|---------------------|--------------------------|
| Team 1 goal (left)  | `(0, 25)`                |
| Team 2 goal (right) | `(100, 25)`              |
| Ball start          | `(50, 25)` (centre spot) |
| Goal-scoring area   | x ∈ [0, 4] or [96, 100], y ∈ [19, 31] |

### Game loop

```
start
 └─ init_gui
 └─ simulate  (repeats every 0.5 s)
     ├─ stop if the Stop button was pressed
     ├─ end the game if every player has 0 stamina, or only goalkeepers have stamina
     └─ game_cycle
          ├─ play_turn for each player
          │    ├─ goalkeeper: protect_goal
          │    └─ others: kick_ball, or else move_toward_ball
          └─ detect_goal → update_score → reset_positions
```

### Key predicates

| Predicate | Purpose |
|-----------|---------|
| `player/5` | Dynamic state: `player(Team, Role, position(X,Y), stamina(S), FacingAngle)` |
| `ball/1`, `score/2` | Dynamic ball position and team scores |
| `see/4` | Checks whether a target is inside a player's vision cone |
| `move_toward_ball/2` | Moves toward the ball if it is visible, otherwise toward the field centre |
| `kick_ball/2` | Kicks the ball toward the opponent's goal |
| `protect_goal/2` | Goalkeeper logic: clear the ball, move toward it, or guard the goal |
| `detect_goal/0`, `update_score/1` | Detect goals, update the score and restore stamina |
| `reset_positions/0` | Puts players and ball back in kick-off positions and keeps their stamina |
| `clamp/4` | Keeps coordinates inside the field |

## Project Structure

```
.
├── robocup.pl      # Simulation source code
└── README.md
```

## License

This project is for educational purposes. Add a license (e.g. MIT) if you plan to share or reuse it.
