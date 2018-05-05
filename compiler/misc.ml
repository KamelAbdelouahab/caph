(************************************************************************************)
(*                                                                                  *)
(*                                     CAPH                                         *)
(*                            http://caph.univ-bpclermont.fr                        *)
(*                                                                                  *)
(*                                  Jocelyn SEROT                                   *)
(*                         Jocelyn.Serot@univ-bpclermont.fr                         *)
(*                                                                                  *)
(*         Copyright 2011-2018 Jocelyn SEROT.  All rights reserved.                 *)
(*  This file is distributed under the terms of the Q Public License version 1.0.   *)
(*                                                                                  *)
(************************************************************************************)

exception Internal of string;;
exception Error

let generate_makefiles = ref false
let warn_on_cast = ref false

let source_file = ref ""

let id x = x 

let open_out fname =
  let f = if !generate_makefiles then "/dev/null" else fname in 
  Pervasives.open_out f

let fatal_error msg = raise (Internal msg)

let not_implemented what = 
  Printf.eprintf "** Not implemented: %s.\n" what;
  raise Error

let time_of_day () =
  let t = Unix.localtime (Unix.time ()) in
  Printf.sprintf "on %04d-%02d-%02d at %02d:%02d:%02d"
    (t.Unix.tm_year+1900) (t.Unix.tm_mon+1) t.Unix.tm_mday t.Unix.tm_hour t.Unix.tm_min t.Unix.tm_sec

let get_username () = try Sys.getenv "USER" with Not_found -> "<unknown>"
  
let dump_banner comment oc =
  Printf.fprintf oc "%s -------------------------------------------------------------------------------\n" comment;
  Printf.fprintf oc "%s This file has been automatically generated by the Caph compiler (version %s)\n" comment Version.version;
  Printf.fprintf oc "%s from file %s, %s, by %s\n" comment !source_file (time_of_day ()) (get_username());
  Printf.fprintf oc "%s For more information, see : http://caph.univ-bpclermont.fr\n" comment; 
  Printf.fprintf oc "%s -------------------------------------------------------------------------------\n\n" comment

let int_to_alpha offset i =
  if i < 26
  then String.make 1 (char_of_int (i+int_of_char offset))
  else String.make 1 (char_of_int ((i mod 26) + int_of_char offset)) ^ string_of_int (i/26)

let print_warnings = ref false

let compose f g x = g (f x)

let fst3 (x,_,_) = x

let list_iter_index f l = 
  let rec h i = function
    [] -> ()
  | x::xs -> f i x ; h (i+1) xs in
  h 0 l

let list_map_index f l = 
  let rec h i = function
    [] -> []
  | x::xs -> f i x :: h (i+1) xs in
  h 0 l

let rec map_foldl f acc = function
    [] -> acc, []
  | x::xs -> 
      let acc', x' = f acc x in
      let acc'', xs' = map_foldl f acc' xs in
      acc'', x'::xs'

let rec map_foldl' f acc = function
    [] -> acc, []
  | x::xs -> 
      let acc', x' = f acc x in
      let acc'', xs' = map_foldl' f acc' xs in
      acc'', x'::xs'

let map_accum f = map_foldl (fun z x -> let z', y = f x in z @ [z'], y) []

let rec foldl_index f acc l =
  let rec h i z = function
    [] -> z
  | x::xs -> let z' = f i z x in h (i+1) z' xs in
  h 0 acc l

let rec foldl2_index f acc l1 l2 =
  let rec h i z = function
    ([], []) -> z
  | (x1::xs1, x2::xs2) -> let z' = f i z x1 x2 in h (i+1) z' (xs1,xs2)
  | (_, _) -> invalid_arg "Misc.foldl2_index" in
  h 0 acc (l1,l2)

let rec map_foldl2 f acc l l' = match l, l' with
    [], [] -> acc, []
  | (x::xs), (y::ys) -> 
      let acc', x'  = f acc x y in
      let acc'', xs' = map_foldl2 f acc' xs ys in
      acc'', x'::xs'
  | _, _ -> invalid_arg "map_foldl2"

let rec list_split3 = function
    [] -> ([], [], [])
  | (x,y,z)::l ->
      let (rx, ry, rz) = list_split3 l in (x::rx, y::ry, z::rz)

let rec list_take n l = match n, l with
  0, _ -> []
| n, [] -> invalid_arg "list_take"
| n, x::xs -> x :: list_take (n-1) xs

