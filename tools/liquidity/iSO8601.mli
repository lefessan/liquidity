(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2017       .                                          *)
(*    Fabrice Le Fessant, OCamlPro SAS <fabrice@lefessant.net>            *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(* either "yyyy-mm-dd" or "yyyy-mm-ddThh:mm" or "yyyy-mm-ddThh:mm:ss"
   or " "yyyy-mm-ddThh:mm+hh:mm" to  " "yyyy-mm-ddThh:mm+hh:mm" *)
val of_string : string -> string

(* In UTC *)
val float_of_string : string -> float
val string_of_float : float -> string
val time : unit -> float
