;; signal-outcome.wat — "this trading signal's call came true" (P3-01)
;;
;; An *observational* falsifier for Vantage trading signals. A signal becomes a
;; claim (kind 47001) whose inputs pin the record: asset, direction, entry
;; price, window and hit threshold. Whether the call came true is a fact about
;; the market after the window closed, so the falsifier reads exactly one
;; observation and nothing else:
;;
;;   manifest: {"observations":["signal:outcome"]}
;;   "hit"   -> holds          (signed return beat the threshold)
;;   "miss"  -> fails          (it did not)
;;   absent  -> indeterminate  (never gathered: the window is not marked yet)
;;   other   -> indeterminate  (an unknown token says nothing either way)
;;
;; Who supplies the observation is what gives each event its meaning:
;;   - a confirming source (47002) supplies "hit": its own signed call that
;;     the move happens, which settle() later scores against the oracle;
;;   - the resolver (47010) answers from the Mycelium signal_outcome mark,
;;     the exogenous ground truth.
;;
;; verdicts: 1 = holds, 2 = fails, 3 = indeterminate

(module
  (import "crucible" "observe_len"  (func $observe_len  (param i32 i32) (result i32)))
  (import "crucible" "observe_read" (func $observe_read (param i32 i32 i32)))
  (import "crucible" "emit"         (func $emit         (param i32 i32 i32)))

  (memory (export "memory") 1)

  ;; 0..14   the observation key
  ;; 32..    messages
  ;; 256..   where the observed value lands
  (data (i32.const 0)   "signal:outcome")
  (data (i32.const 32)  "signal call hit")
  (data (i32.const 64)  "signal call missed")
  (data (i32.const 96)  "signal outcome was never gathered")
  (data (i32.const 144) "signal outcome unrecognised")

  (func (export "crucible_falsify")
    (local $len i32)

    (local.set $len (call $observe_len (i32.const 0) (i32.const 14)))

    ;; -1: the window has not been marked. Say so; do not assume.
    (if (i32.lt_s (local.get $len) (i32.const 0))
      (then
        (call $emit (i32.const 3) (i32.const 96) (i32.const 33))
        (return)))

    ;; Anything longer than "miss" is not a token we know; never read it.
    (if (i32.gt_s (local.get $len) (i32.const 4))
      (then
        (call $emit (i32.const 3) (i32.const 144) (i32.const 27))
        (return)))

    (call $observe_read (i32.const 0) (i32.const 14) (i32.const 256))

    ;; "hit"
    (if (i32.and
          (i32.eq (local.get $len) (i32.const 3))
          (i32.and
            (i32.and
              (i32.eq (i32.load8_u (i32.const 256)) (i32.const 104))    ;; h
              (i32.eq (i32.load8_u (i32.const 257)) (i32.const 105)))   ;; i
            (i32.eq (i32.load8_u (i32.const 258)) (i32.const 116))))    ;; t
      (then
        (call $emit (i32.const 1) (i32.const 32) (i32.const 15))
        (return)))

    ;; "miss"
    (if (i32.and
          (i32.eq (local.get $len) (i32.const 4))
          (i32.and
            (i32.and
              (i32.eq (i32.load8_u (i32.const 256)) (i32.const 109))    ;; m
              (i32.eq (i32.load8_u (i32.const 257)) (i32.const 105)))   ;; i
            (i32.and
              (i32.eq (i32.load8_u (i32.const 258)) (i32.const 115))    ;; s
              (i32.eq (i32.load8_u (i32.const 259)) (i32.const 115))))) ;; s
      (then
        (call $emit (i32.const 2) (i32.const 64) (i32.const 18))
        (return)))

    (call $emit (i32.const 3) (i32.const 144) (i32.const 27)))
)
