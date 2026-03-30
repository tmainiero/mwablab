(in-package :mwablab)

;;;; Category
;;;;
;;;; A category C consists of:
;;;;   - a collection of objects Ob(C)
;;;;   - for each pair of objects X, Y a set Hom_C(X, Y) of morphisms
;;;;   - for each object X an identity morphism id_X : X → X
;;;;   - for each composable pair f : X → Y, g : Y → Z a composite g ∘ f : X → Z
;;;;
;;;; satisfying unitality and associativity.
;;;;
;;;; Reference: Stacks Project, Tag 0013.

(defclass category ()
  ((name
    :initarg :name
    :accessor category-name
    :type string
    :documentation "Human-readable name for the category.")
   (objects
    :initarg :objects
    :accessor category-objects
    :documentation "Collection of objects, or a predicate (x) → boolean.")
   (hom
    :initarg :hom
    :accessor category-hom
    :documentation "Function (x y) → list (or set) of morphisms from x to y.
Encodes Hom_C(X, Y) for any objects X, Y.")
   (identity
    :initarg :identity
    :accessor category-identity
    :documentation "Function (x) → identity morphism id_X at x.
Must satisfy: compose(f, id_X) = f and compose(id_Y, f) = f for f : X → Y.")
   (compose
    :initarg :compose
    :accessor category-compose
    :documentation "Function (g f) → g ∘ f, the composite of f followed by g.
Arguments in diagrammatic order: f : X → Y, g : Y → Z, result : X → Z.
Must satisfy associativity: compose(h, compose(g, f)) = compose(compose(h, g), f)."))
  (:documentation "A category C. Stacks Project, Tag 0013.

A category consists of objects, hom-sets, identity morphisms, and a
composition law satisfying unitality and associativity.

Slots store the data as Lisp functions, enabling both finite (list-based)
and infinite (predicate/closure-based) categories."))

;;; Generic functions

(defgeneric id-morphism (cat obj)
  (:documentation "Return the identity morphism id_{OBJ} in category CAT.

For a category C and object X ∈ Ob(C), id_X ∈ Hom_C(X, X) is the
unique morphism satisfying:
  - f ∘ id_X = f  for all f : X → Y
  - id_X ∘ g = g  for all g : Z → X

Reference: Stacks Project, Tag 0013."))

(defmethod id-morphism ((cat category) obj)
  (funcall (category-identity cat) obj))

(defgeneric compose-morphisms (cat g f)
  (:documentation "Return the composite morphism G ∘ F in category CAT.

Given f : X → Y and g : Y → Z in C, returns g ∘ f : X → Z.
Arguments are in traditional (right-to-left) order: G is applied after F.

Must satisfy associativity:
  compose(h, compose(g, f)) = compose(compose(h, g), f)

Reference: Stacks Project, Tag 0013."))

(defmethod compose-morphisms ((cat category) g f)
  (funcall (category-compose cat) g f))

(defgeneric hom-set (cat x y)
  (:documentation "Return the hom-set Hom_C(X, Y) in category CAT.

The hom-set Hom_C(X, Y) is the collection of all morphisms f : X → Y
in the category C. Returns a list of morphisms (for finite categories)
or a closure-based representation (for infinite categories).

Reference: Stacks Project, Tag 0013."))

(defmethod hom-set ((cat category) x y)
  (funcall (category-hom cat) x y))