let rec list_drop n l = match n, l with
  0, xs -> xs
| n, [] -> invalid_arg "list_drop"
| n, _::xs -> list_drop (n-1) xs

let split_string sep s =
  let r = ref []  in
  let l = String.length s in
  let rec h i = 
    if i >= l then !r 
    else if s.[i] = sep then h (i+1)
    else g i i
  and g j i =
    if i >= l then String.sub s j (i-j) :: !r
    else if s.[i] = sep then begin r := String.sub s j (i-j) :: !r ; h i end
    else g j (i+1) in
  List.rev (h 0)
;;

let rec string_of_list sf sep l = 
  List.fold_left 
    (fun s v -> 
      match sf v, s with
        "", _ -> s
      | s', "" -> s'
      | s', _ -> s ^ sep ^ s')
    ""
    l

let rec string_of_indexed_list sf sep l = 
  let r, _ = List.fold_left 
    (fun (s,i) v -> 
      match sf i v, s with
        "", _ -> s, i+1
      | s', "" -> s', i+1
      | s', _ -> s ^ sep ^ s', i+1)
    ("",0)
    l
  in r

let string_of_bracketed_list (lb,rb) sf sep l = 
  let s = string_of_list sf sep l in
  if List.length l > 1 then lb ^ s ^ rb else s
  
let string_of_listp sf sep l = string_of_bracketed_list ("(",")") sf sep l

let rec string_of_list2 sf sep = function
    [],[] -> ""
  | [v1],[v2] -> sf v1 v2
  | v1::vs1, v2::vs2 -> sf v1 v2 ^ sep ^ string_of_list2 sf sep (vs1,vs2)
  | _ -> raise (Invalid_argument "Misc.string_of_list2")

let rec string_of_indexed_list sf sep l = 
  let r, _ = 
  List.fold_left 
    (fun (s,i) v -> 
      match sf i v, s with
        "", _ -> (s,i+1)
      | s', "" -> (s',i+1)
      | s', _ -> (s ^ sep ^ s',i+1))
    ("",0)
    l
  in r

let rec string_of_list' sf sep = function
    [] -> ""
  | v::vs -> sf v ^ sep ^ string_of_list sf sep vs

let rec string_of_two_lists sf1 sf2 sep l1 l2 = 
  match string_of_list sf1 sep l1, string_of_list sf2 sep l2 with
    "", "" -> ""
  | "", s2 -> s2
  | s1, "" -> s1
  | s1, s2 -> s1 ^ sep ^ s2

let rec string_of_three_lists sf1 sf2 sf3 sep l1 l2 l3 = 
  match string_of_list sf1 sep l1, string_of_list sf2 sep l2, string_of_list sf3 sep l3 with
    "", "", "" -> ""
  | "", "", s3 -> s3
  | "", s2, "" -> s2
  | "", s2, s3 -> s2 ^ sep ^ s3
  | s1, "", "" -> s1
  | s1, "", s3 -> s1 ^ sep ^ s3
  | s1, s2, "" -> s1 ^ sep ^ s2
  | s1, s2, s3 -> s1 ^ sep ^ s2 ^ sep ^ s3

let rec find_map f = function
    [] -> raise Not_found
  | x::xs -> match f x with 
      true, y -> y
    | false, _ -> find_map f xs

let list_map_filter p f l = List.map f (List.filter p l)

let rec filter_map2 p f l = match l with 
   [] -> []
| x::xs -> if p x then f x :: filter_map2 p f xs else filter_map2 p f xs

let list_make_index n f =
  let rec h i = if i >= n then [] else f i :: h (i+1) in
  h 0

let list_repl n x =
  let rec h = function 0 -> [] | n -> x :: h (n-1) in
  h n

let list_make n1 n2 f =
  let rec h i = if i > n2 then [] else f i :: h (i+1) in
  h n1

let rec output_list f oc sep = function
    [] -> ()
  | [v] -> f oc v
  | v::vs -> f oc v; output_string oc sep; output_list f oc sep vs

let apply_option f = function None -> None | Some x -> Some (f x)

let string_of_opt f = function None -> "" | Some x -> f x

let assoc_add l ((k,_) as v) = if List.mem_assoc k l then l else v::l

let assoc_replace i f = List.map (function (j,v) -> j, if i=j then f v else v)

