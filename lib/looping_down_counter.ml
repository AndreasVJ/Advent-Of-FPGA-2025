open Hardcaml
open Signal

type t = Signal.t

let create
    ~clock
    ~reset
    ~enable
    ~width
    ~start_value
  =
  let spec = Reg_spec.create ~clock () in

  let value =
    reg_fb
      spec
      ~enable:(enable |: reset)
      ~width
      ~f:(fun q ->
        mux2 reset
          (of_int ~width start_value)
          (mux2
             (q ==:. 0)
             (of_int ~width start_value)
             (q -:. 1)))
  in

  value
