// Bellman-Ford 最短路算法实现

struct Edge {
  from: Int;
  to: Int;
  weight: Int;
}

fn bellman_ford(
  edges: Array[Edge],
  edge_count: Int,
  vertex_count: Int,
  source: Int,
  dist: Array[Int]
) -> Bool {
  let mut i = 0;
  while i < vertex_count {
    dist[i] = 999999;
    i = i + 1;
  }
  
  dist[source] = 0;
  
  let mut iter = 0;
  while iter < vertex_count - 1 {
    let mut j = 0;
    while j < edge_count {
      let edge = edges[j];
      let u = edge.from;
      let v = edge.to;
      let w = edge.weight;
      
      if dist[u] != 999999 && dist[u] + w < dist[v] {
        dist[v] = dist[u] + w;
      };
      
      j = j + 1;
    }
    iter = iter + 1;
  }
  
  let mut k = 0;
  let mut has_negative_cycle = false;
  while k < edge_count {
    let edge = edges[k];
    let u = edge.from;
    let v = edge.to;
    let w = edge.weight;
    
    if dist[u] != 999999 && dist[u] + w < dist[v] {
      has_negative_cycle = true;
    };
    
    k = k + 1;
  }
  
  !has_negative_cycle
}

fn print_distances(dist: Array[Int], n: Int) -> Unit {
  let mut i = 0;
  while i < n {
    if dist[i] == 999999 {
      println(0 - 1);
    } else {
      println(dist[i]);
    };
    i = i + 1;
  }
}

fn test_simple_graph() -> Unit {
  let e0 = Edge::{ from: 0, to: 1, weight: 5 };
  let e1 = Edge::{ from: 0, to: 2, weight: 3 };
  let e2 = Edge::{ from: 1, to: 3, weight: 1 };
  let e3 = Edge::{ from: 2, to: 1, weight: 1 };
  let e4 = Edge::{ from: 2, to: 3, weight: 5 };
  
  let edges = [e0, e1, e2, e3, e4];
  let dist = Array::make(4, 0);
  
  let result = bellman_ford(edges, 5, 4, 0, dist);
  
  if result {
    println(1);
  } else {
    println(0);
  };
  
  print_distances(dist, 4);
}

fn test_disconnected_graph() -> Unit {
  let e0 = Edge::{ from: 0, to: 1, weight: 5 };
  let e1 = Edge::{ from: 1, to: 2, weight: 3 };
  let e2 = Edge::{ from: 3, to: 4, weight: 2 };
  
  let edges = [e0, e1, e2];
  let dist = Array::make(5, 0);
  
  let result = bellman_ford(edges, 3, 5, 0, dist);
  
  if result {
    println(1);
  } else {
    println(0);
  };
  
  print_distances(dist, 5);
}

fn test_negative_weights() -> Unit {
  let e0 = Edge::{ from: 0, to: 1, weight: 5 };
  let e1 = Edge::{ from: 0, to: 2, weight: 3 };
  let e2 = Edge::{ from: 1, to: 3, weight: 0 - 2 };
  let e3 = Edge::{ from: 2, to: 1, weight: 0 - 4 };
  let e4 = Edge::{ from: 2, to: 3, weight: 5 };
  
  let edges = [e0, e1, e2, e3, e4];
  let dist = Array::make(4, 0);
  
  let result = bellman_ford(edges, 5, 4, 0, dist);
  
  if result {
    println(1);
  } else {
    println(0);
  };
  
  print_distances(dist, 4);
}

fn test_single_vertex() -> Unit {
  let edges = Array::make(1, Edge::{ from: 0, to: 0, weight: 0 });
  let dist = Array::make(1, 0);
  
  let result = bellman_ford(edges, 0, 1, 0, dist);
  
  if result {
    println(1);
  } else {
    println(0);
  };
  
  print_distances(dist, 1);
}

fn test_linear_graph() -> Unit {
  let e0 = Edge::{ from: 0, to: 1, weight: 1 };
  let e1 = Edge::{ from: 1, to: 2, weight: 2 };
  let e2 = Edge::{ from: 2, to: 3, weight: 3 };
  let e3 = Edge::{ from: 3, to: 4, weight: 4 };
  
  let edges = [e0, e1, e2, e3];
  let dist = Array::make(5, 0);
  
  let result = bellman_ford(edges, 4, 5, 0, dist);
  
  if result {
    println(1);
  } else {
    println(0);
  };
  
  print_distances(dist, 5);
}

fn test_complete_graph() -> Unit {
  let e0 = Edge::{ from: 0, to: 1, weight: 1 };
  let e1 = Edge::{ from: 0, to: 2, weight: 4 };
  let e2 = Edge::{ from: 1, to: 2, weight: 2 };
  
  let edges = [e0, e1, e2];
  let dist = Array::make(3, 0);
  
  let result = bellman_ford(edges, 3, 3, 0, dist);
  
  if result {
    println(1);
  } else {
    println(0);
  };
  
  print_distances(dist, 3);
}

fn test_zero_weights() -> Unit {
  let e0 = Edge::{ from: 0, to: 1, weight: 0 };
  let e1 = Edge::{ from: 1, to: 2, weight: 0 };
  let e2 = Edge::{ from: 2, to: 3, weight: 0 };
  
  let edges = [e0, e1, e2];
  let dist = Array::make(4, 0);
  
  let result = bellman_ford(edges, 3, 4, 0, dist);
  
  if result {
    println(1);
  } else {
    println(0);
  };
  
  print_distances(dist, 4);
}

fn main {
  test_simple_graph();
  test_disconnected_graph();
  test_negative_weights();
  test_single_vertex();
  test_linear_graph();
  test_complete_graph();
  test_zero_weights();
}

