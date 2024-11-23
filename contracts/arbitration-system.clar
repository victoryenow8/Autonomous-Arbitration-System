;; Decentralized Autonomous Arbitration System

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-state (err u104))
(define-constant err-deadline-passed (err u105))
(define-constant err-insufficient-jurors (err u106))

;; Data variables
(define-data-var next-case-id uint u0)
(define-data-var juror-pool (list 1000 principal) (list))

;; Data maps
(define-map cases
  { case-id: uint }
  {
    plaintiff: principal,
    defendant: principal,
    description: (string-utf8 500),
    status: (string-ascii 20),
    evidence: (list 10 (string-utf8 500)),
    jurors: (list 5 principal),
    votes: (list 5 uint),
    verdict: (optional (string-utf8 500)),
    deadline: uint
  }
)

(define-map user-cases
  { user: principal }
  { case-ids: (list 100 uint) }
)

;; Private functions
(define-private (is-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-case-participant (case-id uint))
  (let (
    (case (unwrap! (get-case case-id) false))
  )
    (or
      (is-eq tx-sender (get plaintiff case))
      (is-eq tx-sender (get defendant case))
    )
  )
)

(define-private (is-juror (case-id uint))
  (let (
    (case (unwrap! (get-case case-id) false))
  )
    (is-some (index-of (get jurors case) tx-sender))
  )
)

(define-private (add-case-to-user (user principal) (case-id uint))
  (let (
    (user-case-list (default-to (list) (get case-ids (map-get? user-cases { user: user }))))
  )
    (match (as-max-len? (append user-case-list case-id) u100)
      success (ok (map-set user-cases
        { user: user }
        { case-ids: success }
      ))
      (err err-invalid-state)
    )
  )
)

