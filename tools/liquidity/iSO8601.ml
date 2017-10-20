(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2017       .                                          *)
(*    Fabrice Le Fessant, OCamlPro SAS <fabrice@lefessant.net>            *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(* TODO: I am not sure that the timezones are correctly handled. We
  should improve that, maybe use "calendar" *)

let cut_at s c =
  try
    let pos = String.index s c in
    String.sub s 0 pos,
    Some (String.sub s (pos+1) (String.length s - pos -1))
  with Not_found -> s, None

let gap_gmt_local =
  let t = Unix.time () in
  let local_tm = Unix.localtime t in
  let gm_tm = Unix.gmtime t in
  let gap =
    ((local_tm.Unix.tm_hour - gm_tm.Unix.tm_hour) * 60 +
       (local_tm.Unix.tm_min - gm_tm.Unix.tm_min)) * 60
  in
  float_of_int gap

let rec split_at s c =
  match cut_at s c with
  | head, None -> [head]
  | head, Some tail ->
     head :: split_at tail c

let of_string s =
  let date, hour = cut_at s 'T' in
  let hour, timezone =
    match hour with
    | None -> "00:00:00", "00:00"
    | Some s ->
       let hour, timezone = cut_at s '+' in
       let hour = if String.length hour = 5 then hour ^ ":00" else hour in
       let timezone = match timezone with
           None -> "00:00"
         | Some timezone -> timezone
       in
       (hour, timezone)
  in
  Printf.sprintf "%sT%s+%s" date hour timezone

let float_of_string s =
  let date, hour = cut_at s 'T' in
  let hour, timezone =
    match hour with
    | None -> "00:00:00", "00:00"
    | Some s ->
       let hour, timezone = cut_at s '+' in
       let hour = if String.length hour = 5 then hour ^ ":00" else hour in
       let timezone = match timezone with
           None -> "00:00"
         | Some timezone -> timezone
       in
       (hour, timezone)
  in
  let date = split_at date '-' in
  let hour = split_at hour ':' in
  let timezone = split_at timezone ':' in
  match date, hour, timezone with
    [ year; month; mday ], [ hour; min; sec ], [tz_hour; tz_min ] ->
    let tm = {
      Unix.tm_year = int_of_string year - 1900;
      tm_mon = int_of_string month - 1;
      tm_mday = int_of_string mday;
      tm_hour = int_of_string hour;
      tm_min = int_of_string min;
      tm_sec = int_of_string sec;
      tm_wday = 0;
      tm_yday = 0;
      tm_isdst = false;
      } in
    let float, _tm = Unix.mktime tm in
    let float = float -. gap_gmt_local in
    let tz_offset = 3600 * int_of_string tz_hour + 60 *
                                                     int_of_string tz_min
    in
    float +. (float_of_int tz_offset)
  | _ -> failwith "ISO8601.tm_of_string"

let string_of_float float =
  let tm = Unix.localtime (float +. gap_gmt_local) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02d+00:00"
                 (1900+tm.Unix.tm_year)
                 (1+tm.Unix.tm_mon)
                 tm.Unix.tm_mday
                 tm.Unix.tm_hour
                 tm.Unix.tm_min
                 tm.Unix.tm_sec

let time () =
  Unix.time () -. gap_gmt_local
