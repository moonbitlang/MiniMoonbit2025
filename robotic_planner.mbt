// 机器人路径规划系统 - A*算法和运动控制

enum CellType {
  Free;
  Obstacle;
  Start;
  Goal;
}

enum Direction {
  North;
  South;
  East;
  West;
  NorthEast;
  NorthWest;
  SouthEast;
  SouthWest;
}

enum PlanningStatus {
  NotStarted;
  InProgress;
  PathFound;
  NoPathExists;
}

struct Position {
  x: Int;
  y: Int;
}

struct Node {
  pos: Position;
  g_cost: Int;
  h_cost: Int;
  f_cost: Int;
  parent_x: Int;
  parent_y: Int;
}

struct GridMap {
  cells: Array[CellType];
  width: Int;
  height: Int;
}

struct Path {
  positions: Array[Position];
  length: Int;
  total_cost: Int;
}

struct Robot {
  position: Position;
  heading: Double;
  speed: Double;
  battery: Int;
}

fn make_position(x: Int, y: Int) -> Position {
  Position::{ x: x, y: y }
}

fn make_node(pos: Position, g: Int, h: Int, px: Int, py: Int) -> Node {
  Node::{
    pos: pos,
    g_cost: g,
    h_cost: h,
    f_cost: g + h,
    parent_x: px,
    parent_y: py
  }
}

fn make_grid(width: Int, height: Int) -> GridMap {
  let size = width * height;
  let cells = Array::make(size, Free);
  GridMap::{ cells: cells, width: width, height: height }
}

fn make_robot(x: Int, y: Int) -> Robot {
  Robot::{
    position: make_position(x, y),
    heading: 0.0,
    speed: 1.0,
    battery: 100
  }
}

fn get_cell(grid: GridMap, x: Int, y: Int) -> CellType {
  if x >= 0 && x < grid.width && y >= 0 && y < grid.height {
    grid.cells[y * grid.width + x]
  } else {
    Obstacle
  }
}

fn set_cell(grid: GridMap, x: Int, y: Int, cell_type: CellType) -> Unit {
  if x >= 0 && x < grid.width && y >= 0 && y < grid.height {
    grid.cells[y * grid.width + x] = cell_type;
  }
}

fn is_walkable(grid: GridMap, x: Int, y: Int) -> Bool {
  match get_cell(grid, x, y) {
    Obstacle => false;
    _ => true;
  }
}

fn manhattan_distance(p1: Position, p2: Position) -> Int {
  let dx = if p1.x > p2.x { p1.x - p2.x } else { p2.x - p1.x };
  let dy = if p1.y > p2.y { p1.y - p2.y } else { p2.y - p1.y };
  dx + dy
}

fn euclidean_distance_approx(p1: Position, p2: Position) -> Int {
  let dx = if p1.x > p2.x { p1.x - p2.x } else { p2.x - p1.x };
  let dy = if p1.y > p2.y { p1.y - p2.y } else { p2.y - p1.y };
  dx * dx + dy * dy
}

fn get_neighbors(pos: Position, grid: GridMap, neighbors: Array[Position]) -> Int {
  let mut count = 0;
  
  let offsets = [
    (0, 0 - 1), (0, 1), (0 - 1, 0), (1, 0),
    (0 - 1, 0 - 1), (1, 0 - 1), (0 - 1, 1), (1, 1)
  ];
  
  let mut i = 0;
  while i < 8 {
    let (dx, dy) = offsets[i];
    let nx = pos.x + dx;
    let ny = pos.y + dy;
    
    if is_walkable(grid, nx, ny) {
      neighbors[count] = make_position(nx, ny);
      count = count + 1;
    };
    
    i = i + 1;
  }
  
  count
}

fn find_in_list(list: Array[Node], size: Int, pos: Position) -> Int {
  let mut i = 0;
  while i < size {
    if list[i].pos.x == pos.x && list[i].pos.y == pos.y {
      return i;
    };
    i = i + 1;
  }
  0 - 1
}

