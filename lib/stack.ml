open Base
open Hardcaml
open Signal

type t =
  {
    mem   : Signal.t list;
    top   : Signal.t;
    full  : Signal.t;
    empty : Signal.t;
    sp    : Signal.t;
  }


let reg_bank
    ~clock
    ~depth
    ~addr
    ~write_en
    ~data_in
  =
    let spec = Reg_spec.create ~clock () in
    List.init depth ~f:(fun i ->
      let we = write_en &: (addr ==:. i) in
      reg
        spec
        ~enable:we
        data_in
    )


let create
    ~depth
    ~clock
    ~push
    ~pop
    ~data_in
    ~set_sp
    ~sp_val
  =

  let sp_width = Int.ceil_log2 depth in

  let overwritten_sp_val = mux push
    [
      sp_val;
      sp_val +:. 1;
    ]
  in

  let full = wire 1 in

  let sp =
    reg_fb
    (Reg_spec.create ~clock ())
    ~width:sp_width
    ~enable:(push |: pop |: set_sp)
    ~f:(fun sp ->
          mux (set_sp @: push)
            [
              (sp -:. 1);   (* pop *)
              (mux full [sp +:. 1; sp]);   (* push *)
              overwritten_sp_val;
              overwritten_sp_val;
            ]
        )
  in

  let mem =
    reg_bank
      ~clock
      ~depth
      ~addr:(mux set_sp [sp; sp_val])
      ~write_en:push
      ~data_in
  in

  let top = mux (sp -:. 1) mem in

  full <== (sp >=:. depth);
  let empty = (sp ==:. 0) in

  { mem; top; full; empty; sp }

