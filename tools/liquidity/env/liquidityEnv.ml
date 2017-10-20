(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2017       .                                          *)
(*    Fabrice Le Fessant, OCamlPro SAS <fabrice@lefessant.net>            *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(* External word *)

module Dependencies = struct


  module Z : sig
    type t
    val of_string : string -> t
    val of_int : int -> t
    val to_int : t -> int
    val of_float : float -> t
    val to_float : t -> float
    val add : t -> t -> t
    val sub : t -> t -> t
    val mul : t -> t -> t
    val ediv_rem : t -> t -> t * t
    val abs  : t -> t
  end = Z (* Zarith *)

  module ISO8601 : sig
      val float_of_string : string -> float
      val string_of_float : float -> string
      val time : unit -> float
  end = ISO8601

end

open Dependencies





(* This module is completely unsafe: it can only by used to execute a
file that has been correctly typechecked by the `liquidity`
typechecker.  *)

exception Fail

type integer =
  Int of Z.t
| Tez of Z.t
| Timestamp of Z.t
type timestamp = integer
type tez = integer
type nat = integer

type key = Key of string
type key_hash = Key_hash of string
type signature = Signature of string

type ('arg, 'res) contract = {
    manager : key_hash;
    delegate : key_hash option;
    spendable : bool;
    delegatable : bool;
    mutable balance : tez;
    call : ('arg -> 'res);
    storage : Obj.t ref;
  }

module Signature : sig
  val of_string : string -> signature
end = struct
  let of_string s = Signature s
end

module Key : sig
  val of_string : string -> key
  end = struct
  let of_string s = Key s
end

module Key_hash : sig
  val of_string : string -> key_hash
  end = struct
  let of_string s = Key_hash s
end

module Tez : sig

  val of_string : string -> tez

  end = struct

  let of_string s =
    let (tezzies, centiles) =
      try
        let pos = String.index s '.' in
        let tezzies = String.sub s 0 pos in
        let len = String.length s in
        let centiles = "0" ^ String.sub s (pos+1) (len-pos-1) in
        Z.of_string tezzies, Z.of_string centiles
      with Not_found ->
        Z.of_string s, Z.of_int 0
    in
    Tez (Z.add (Z.mul (Z.of_int 100) tezzies) centiles)

end

module Int : sig

  val of_string : string -> integer

end = struct

  let of_string n = Int (Z.of_string n)

end

module Timestamp : sig
  val of_string : string -> timestamp
  val to_string : timestamp -> string
end = struct
  let of_string s =
    Timestamp (Z.of_float (ISO8601.float_of_string s))
  let to_string = function
      Timestamp f -> ISO8601.string_of_float (Z.to_float f)
    | _ -> assert false

end


let z_of_int = function
    Tez n -> n
  | Int n -> n
  | Timestamp n -> n

module Array : sig
  val get : 'a -> integer -> 'b
  val set : 'a -> integer -> 'b -> 'a

end = struct (* Arrays are for tuples, not typable in OCaml *)

  let get t n =
    let n = z_of_int n in
    let n = Z.to_int n in
    Obj.magic (Obj.field (Obj.magic  t) n)

  let set t n x =
    let n = z_of_int n in
    let n = Z.to_int n in
    let t = Obj.repr t in
    let t = Obj.dup t in
    Obj.set_field t n (Obj.repr x);
    Obj.magic t

end

module Map : sig

  type ('key, 'value) map

  val empty : unit -> ('key,'value) map
  val make : ('key * 'value) list -> ('key, 'value) map
  val reduce : ( ('key * 'value) * 'acc -> 'acc) ->
               ('key,'value) map -> 'acc -> 'acc

  val map : ( 'key * 'value -> 'res) ->
               ('key,'value) map ->
               ('key,'res) map

  val find : 'key -> ('key, 'value) map -> 'value option

  val update : 'key -> 'value option  -> ('key, 'value) map ->
               ('key, 'value) map

  val mem : 'key -> ('key, 'value) map -> bool (* NOT TESTED *)
  val size : ('key, 'value) map -> int

end = struct

  module ObjMap = Map.Make(struct
                            type t = Obj.t
                            let compare = compare
                            end)

  type ('key, 'value) map
  let empty _ = Obj.magic ObjMap.empty
  let make list =
    let map =
      List.fold_left (fun map (key,value) ->
          let key = Obj.repr key in
          let value = Obj.repr value in
          ObjMap.add key value map
        ) (empty 0) list
    in
    Obj.magic map

  let reduce f map acc =
    let f = (Obj.magic f : (Obj.t * 'value) * Obj.t -> Obj.t) in
    let acc = Obj.repr acc in
    let map = (Obj.magic map : 'value ObjMap.t) in
    let (acc : Obj.t) = ObjMap.fold (fun key value acc ->
                            f ( (key,value), acc )
                          ) map acc
    in
    Obj.magic acc

  let map f map =
    let f = (Obj.magic f : Obj.t * 'value -> 'value) in
    let map = (Obj.magic map : 'value ObjMap.t) in
    let map = ObjMap.map (fun key value -> f (key,value)) map in
    Obj.magic map

  let find key map =
    try
      let key = Obj.repr key in
      let map = (Obj.magic map : 'value ObjMap.t) in
      Some (ObjMap.find key map)
    with Not_found -> None

  let update key value map = assert false (* TODO *)
  let mem key map = assert false (* TODO, NOT TESTED *)
  let size map = ObjMap.cardinal (Obj.magic map)

end
include Array (* Remove ? *)


type ('key,'value) map = ('key,'value) Map.map

module Set : sig

  type 'key set
  val empty : unit -> 'key set
  val make : 'key list -> 'key set
  val update : 'key -> bool -> 'key set -> 'key set
  val mem : 'key -> 'key set -> bool
  val reduce : ( 'key * 'acc -> 'acc) ->
               'key set -> 'acc -> 'acc
  val map : ('key -> 'res) -> 'key set -> 'res set
  val size : 'key set -> int

end = struct

  module ObjSet = Set.Make(struct
                            type t = Obj.t
                            let compare = compare
                            end)

  type 'key set

  let empty _ = Obj.magic ObjSet.empty
  let make list =
    let set =
      List.fold_left (fun set key ->
          let key = Obj.repr key in
          ObjSet.add key set
        ) (empty 0) list
    in
    Obj.magic set
  let update key bool set =
    let key = Obj.repr key in
    let set = (Obj.magic set : ObjSet.t) in
    let set =
      if bool then
        ObjSet.add key set
      else
        ObjSet.remove key set
    in
    Obj.magic set
  let mem key set =
    let key = Obj.repr key in
    let set = (Obj.magic set : ObjSet.t) in
    ObjSet.mem key set

  let reduce f set acc =
    let f = (Obj.magic f : Obj.t * Obj.t -> Obj.t) in
    let acc = Obj.repr acc in
    let set = (Obj.magic set : ObjSet.t) in
    let (acc : Obj.t) = ObjSet.fold (fun key acc ->
                            f (key, acc )
                          ) set acc
    in
    Obj.magic acc

  let map f set = assert false (* TODO, NOT TESTED *)
  let size set = ObjSet.cardinal (Obj.magic set)

end

type 'key set = 'key Set.set

module Arith : sig

  val (+) : integer -> integer -> integer
  val (-) : integer -> integer -> integer
  val ( * ) : integer -> integer -> integer
  val ( / ) : integer -> integer -> (integer * integer) option

  val int : integer -> integer
  val abs : integer -> integer

end = struct

  let (+) = Z.add
  let (+) x y =
    match x,y with
    | Timestamp x, Int y
    | Int x, Timestamp y
      -> Timestamp (x + y)
    | Tez x, Tez y -> Tez (x+y)
    | Int x, Int y -> Int (x+y)
    | Tez _, (Int _|Timestamp _)
      | (Int _ | Timestamp _), Tez _
    | Timestamp _, Timestamp _
      -> assert false


  let (-) = Z.sub
  let (-) x y =
    match x,y with
    | Timestamp x, Timestamp y -> Int (x - y)
    | Timestamp x, Int y
      -> Timestamp (x - y)
    | Tez x, Tez y -> Tez (x-y)
    | Int x, Int y -> Int (x-y)
    | Tez _, (Int _|Timestamp _)
      | (Int _ | Timestamp _), Tez _
    | Int _, Timestamp _
      -> assert false

  let ediv x y =
    try
      let (q, r) = Z.ediv_rem x y in
      Some (q, r)
    with _ -> None

  let (/) x y =
    try
      let (q, r) =
        let x = z_of_int x in
        let y = z_of_int y in
        Z.ediv_rem x y in
      Some (match x,y with
              Tez _, Tez _ -> Int q, Tez r
            | Tez _, Int _ -> Tez q, Tez r
            | Int _, Int _ -> Int q, Int r
            | Int _, Tez _
              | Int _, Timestamp _
              | Tez _, Timestamp _
              | Timestamp _, Tez _
              | Timestamp _, Int _
              | Timestamp _, Timestamp _
                                 -> assert false
           )
    with _ -> None

  let ( * ) = Z.mul
  let ( * ) x y =
    match x,y with
    | Tez x, Int y
    | Int x, Tez y -> Tez (x * y)
    | Int x, Int y -> Int (x * y)
      | Tez _, Tez _
        | Int _, Timestamp _
      | Tez _, Timestamp _
      | Timestamp _, Tez _
      | Timestamp _, Int _
      | Timestamp _, Timestamp _
      -> assert false

  let int x = x

  let abs = function Int x -> Int (Z.abs x)
                   | Tez _
                   | Timestamp _ -> assert false

end

let (@) = (^)

include Arith

module Lambda : sig
  val pipe : 'a -> ('a -> 'b) -> 'b
end = struct
  let pipe x f = f x
end

module Loop : sig
  val loop : ('a -> bool * 'a) -> 'a -> 'a
end = struct
  let rec loop f x =
    let (bool, ret) = f x in
    if bool then loop f ret
    else ret
end

type call = {
    contract : ( unit, unit ) contract;
    amount : tez;
  }

(* TODO: initialize with at least a fake address so that source will
not fail.*)
let calls = ref []

module Contract : sig

  val call : ('arg, 'res) contract -> tez -> 'storage -> 'arg ->
             'res * 'storage

  val manager : ('a,'b) contract -> key_hash
  val create : key_hash -> key_hash option ->
               bool -> bool -> tez ->
               ( ('a *'b) -> ('c * 'b) ) -> 'b ->
               ('a,'c) contract
  val source : unit -> ('a,'b) contract
  val self : unit -> ('a,'b) contract
end = struct

  let self () =
    match !calls with
    | [] -> assert false
    | call :: _ -> (Obj.magic call.contract : ('a,'b) contract)

  let source () =
    match !calls with
    | [] | [_] -> assert false
    | _ :: call :: _ -> (Obj.magic call.contract : ('a,'b) contract)

  let call contract amount storage arg =
    let c = self () in
    c.storage := Obj.repr storage;
    let res = contract.call arg in
    (res, Obj.magic ! (c.storage))

  let manager contract = contract.manager
  let create manager delegate
             spendable delegatable balance
             body storage =

    let storage = ref storage in
    let call arg =
      let (res, new_storage) = body (arg, !storage) in
      storage := new_storage;
      res
    in
    let storage : Obj.t ref = Obj.magic storage in
    let c = {
        manager;
        delegate;
        spendable; delegatable;
        balance;
        call;
        storage;
      } in
    c

end

module Current : sig

  val amount : unit -> tez
  val fail : unit -> 'a
  val time : unit -> timestamp
  val balance : unit -> tez
  val gas : unit -> tez (* NOT TESTED *)
  val contract : unit -> ('a,'b) contract (* unsafe, NOT IMPLEMENTED in Michelson !! *)
  val source : unit -> ('a,'b) contract (* NOT TESTED *)

end = struct

  let amount () =
    match !calls with
    | [] -> assert false
    | call :: _ -> call.amount

  let fail () = raise Fail
  let time () = Timestamp (Z.of_float (ISO8601.time ()))
  let balance () =
    let c = Contract.self () in
    c.balance
  let gas () = assert false (* TODO *)
  let contract () = Contract.self ()
  let source () = Contract.source ()
end


type ('a,'b) variant = Left of 'a | Right of 'b

module List : sig

  val reduce : ('a * 'b -> 'b) -> 'a list -> 'b -> 'b
  val map : ('a -> 'b) -> 'a list -> 'b list
  val rev : 'a list -> 'a list
  val size : 'a list -> integer

end = struct

  let rec reduce f list b =
    match list with
    | [] -> b
    | a :: list ->
       reduce f list (f (a,b))

  let map = List.map
  let rev = List.rev
  let size list = Int (Z.of_int (List.length list))

end

module Account : sig
  val create : key_hash -> key_hash option ->
               bool -> tez -> (unit,unit) contract
  val default : key_hash -> (unit,unit) contract
end = struct
  let create key key_opt _spendable _amount = assert false (* TODO NOT TESTED *)
  let default _key = assert false (* TODO *)
end

module Crypto : sig
  val hash : 'a -> string
  val hash_key : key -> key_hash
  val check : key -> signature * string -> bool
end = struct
  let hash _ = assert false (*TODO *)
  let hash_key _ = assert false (*TODO *)
  let check _key (_sig, _hash) = assert false (* TODO *)
end

type int = integer