fn get_min_f_node(open_list: Array[Node], size: Int) -> Int {
  if size == 0 {
    0 - 1
  } else {
    let mut min_idx = 0;
    let mut min_f = open_list[0].f_cost;
    let mut i = 1;
    
    while i < size {
      if open_list[i].f_cost < min_f {
        min_f = open_list[i].f_cost;
        min_idx = i;
      };
      i = i + 1;
    }
    
    min_idx
  }
}

fn remove_from_list(list: Array[Node], size: Int, index: Int) -> Int {
  if index >= 0 && index < size {
    let mut i = index;
    while i < size - 1 {
      list[i] = list[i + 1];
      i = i + 1;
    }
    size - 1
  } else {
    size
  }
}

fn reconstruct_path(
  closed_list: Array[Node],
  closed_size: Int,
  goal: Position,
  path: Array[Position]
) -> Int {
  let goal_idx = find_in_list(closed_list, closed_size, goal);
  if goal_idx < 0 {
    0
  } else {
    let mut path_length = 0;
    let mut current_x = goal.x;
    let mut current_y = goal.y;
    
    while path_length < 100 {
      let current_pos = make_position(current_x, current_y);
      let idx = find_in_list(closed_list, closed_size, current_pos);
      
      if idx < 0 {
        return path_length;
      };
      
      path[path_length] = current_pos;
      path_length = path_length + 1;
      
      let node = closed_list[idx];
      if node.parent_x < 0 {
        return path_length;
      };
      
      current_x = node.parent_x;
      current_y = node.parent_y;
    }
    
    path_length
  }
}

fn a_star_search(
  grid: GridMap,
  start: Position,
  goal: Position,
  path: Array[Position]
) -> Int {
  let open_list = Array::make(200, make_node(make_position(0, 0), 0, 0, 0 - 1, 0 - 1));
  let closed_list = Array::make(200, make_node(make_position(0, 0), 0, 0, 0 - 1, 0 - 1));
  let mut open_size = 0;
  let mut closed_size = 0;
  
  let start_node = make_node(start, 0, manhattan_distance(start, goal), 0 - 1, 0 - 1);
  open_list[0] = start_node;
  open_size = 1;
  
  let mut iterations = 0;
  while open_size > 0 && iterations < 500 {
    let current_idx = get_min_f_node(open_list, open_size);
    if current_idx < 0 {
      return 0;
    };
    
    let current = open_list[current_idx];
    
    if current.pos.x == goal.x && current.pos.y == goal.y {
      closed_list[closed_size] = current;
      closed_size = closed_size + 1;
      return reconstruct_path(closed_list, closed_size, goal, path);
    };
    
    open_size = remove_from_list(open_list, open_size, current_idx);
    closed_list[closed_size] = current;
    closed_size = closed_size + 1;
    
    let neighbors = Array::make(8, make_position(0, 0));
    let neighbor_count = get_neighbors(current.pos, grid, neighbors);
    
    let mut i = 0;
    while i < neighbor_count {
      let neighbor_pos = neighbors[i];
      
      if find_in_list(closed_list, closed_size, neighbor_pos) >= 0 {
        i = i + 1;
      } else {
        let g = current.g_cost + 1;
        let h = manhattan_distance(neighbor_pos, goal);
        let neighbor_node = make_node(neighbor_pos, g, h, current.pos.x, current.pos.y);
        
        let open_idx = find_in_list(open_list, open_size, neighbor_pos);
        if open_idx < 0 {
          if open_size < 200 {
            open_list[open_size] = neighbor_node;
            open_size = open_size + 1;
          };
        } else {
          if g < open_list[open_idx].g_cost {
            open_list[open_idx] = neighbor_node;
          };
        };
        
        i = i + 1;
      };
    }
    
    iterations = iterations + 1;
  }
  
  0
}

