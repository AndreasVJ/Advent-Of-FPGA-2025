open Base
open Hardcaml
open Signal


type t = Signal.t


let or_reduce d =
  tree ~arity:2 (bits_lsb d) ~f:(reduce ~f:( |: ))


let rec encode_onehot (onehot : Signal.t) ~out_data_width ~orig_onehot_width ~base_idx ~level : Signal.t =
  let w = width onehot in
  assert (Int.is_pow2 w);

  if w = 2 then
    (* base case *)
    mux (bit onehot 1)
      [
        of_int ~width:out_data_width (base_idx - 2);
        of_int ~width:out_data_width (base_idx - 1);
      ]
  else
    let half = w / 2 in
    let lo = select onehot (half - 1) 0 in
    let hi = select onehot (w - 1) half in

    let in_hi = or_reduce hi in

    let base_idx_delta = orig_onehot_width lsr level in

    mux in_hi
      [
        encode_onehot lo ~out_data_width ~orig_onehot_width ~base_idx:(base_idx - base_idx_delta) ~level:(level+1);
        encode_onehot hi ~out_data_width ~orig_onehot_width ~base_idx ~level:(level+1)
      ]


let create (x : Signal.t) =
  let data_width = width x in
  assert (Int.is_pow2 data_width);

  let out_data_width = Int.ceil_log2 (data_width+1) in

  let contains_ones = or_reduce x in

  (* CTO(x) = CTZ(~x) *)
  let y = ~:x in

  let onehot = y &: (x +:. 1) in
  let onehot_valid = or_reduce onehot in

  let onehot_idx = encode_onehot onehot ~out_data_width ~orig_onehot_width:data_width ~base_idx:data_width ~level:1 in

  let onehot_count = mux onehot_valid [(of_int ~width:out_data_width data_width); onehot_idx] in

  let count = mux contains_ones [(of_int ~width:out_data_width 0); onehot_count] in

  count

