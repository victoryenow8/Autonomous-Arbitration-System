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

;; Public functions
(define-public (submit-case (defendant principal) (description (string-utf8 500)))
  (let (
    (case-id (var-get next-case-id))
    (plaintiff tx-sender)
  )
    (map-set cases
      { case-id: case-id }
      {
        plaintiff: plaintiff,
        defendant: defendant,
        description: description,
        status: "pending",
        evidence: (list),
        jurors: (list),
        votes: (list),
        verdict: none,
        deadline: (+ block-height u1000)
      }
    )
    (var-set next-case-id (+ case-id u1))
    (try! (add-case-to-user plaintiff case-id))
    (try! (add-case-to-user defendant case-id))
    (ok case-id)
  )
)

(define-public (add-evidence (case-id uint) (evidence-hash (string-utf8 500)))
  (let (
    (case (unwrap! (get-case case-id) (err err-not-found)))
  )
    (asserts! (is-case-participant case-id) (err err-unauthorized))
    (asserts! (is-eq (get status case) "pending") (err err-invalid-state))
    (asserts! (< block-height (get deadline case)) (err err-deadline-passed))
    (ok (map-set cases
      { case-id: case-id }
      (merge case { evidence: (unwrap! (as-max-len? (append (get evidence case) evidence-hash) u10) (err err-invalid-state)) })
    ))
  )
)

(define-public (volunteer-as-juror)
  (let (
    (current-pool (var-get juror-pool))
  )
    (asserts! (is-none (index-of current-pool tx-sender)) (err err-already-exists))
    (ok (var-set juror-pool (unwrap! (as-max-len? (append current-pool tx-sender) u1000) (err err-invalid-state))))
  )
)

(define-public (select-jurors (case-id uint))
  (let (
    (case (unwrap! (get-case case-id) (err err-not-found)))
    (pool (var-get juror-pool))
  )
    (asserts! (is-owner) (err err-owner-only))
    (asserts! (is-eq (get status case) "pending") (err err-invalid-state))
    (asserts! (>= (len pool) u5) (err err-insufficient-jurors))
    (let (
      (selected-jurors (fold select-juror pool (list)))
    )
      (ok (map-set cases
        { case-id: case-id }
        (merge case {
          status: "active",
          jurors: selected-jurors
        })
      ))
    )
  )
)

(define-private (select-juror (juror principal) (selected (list 5 principal)))
  (if (< (len selected) u5)
    (unwrap! (as-max-len? (append selected juror) u5) selected)
    selected
  )
)


