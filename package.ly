% Pedal bracket decorations - text on LHS and arrows on RHS.
% Andrew Bernard
% With thanks to Thomas Morley for spanner bounds code.

pedalWithArrowsAndTextCallback =
#(define-scheme-function (lhs-text use-arrows)
   (string? boolean?)
   "lhs-text - text to decorate LHS of bracket.
    use-arrows - boolean: use arrows on RHS if true."
   (define (make-arrow-path arrow-length arrowhead-height arrowhead-width)
     "Draw arrow with triangular arrowhead."
     (list
      'moveto 0 0
      'lineto arrow-length 0
      'lineto arrow-length (/ arrowhead-width 2)
      'lineto (+ arrow-length arrowhead-height) 0
      'lineto arrow-length (- (/ arrowhead-width 2))
      'lineto arrow-length 0
      'closepath
      ))
   (lambda (grob)
     ;; function to modify the individual grob part
     (define add-decorations
       (lambda (g list-length)
         (let* (
                 ;; unpack the argument
                 (index (car g))
                 (grobber (cadr g))
                 (last (= index list-length))
                 ;; get the default-stencil and its x-dimension and x-length.
                 (stil (ly:piano-pedal-bracket::print grobber))
                 (stil-x-extent (ly:stencil-extent stil X))
                 (stil-x-length (interval-length stil-x-extent))
                 ;; make arrow for the rhs end
                 (new-stil (if (and use-arrows (not last))
                               (begin
                                (let* (
                                        (thickness 0.1)
                                        (arrowhead-height 1.0)
                                        (arrowhead-width 1.0)
                                        (arrow-length 1.0)
                                        (arrow
                                         (make-path-stencil
                                          (make-arrow-path
                                           arrow-length
                                           arrowhead-height
                                           arrowhead-width)
                                          thickness 1 1 #t)))
                                  (ly:stencil-combine-at-edge stil X RIGHT arrow -2)))
                               stil))
                 ;; make text for the lhs end
                 (text-stil
                  (grob-interpret-markup grobber
                    (markup
                     #:line
                     (#:abs-fontsize
                      6
                      (#:sans
                       (#:upright
                        (#:whiteout (#:box (#:pad-markup 0.3 lhs-text)))))))))
                 (text-stil-x-extent (ly:stencil-extent text-stil X))
                 (text-stil-x-length (interval-length text-stil-x-extent))
                 ;; get a list of spanners bounded by PianoPedalBrackets
                 ;; left-bound, which is PaperColumn or NonMusicalPaperColumn
                 (left-bound-spanners
                  (ly:grob-array->list
                   (ly:grob-object
                    (ly:spanner-bound grobber LEFT)
                    'bounded-by-me)))
                 ;; filter left-bound-spanners for PianoPedalBrackets
                 (piano-pedal-brackets
                  (filter
                   (lambda (gr)
                     (grob::has-interface gr 'piano-pedal-bracket-interface))
                   left-bound-spanners))
                 ;; delete identical PianoPedalBracket from piano-pedal-brackets
                 ;; TODO `delete-duplicates' may be expensive, see guile-manual
                 ;;      find another method
                 (bounded-piano-brackets-per-column
                  (delete-duplicates piano-pedal-brackets))
                 ;; add text
                 ;; only add text-stil, if current Column does not have two
                 ;; PianoPedalBrackets
                 ;; TODO is this condition re columns really sufficient?
                 ;; also, do not add text-stil if the segment is too short.
                 (new-stil
                  (if (or
                       (= (length bounded-piano-brackets-per-column) 2)
                       (< stil-x-length text-stil-x-length))
                      new-stil
                      (ly:stencil-stack new-stil X LEFT text-stil -8))))
           (ly:grob-set-property! grobber 'stencil new-stil))))
     (let* (
             ;; get broken pieces, or the single unbroken grob
             (orig (ly:grob-original grob))
             (pieces (ly:spanner-broken-into orig))
             (pieces (if (null? pieces)
                         (list orig)
                         pieces))
             (pieces-indexed-list (zip (iota (length pieces) 1) pieces))
             (pieces-length (length pieces)))
       ;; We want arrows on all segments but the last, and text on all segments,
       ;; so we have to pass some notion of list index to the function doing the
       ;; decorating. Hence the ziplist combining grob segment and index in pairs.
       (let loop ((count 0))
         (if (< count pieces-length)
             (begin
              (add-decorations (list-ref pieces-indexed-list count) pieces-length)
              (loop (+ count 1))))))))