let assoc_from_list xys =
  let rec h xs (x,y) = 
  if List.mem_assoc x xs then
    let ys = List.assoc x xs in
    (x,ys@[y]) :: List.remove_assoc x xs
  else
    (x,[y]) :: xs in
  List.fold_left h [] xys

let list_union l1 l2 =
  let add l x = if List.mem x l then l else x::l in
  List.fold_left add l1 l2

let list_unionq l1 l2 =
  let add l x = if List.memq x l then l else x::l in
  List.fold_left add l1 l2

let rec map3 f l1 l2 l3 =
  match (l1, l2, l3) with
    ([], [], []) -> []
  | (a1::l1, a2::l2, a3::l3) -> let r = f a1 a2 a3 in r :: map3 f l1 l2 l3
  | (_, _, _) -> invalid_arg "Misc.map3"

let flatmap f l = List.flatten (List.map f l)

let int_of_bool = function false -> 0 | true -> 1

let bit_of_bool = function false -> 0 | true -> 1

let rec iter_sep f s = function
    [] -> ()
  | [v] -> f v
  | v::vs -> f v; s (); iter_sep f s vs

let print_semic_nl oc f l = iter_sep (f oc) (function () -> Printf.fprintf oc ";\n") l

let append_sep s sep s' = match s with "" -> s' | _ -> s ^ sep ^ s'

let check_file f = 
  if not (Sys.file_exists f ) then Printf.eprintf "Warning: file %s does not exist.\n" f

let prefix sep err s = 
  try String.sub s 0 (String.index s sep)
  with Not_found -> err s

let log2 x = int_of_float (log (float_of_int x) /. log 2.)

let rec pow2 k = if k = 0 then 1 else 2 * pow2 (k-1) (* Not tail recursive, but who cares, here ... *)

let is_pow2 n = pow2 (log2 n) = n

let change_extension s f = Filename.chop_extension f ^ "." ^ s

let get_extension n =
  let l = String.length (Filename.chop_extension n) in
  String.sub n (l+1) (String.length n-l-1)

exception Not_same_for_all

let same_for_all f = function 
    [] -> raise (Invalid_argument "same_for_all")
  | x::xs -> 
      let y = f x in
      if List.for_all (function x -> f x = y) xs then y else raise Not_same_for_all

let list_same f = function
    [] -> true
  | x::xs -> let r = f x in List.for_all (function y -> f y = r) xs

let string_of_pair f x y = "(" ^ f x ^ "," ^ f y ^ ")"

let cpl2 n x = pow2 n - x

let rec  bit_size n = if n=0 then 0 else 1 + bit_size (n/2)

let bits_of_int n = 
  let s = bit_size n in
  let b = Array.make s 0 in
  let rec h n i =
    if i<s then begin
      b.(i) <- n mod 2;
      h (n/2) (i+1)
      end in
  h n 0;
  b

let bits_of_float v =
  let u = Int32.bits_of_float v in
  let b = Bytes.make 32 '0' in
  let rec h u i =
    if i>=0 then begin
      Bytes.set b i (if Int32.to_int (Int32.logand u Int32.one) = 1 then '1' else '0');
      h (Int32.shift_right u 1) (i-1)
      end in
  h u 31;
  b

let list_init si ei f =
  let rec h i = if i <= ei then f i :: h (i+1) else [] in
  h si

let string_is_prefix s' s =
  let l = String.length s' in
  String.length s > l && String.sub s 0 l = s'
  
let string_after s' s =
  if string_is_prefix s' s then
    let l = String.length s' in
    String.sub s l (String.length s - l)
  else ""

let string_is_suffix s' s = 
  let l = String.length s in
  let l' = String.length s' in
  l > l' && String.sub s (l-l') l' = s'

let replace_suffix sep s' s =
    let i = String.rindex s sep in
    String.sub s 0 (i+1) ^ s' 

let get_suffix s =
  try 
    let i = String.rindex s '.' in
    String.sub s (i+1) (String.length s - i - 1)
  with 
    Not_found -> ""
  | Invalid_argument _ -> ""

let max x y = if x > y then x else y

let list_prod l1 l2 = List.flatten (List.map (function x1 -> List.map (function x2 -> x1, x2) l2) l1)

let list_prod_with f l1 l2 = List.flatten (List.map (function x1 -> List.map (function x2 -> f x1 x2) l2) l1)

let list_cart_prodn ls =
  let h l = List.map (function e -> [e]) l in
  let p l1 l2 = list_prod_with (fun x y -> x@[y]) l1 l2 in
  match ls with
    [] -> []
  | [l] -> h l
  | l::ls -> List.fold_left p (h l) ls

