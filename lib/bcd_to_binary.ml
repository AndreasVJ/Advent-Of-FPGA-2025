open Base
open Hardcaml
open Signal


type t =
  {
    result: Signal.t;
    valid: Signal.t;
  }


let create
    ~clock
    ~digits
    ~start
  =

  let num_digits = List.length digits in
  let count_width = Int.ceil_log2 num_digits in
  let result_width =
    Int.of_float
      (Stdlib.Float.ceil (Float.of_int num_digits *. Float.log2 10.))
  in

  let spec = Reg_spec.create ~clock () in

  let digits_reg =
    List.map digits ~f:(fun d ->
      reg spec ~enable:start d
    )
  in

  let stop = wire 1 in

  let count = Counter.create
    ~width:count_width
    ~start_value:0
    ~clock
    ~start
    ~stop
    ~reset:start
  in

  let valid = (count >=:. num_digits) &: ~:start in
  stop <== valid;

  let is_running =
    reg
      spec
      ~enable:(start |: stop)
      (mux stop
        [
          vdd;
          gnd;
        ])
  in

  let result =
    reg_fb
      spec
      ~enable:((is_running &: ~:valid) |: start)
      ~width:result_width
      ~f:(fun q ->
        mux start
          [
            (
              let d = uresize (mux count digits_reg) result_width in
              let q_times_10 = (sll q 3) +: (sll q 1) in
              q_times_10 +: d
            );
            of_int ~width:result_width 0;
          ]
      )
  in

  {
    result;
    valid;
  }
