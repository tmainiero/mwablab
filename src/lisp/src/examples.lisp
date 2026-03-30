(in-package :mwablab)

;;;; Concrete examples for REPL exploration
;;;;
;;;; These are finite and simple categories for testing, prototyping,
;;;; and illustrating the categorical DSL. They are not meant to be
;;;; mathematically exhaustive — only computationally useful.
;;;;
;;;; Reference: Stacks Project, Tag 0013.

;;; ─── Helpers ────────────────────────────────────────────────────────────────

(defun make-finite-category (name objects morphisms)
  "Construct a finite category from NAME, a list of OBJECTS, and a list of MORPHISMS.

MORPHISMS is a list of triples (dom cod label), where:
  - dom  is the domain object
  - cod  is the codomain object
  - label is any identifier for the morphism

Identity morphisms are generated automatically as (x x :id) for each x in OBJECTS.
Composition is defined by lookup: (g ∘ f) finds the unique morphism h with
  dom(h) = dom(f) and cod(h) = cod(g) and h is in MORPHISMS (or the identity).

This is suitable for posets, graphs, and other small combinatorial categories.
For non-trivial composition (e.g. monoids), supply morphisms with explicit
composites and use MAKE-INSTANCE 'CATEGORY directly.

Reference: Stacks Project, Tag 0013."
  (let* (;; Augment with identity morphisms
         (all-morphisms
           (append
            (mapcar (lambda (x) (list x x (intern (format nil "ID-~A" x) :keyword)))
                    objects)
            morphisms))
         ;; Build lookup: (dom . cod) → list of morphisms
         (hom-table (make-hash-table :test #'equal)))
    ;; Populate hom-table
    (dolist (m all-morphisms)
      (destructuring-bind (dom cod label) m
        (declare (ignore label))
        (push m (gethash (cons dom cod) hom-table '()))))
    ;; Identity function: find the (x x :id-x) entry
    (flet ((find-identity (x)
             (find x all-morphisms
                   :key (lambda (m) (and (equal (first m) x)
                                         (equal (second m) x)
                                         m))
                   :test (lambda (a b) (and b (equal a (first b)) (equal a (second b))))))
           (find-composite (f g)
             ;; f : A → B, g : B → C — result has dom A, cod C
             (let* ((a (first f))
                    (c (second g))
                    (candidates (gethash (cons a c) hom-table)))
               (first candidates))))
      (make-instance 'category
        :name name
        :objects objects
        :hom (lambda (x y)
               (mapcar #'third (gethash (cons x y) hom-table '())))
        :identity (lambda (x)
                    (third (find-identity x)))
        :compose (lambda (g f)
                   (third (find-composite f g)))))))

(defun make-discrete-category (objects)
  "Construct the discrete category on OBJECTS.

The discrete category on a set S has:
  - Ob = S
  - Hom(X, Y) = {id_X}  if X = Y,  ∅ otherwise
  - Composition: id_X ∘ id_X = id_X

Every object is its own identity; there are no non-identity morphisms.
This is the free category on a set of objects with no morphisms.

Reference: Stacks Project, Tag 0013."
  (make-instance 'category
    :name (format nil "Disc(~A)" objects)
    :objects objects
    :hom (lambda (x y)
           (if (equal x y) (list :id) '()))
    :identity (lambda (x) (declare (ignore x)) :id)
    :compose (lambda (g f)
               (declare (ignore g))
               f)))

;;; ─── *set-category* ─────────────────────────────────────────────────────────
;;;
;;; A finite approximation of Set for exploration.
;;; Objects are a handful of named finite sets; morphisms are total functions
;;; represented as association lists (input . output).
;;;
;;; This is not a full categorical model of Set — it is a sandbox for
;;; checking that the generic functions work on a concrete example.

(defvar *finite-sets*
  (list :empty :one :two :three)
  "Named finite sets used in *set-category*.
  :empty — ∅
  :one   — {*}
  :two   — {0, 1}
  :three — {0, 1, 2}")

(defvar *finite-set-elements*
  '((:empty . ())
    (:one   . (*))
    (:two   . (0 1))
    (:three . (0 1 2)))
  "Elements of each named finite set in *set-category*.")

(defun finite-set-elements (name)
  "Return the elements of the finite set named NAME."
  (cdr (assoc name *finite-set-elements*)))

(defun all-functions (dom-elts cod-elts)
  "Return all total functions from DOM-ELTS to COD-ELTS as association lists.

A function f : A → B is represented as an alist mapping each element of A
to an element of B. The number of such functions is |B|^|A|.

Returns NIL (the empty list) when DOM-ELTS is non-empty and COD-ELTS is empty,
since no total function exists from a non-empty set to the empty set."
  (if (null dom-elts)
      (list '())                        ; unique function from ∅
      (when cod-elts
        (loop for rest in (all-functions (rest dom-elts) cod-elts)
              append
              (loop for b in cod-elts
                    collect (cons (cons (first dom-elts) b) rest))))))

(defun compose-functions (g f)
  "Compose functions F and G (as alists), returning G ∘ F.

For f : A → B and g : B → C represented as alists,
(g ∘ f)(x) = g(f(x)) for each x ∈ A."
  (mapcar (lambda (pair)
            (cons (car pair)
                  (cdr (assoc (cdr pair) g))))
          f))

(defvar *set-category*
  (make-instance 'category
    :name "FinSet"
    :objects *finite-sets*
    :hom (lambda (x y)
           (all-functions (finite-set-elements x)
                          (finite-set-elements y)))
    :identity (lambda (x)
                (mapcar (lambda (e) (cons e e))
                        (finite-set-elements x)))
    :compose #'compose-functions)
  "A finite approximation of Set for REPL exploration.

Objects are named finite sets :empty, :one, :two, :three.
Morphisms are total functions represented as association lists.
Composition is function composition.

This is a concrete sandbox for exploring categorical constructions.
It does not represent all of Set — only the finite fragment needed
for local exploration.

Reference: Stacks Project, Tag 0013.")
