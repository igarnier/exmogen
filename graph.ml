open Prelude

(* Persistent integer map.
   For now, we use standard Ocaml maps. Possible more efficient alternatives are:
   . Patricia trees (JC Filliatre's for instance) -- Drop-in replacement
   . Peristent hash tables/AVLs, etc              -- See Reins or Core lib ?
   . Persistent arrays (assuming we are careful w.r.t. vertex naming)
*)
module NodeIdMap =
struct

  include Map.Make
    (struct
      type t      = int
      let compare (x : int) (y : int) = 
        if x < y then -1
        else if x > y then 1
        else 0
     end)

  let find_opt id map =
    try Some (find id map) with
      Not_found -> None
        
end

type ('n,'l) info = {
  (* Colour of node *)
  clr : 'n;
  (* Adjacency relation supposed symmetric (invariant to be mainted) *)
  adj : ('l * int) list
}

type ('n, 'l) t = {
  (* Total number of nodes. We assume the vertex set is of the shape [0; size-1], i.e.
     a contiguous set of integers starting from 0. *)
  size  : int;
  (* Map every node id to its info *)
  info  : ('n, 'l) info NodeIdMap.t;
  (* List of growable points, i.e. incomplete nodes *)
  (* buds  : bud list; *)
  (* Canonical root - /!\ not automatically updated /!\ *)
  root  : int
}

let empty = {
  size    = 0;
  info    = NodeIdMap.empty;
  (*buds    = [];*)
  root    = -1
}

let size { size } = size
let info { info } = info
let root { root } = root

let get_info graph v =
  NodeIdMap.find v graph.info

let get_colour graph v =
  (NodeIdMap.find v graph.info).clr

let get_neighbours graph v =
  (NodeIdMap.find v graph.info).adj

(* TODO what to do with [buds] *)
let add_node_with_colour graph clr =
  let v = graph.size in
  let info = NodeIdMap.add v { clr; adj = [] } graph.info in
  { graph with
    size = v + 1;
    info }

let add_edge graph v1 l v2 =
  if v1 < graph.size && v2 < graph.size then
    let { adj = a1 } as i1 = get_info graph v1
    and { adj = a2 } as i2 = get_info graph v2 in
    let info = NodeIdMap.add v1 { i1 with adj = (l, v2) :: a1 } graph.info in
    let info = NodeIdMap.add v2 { i2 with adj = (l, v1) :: a2 } info in
    { graph with info }
  else
    failwith "add_edge: invalid arguments"

(* --------------------------- *)
(* Printing to DOT file format *)

let to_dot file_name graph_name graph print_node print_label =
  let file_desc = open_out file_name in
  let print x   = Printf.fprintf file_desc x in
  print "graph %s {\n" graph_name;
    (* (\*  print "[overlap=false];\n"; *\) *)
    (* print "%d [shape=box];\n" m.i; *)
  NodeIdMap.iter (fun i elt ->
    let s = print_node elt.clr i in
    print "%d [label=%s];\n" i s
  ) graph.info;
  NodeIdMap.iter (fun i elt ->
    List.iter (fun (label, dest) ->
      let label = print_label label in
      print "%d -- %d [label=\"%s\"];\n" i dest label
    ) elt.adj
  ) graph.info;
  print "}\n";
  close_out file_desc