fn move_robot(robot: Robot, target: Position) -> Robot {
  let dx = target.x - robot.position.x;
  let dy = target.y - robot.position.y;
  
  let new_battery = robot.battery - 1;
  
  if new_battery < 0 {
    robot
  } else {
    Robot::{
      position: target,
      heading: robot.heading,
      speed: robot.speed,
      battery: new_battery
    }
  }
}

fn follow_path(robot: Robot, path: Array[Position], path_length: Int, steps: Int) -> Robot {
  let mut current_robot = robot;
  let mut step = 0;
  let mut path_idx = path_length - 1;
  
  while step < steps && path_idx >= 0 {
    current_robot = move_robot(current_robot, path[path_idx]);
    path_idx = path_idx - 1;
    step = step + 1;
  }
  
  current_robot
}

fn cell_type_to_int(cell: CellType) -> Int {
  match cell {
    Free => 0;
    Obstacle => 1;
    Start => 2;
    Goal => 3;
  }
}

fn test_grid_creation() -> Unit {
  let grid = make_grid(10, 10);
  set_cell(grid, 5, 5, Obstacle);
  set_cell(grid, 5, 6, Obstacle);
  
  println(cell_type_to_int(get_cell(grid, 5, 5)));
  println(cell_type_to_int(get_cell(grid, 5, 6)));
  println(cell_type_to_int(get_cell(grid, 5, 7)));
}

fn test_distance_functions() -> Unit {
  let p1 = make_position(0, 0);
  let p2 = make_position(3, 4);
  
  let manhattan = manhattan_distance(p1, p2);
  let euclidean_sq = euclidean_distance_approx(p1, p2);
  
  println(manhattan);
  println(euclidean_sq);
}

fn test_simple_path() -> Unit {
  let grid = make_grid(10, 10);
  
  let start = make_position(0, 0);
  let goal = make_position(5, 5);
  
  let path = Array::make(100, make_position(0, 0));
  let path_length = a_star_search(grid, start, goal, path);
  
  println(path_length);
  if path_length > 0 {
    println(path[0].x);
    println(path[0].y);
  };
}

fn test_path_with_obstacles() -> Unit {
  let grid = make_grid(10, 10);
  
  set_cell(grid, 2, 0, Obstacle);
  set_cell(grid, 2, 1, Obstacle);
  set_cell(grid, 2, 2, Obstacle);
  set_cell(grid, 2, 3, Obstacle);
  
  let start = make_position(0, 2);
  let goal = make_position(5, 2);
  
  let path = Array::make(100, make_position(0, 0));
  let path_length = a_star_search(grid, start, goal, path);
  
  println(path_length);
}

fn test_robot_movement() -> Unit {
  let robot = make_robot(0, 0);
  let target = make_position(5, 5);
  
  let moved_robot = move_robot(robot, target);
  
  println(moved_robot.position.x);
  println(moved_robot.position.y);
  println(moved_robot.battery);
}

fn test_path_following() -> Unit {
  let grid = make_grid(10, 10);
  let start = make_position(0, 0);
  let goal = make_position(5, 0);
  
  let path = Array::make(100, make_position(0, 0));
  let path_length = a_star_search(grid, start, goal, path);
  
  let robot = make_robot(0, 0);
  let final_robot = follow_path(robot, path, path_length, 3);
  
  println(final_robot.position.x);
  println(final_robot.position.y);
  println(final_robot.battery);
}

fn test_complex_maze() -> Unit {
  let grid = make_grid(15, 15);
  
  let mut i = 0;
  while i < 10 {
    set_cell(grid, 5, i, Obstacle);
    set_cell(grid, 10, i + 5, Obstacle);
    i = i + 1;
  }
  
  let start = make_position(0, 5);
  let goal = make_position(14, 5);
  
  let path = Array::make(100, make_position(0, 0));
  let path_length = a_star_search(grid, start, goal, path);
  
  println(path_length);
}

fn main {
  test_grid_creation();
  test_distance_functions();
  test_simple_path();
  test_path_with_obstacles();
  test_robot_movement();
  test_path_following();
  test_complex_maze();
}

