(in-package :mwablab)

;;;; Product Category
;;;;
;;;; Given categories C and D, the product category C x D has:
;;;;   - Objects: pairs (X, Y) with X in Ob(C), Y in Ob(D)
;;;;   - Morphisms: pairs (f, g) with f in Hom_C(X1,X2), g in Hom_D(Y1,Y2)
;;;;   - Identity: (id_X, id_Y)
;;;;   - Composition: (f2, g2) . (f1, g1) = (f2 . f1, g2 . g1)
;;;;
;;;; Reference: nLab, product+category.

;;; Product morphism representation

(defstruct (prod-morphism (:constructor make-prod-morphism (first second)))
  "A morphism in a product category, i.e. a pair (f, g) of morphisms
from the component categories.
Slots: FIRST — morphism in C. SECOND — morphism in D."
  first
  second)

;;; Product category construction

(defun product-category (cat-c cat-d)
  "Construct the product category C x D from categories C and D.

Objects are pairs (X, Y) with X in Ob(C) and Y in Ob(D).
Morphisms (X1,Y1) -> (X2,Y2) are pairs (f, g) with f : X1 -> X2 in C
and g : Y1 -> Y2 in D.
Identity and composition are componentwise.

Reference: nLab, product+category."
  (make-instance 'category
    :name (format nil "~A x ~A"
                  (category-name cat-c) (category-name cat-d))
    :objects (lambda (pair)
               (and (consp pair)
                    (funcall (category-objects cat-c) (car pair))
                    (funcall (category-objects cat-d) (cdr pair))))
    :hom (lambda (source target)
            (let ((hom-c (hom-set cat-c (car source) (car target)))
                  (hom-d (hom-set cat-d (cdr source) (cdr target))))
              (loop for f in hom-c
                    nconc (loop for g in hom-d
                                collect (make-prod-morphism f g)))))
    :identity (lambda (pair)
                (make-prod-morphism
                  (id-morphism cat-c (car pair))
                  (id-morphism cat-d (cdr pair))))
    :compose (lambda (g-pair f-pair)
               (make-prod-morphism
                 (compose-morphisms cat-c
                   (prod-morphism-first g-pair)
                   (prod-morphism-first f-pair))
                 (compose-morphisms cat-d
                   (prod-morphism-second g-pair)
                   (prod-morphism-second f-pair))))))

;;; Projection functors

(defun projection-functor-1 (cat-c cat-d)
  "The first projection functor pi_1 : C x D -> C.

Maps (X, Y) to X on objects and (f, g) to f on morphisms.

Reference: nLab, product+category."
  (make-instance 'functor
    :name (format nil "pi_1 : ~A x ~A -> ~A"
                  (category-name cat-c) (category-name cat-d)
                  (category-name cat-c))
    :source (product-category cat-c cat-d)
    :target cat-c
    :obj-map (lambda (pair) (car pair))
    :mor-map (lambda (prod-mor) (prod-morphism-first prod-mor))))

(defun projection-functor-2 (cat-c cat-d)
  "The second projection functor pi_2 : C x D -> D.

Maps (X, Y) to Y on objects and (f, g) to g on morphisms.

Reference: nLab, product+category."
  (make-instance 'functor
    :name (format nil "pi_2 : ~A x ~A -> ~A"
                  (category-name cat-c) (category-name cat-d)
                  (category-name cat-d))
    :source (product-category cat-c cat-d)
    :target cat-d
    :obj-map (lambda (pair) (cdr pair))
    :mor-map (lambda (prod-mor) (prod-morphism-second prod-mor))))

;;; Universal property: pairing functor

(defun pairing-functor (func-f func-g)
  "The pairing functor <F, G> : E -> C x D induced by the universal property.

Given F : E -> C and G : E -> D, returns the unique functor
<F, G> : E -> C x D such that pi_1 . <F,G> = F and pi_2 . <F,G> = G.

Reference: nLab, product+category."
  (let ((cat-c (functor-target func-f))
        (cat-d (functor-target func-g)))
    (make-instance 'functor
      :name (format nil "<~A, ~A>" (functor-name func-f) (functor-name func-g))
      :source (functor-source func-f)
      :target (product-category cat-c cat-d)
      :obj-map (lambda (e)
                 (cons (fobj func-f e) (fobj func-g e)))
      :mor-map (lambda (h)
                 (make-prod-morphism
                   (fmap func-f h)
                   (fmap func-g h))))))
