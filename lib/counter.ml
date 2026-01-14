open Hardcaml
open Signal

type t = Signal.t


let create
    ~width
    ~start_value
    ~clock
    ~start
    ~stop
    ~reset
  =
  let spec = Reg_spec.create ~clock () in

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

  let count =
      reg_fb
        spec
        ~enable:(is_running |: start |: reset)
        ~width
        ~f:(fun q -> (
            mux reset
            [
              (q +:. 1);
              (of_int ~width start_value)
            ]
          )
        )
    in

  count