let list_unzip l = List.map fst l, List.map snd l

let fst13 (x,_,_) = x

let prefix_dir dir fname = Filename.concat dir fname 

let check_dir name = 
      if not (Sys.file_exists name && Sys.is_directory name) then begin
        Printf.printf "Creating directory %s\n" name;
        Unix.mkdir name 0o777
        end

let move_to_front p l =
  let rec h z = function
      [] -> z
    | x::xs -> let z' = if p x then x::z else z @ [x] in h z' xs in
  h [] l

let string_of_float' v = 
  let s = string_of_float v in
  if s.[String.length s - 1] = '.'
  then s ^ "0"   (* VHDL compilers do not accept FP values ending with a dot *)
  else s

let list_inter l1 l2 = List.filter (function x -> List.mem x l2) l1

let bits_from_card n = int_of_float (ceil (log (float_of_int n)))

let list_max = function
    [] -> raise (Invalid_argument "list_max")
  | [x] -> x
  | x::xs -> List.fold_left max x xs

let list_rem p l = 
  let rec h = function
      [] -> []
    | x::xs -> if p x then h xs else x::h xs in
  h l

let list_remove e l = list_rem (function x -> x=e) l

let redefinition_warning m = Printf.printf "redef of %s\n" m

let add p f l1 l2 = 
    List.fold_left 
      (fun l e ->
        if List.exists (f e) l then redefinition_warning (p e);
        e::l)
      l2
      (List.rev l1)

let find_and_remove p l =
  let rec h = function
    [] -> None, []
  | x::xs when p x -> Some x, xs
  | x::xs -> let r, ys = h xs in r, x::ys in
  h l

let trim l s = if String.length s > l then "..." else s

let str_replc rs s =
  (* [str_replc [ss1,ss1'; ...; ssm,ssm'] s] returns a copy of string [s] in which each substring [ssi] has been
     replaced by [ssi'] *)
  let l = String.length s in
  let matches s i (ss,ss') = 
    let l' = String.length ss in
    i+l'-1 < l && String.sub s i l' = ss in
  let s' = Buffer.create l in
  let i = ref 0 in
  while !i < l do
    try
      let (ss,ss') = List.find (matches s !i) rs in
      Buffer.add_string s' ss';
      i := !i + String.length ss
    with Not_found ->
      Buffer.add_char s' s.[!i];
      i := !i + 1
    done;
  Buffer.contents s'

let htmlize =
  str_replc [
  "<", "&lt;";
  "<=", "&le;";
  ">", "&gt;";
  ">=", "&ge;"
  ]

let find_in_path paths filename =
  if Sys.file_exists filename then
    filename
  else if Filename.is_relative filename then
    let rec find = function
      [] ->
        raise Not_found
    | path::rest ->
        let f = Filename.concat path filename in
        if Sys.file_exists f then f else find rest
    in find paths
  else
    raise Not_found

let lookup msg id tbl =
  try List.assoc id tbl
  with Not_found -> failwith msg  (* should not happen *)

let rec list_pairs f l = match l with
  x::y::rest -> f x y :: list_pairs f rest
 | _ -> l

let rec fold_tree f l = match l with
    [] -> invalid_arg "Misc.foldt"
  | [x] -> x
  | xs -> fold_tree f (list_pairs f xs)

let rec insert_sort p l =
  let rec insert elem = function
  | [] -> [elem]
  | x :: l -> if p elem x then elem :: x :: l else x :: insert elem l in
  match l with
  | [] -> []
  | x :: l -> insert x (insert_sort p l)

let range n1 n2 =
  let rec h i = if i > n2 then [] else i :: h (i+1) in
  h n1

let (+@) l ls = l @ List.concat ls

let foldl1 f = function x::xs -> List.fold_left f x xs | [] -> invalid_arg "foldl1"

let get_file_with_suffix dir sfx = 
  (* Returns the first file with suffix [sfx] in directory [dir]. Raises [Not_found] if none found *)
  let fs = Array.to_list (Sys.readdir dir) in
  List.find (function f -> Filename.check_suffix f "cph") fs

let get_file_with_name dir name = 
  (* Returns the first file with name (w/o suffix) [name] in directory [dir]. Raises [Not_found] if none found *)
  let fs = Array.to_list (Sys.readdir dir) in
  List.find (function f -> Filename.chop_extension f = name ) fs

