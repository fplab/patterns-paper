open Syntax
open Util

exception UnImplemented

let partition2 (pred1 : 'a -> bool) (pred2 : 'a -> bool) (xs : 'a list) : ('a list * 'a list) option =
  let f (acc : ('a list * 'a list) option) (c : 'a) =
    match acc with
    | None -> None
    | Some (trues, falses) ->
      if pred2 c then None
      else if pred1 c then
        Some (c::trues, falses)
      else 
        Some (trues, c::falses)
  in
  List.fold_left f (Some ([], [])) xs

let is_inconsistent_nums (xis : Constraint.t list) : bool =
  let (num_set, not_num_list) =
    List.fold_left 
      (fun (num_set, not_num_list) (xi : Constraint.t) ->
         match xi with
         | Num n -> (NumSet.add n num_set, not_num_list)
         | NotNum n -> (num_set, n::not_num_list)
         | _ -> assert false
      )
      (NumSet.empty, [])
      xis
  in
  if NumSet.cardinal num_set > 1 then
    true
  else
    List.fold_left
      (fun incon n ->
         if incon then
           incon
         else
           NumSet.mem n num_set
      )
      false
      not_num_list

let rec is_inconsistent ?(may = false) (xis : Constraint.t list) : bool =
  match xis with
  | [] -> false
  | xi::xis' -> (
      match xi with
      | Truth -> is_inconsistent ~may xis'
      | Falsity -> true
      | Unknown -> if may then true else (is_inconsistent ~may xis')
      | And (xi_1, xi_2) -> is_inconsistent ~may (xi_1::xi_2::xis')
      | Or (xi_1, xi_2) -> is_inconsistent ~may (xi_1::xis') && is_inconsistent ~may (xi_2::xis')
      | Unit -> is_inconsistent ~may xis'
      | Inl _ -> (
          match
            partition2
              (function Constraint.Inl _ -> true | _ -> false)
              (function Constraint.Inr _ -> true | _ -> false)
              xis
          with
          | None -> true
          | Some (inls, []) -> is_inconsistent ~may (
              List.map (function Constraint.Inl xi -> xi | _ -> assert false) inls
            )
          | Some (inls, other) -> is_inconsistent ~may (other @ inls)
        )
      | Inr _ -> (
          match
            partition2
              (function Constraint.Inr _ -> true | _ -> false)
              (function Constraint.Inl _ -> true | _ -> false)
              xis
          with
          | None -> true
          | Some (inrs, []) -> is_inconsistent ~may (
              List.map (function Constraint.Inr xi -> xi | _ -> assert false) inrs
            )
          | Some (inrs, other) -> is_inconsistent ~may (other @ inrs)
        )
      | Num n -> (
          match
            partition2
              (function Constraint.Num _ | Constraint.NotNum _ -> true | _ -> false)
              (function Constraint.Num n' -> (n != n') | Constraint.NotNum n' -> (n = n') | _ -> false)
              xis
          with
          | None -> true
          | Some (ns, []) -> is_inconsistent_nums ns
          | Some (ns, other) -> is_inconsistent ~may (other @ ns)
        )
      | NotNum n -> (
          match
            partition2
              (function Constraint.Num _ | Constraint.NotNum _ -> true | _ -> false)
              (function Constraint.Num n' -> (n = n') | _ -> false)
              xis
          with
          | None -> true
          | Some (ns, []) -> is_inconsistent_nums ns
          | Some (ns, other) -> is_inconsistent ~may (other @ ns)
        )
      | Pair (_, _) -> (
          match
            List.partition
              (function Constraint.Pair _ -> true | _ -> false)
              xis
          with
          | (pairs, []) ->
            let (xis_l, xis_r) =
              List.fold_left
                (fun (xis_l, xis_r) pair ->
                   let (xi_l, xi_r) =
                     match pair with
                     | Constraint.Pair (xi_l, xi_r) -> (xi_l, xi_r)
                     | _ -> assert false
                   in (xi_l::xis_l, xi_r::xis_r)
                )
                ([], [])
                pairs
            in (is_inconsistent ~may xis_l) || (is_inconsistent ~may xis_r)
          | (pairs, other) ->
            is_inconsistent ~may (other @ pairs)
        )
    )

let is_redundant (xi_cur : Constraint.t) (xi_pre : Constraint.t) : bool =
  is_inconsistent [And (xi_cur, Constraint.dual xi_pre)]

let is_exhaustive (xi : Constraint.t) : bool =
  is_inconsistent ~may:true [Constraint.dual xi]

let rec rules_is_typechecked
    (xi_pre : Constraint.t) (rules : (unit -> Constraint.t) list)
  : Constraint.t option =
  match rules with
  | [] -> Some Falsity
  | r::rs ->
    let xi_r = r () in
    if is_redundant xi_r xi_pre then
      None
    else 
      (match rules_is_typechecked (Or (xi_pre, xi_r)) rs with
       | None -> None
       | Some xi_post -> Some (Or (xi_r, xi_post))
      )

let match_is_typechecked (xi_list : Constraint.t list) : bool =
  let rules = List.map (fun xi -> fun () -> xi) xi_list in
  match rules_is_typechecked Falsity rules with
  | None -> false
  | Some xi -> is_exhaustive xi

let is_inconsistent_tests : (Constraint.t list * bool) list = [
  ( [Truth; Inl Truth; Inr Truth], true ) ;
  ( [Truth; Falsity], true ) ;
  ( [And (Inl Truth, Truth); Inr Truth], true ) ;
  ( [Or (Falsity, Truth)], false ) ;
  ( [Num 1; NotNum 2; NotNum 3], false ) ;
  ( [Or (Num 1, Num 3); And (NotNum 1, NotNum 3)], true ) ;
  ( [Pair (Inr Falsity, Truth)], true) ;
]

let match_tests : (Constraint.t list * bool) list = [
  ( [Inl Truth; Inr Truth], true ) ;
  ( [Inl Truth; Inr Truth; Inl Unknown], false ) ;
  ( [Inl Truth], false) ;
  ( [Inl Unknown; Inr Unknown; Unknown], true ) ;
  ( [Num 1; Unknown], true) ;
  ( [Inl Truth; Inr Truth; Unknown], false );
]
;;

List.map
  (function (xis, result) -> if is_inconsistent xis = result then () else assert false)
  is_inconsistent_tests
;;
List.map
  (function (xis, result) -> if match_is_typechecked xis = result then () else assert (false))
  match_tests
;;
