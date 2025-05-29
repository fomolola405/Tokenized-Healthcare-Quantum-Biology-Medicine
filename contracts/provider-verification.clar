;; Provider Verification Contract
;; Validates quantum biology practitioners

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CREDENTIALS (err u103))

;; Provider data structure
(define-map providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialization: (string-ascii 100),
    quantum-certification: bool,
    verification-date: uint,
    status: (string-ascii 20)
  }
)

;; Verification status tracking
(define-map verification-history
  { provider-id: principal, verification-id: uint }
  {
    verifier: principal,
    verification-type: (string-ascii 50),
    result: bool,
    timestamp: uint,
    notes: (string-ascii 500)
  }
)

(define-data-var next-verification-id uint u1)

;; Register a new quantum biology provider
(define-public (register-provider
  (provider-id principal)
  (name (string-ascii 100))
  (license-number (string-ascii 50))
  (specialization (string-ascii 100))
  (quantum-certification bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)

    (map-set providers
      { provider-id: provider-id }
      {
        name: name,
        license-number: license-number,
        specialization: specialization,
        quantum-certification: quantum-certification,
        verification-date: block-height,
        status: "pending"
      }
    )
    (ok true)
  )
)

;; Verify provider credentials
(define-public (verify-provider
  (provider-id principal)
  (verification-type (string-ascii 50))
  (result bool)
  (notes (string-ascii 500)))
  (let ((verification-id (var-get next-verification-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_NOT_FOUND)

    (map-set verification-history
      { provider-id: provider-id, verification-id: verification-id }
      {
        verifier: tx-sender,
        verification-type: verification-type,
        result: result,
        timestamp: block-height,
        notes: notes
      }
    )

    (if result
      (map-set providers
        { provider-id: provider-id }
        (merge (unwrap-panic (map-get? providers { provider-id: provider-id }))
               { status: "verified" }))
      (map-set providers
        { provider-id: provider-id }
        (merge (unwrap-panic (map-get? providers { provider-id: provider-id }))
               { status: "rejected" }))
    )

    (var-set next-verification-id (+ verification-id u1))
    (ok verification-id)
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id principal))
  (match (map-get? providers { provider-id: provider-id })
    provider-data (is-eq (get status provider-data) "verified")
    false
  )
)
