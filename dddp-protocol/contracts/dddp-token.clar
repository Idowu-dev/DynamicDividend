;; Dividend Token Contract
;; A token that allows holders to receive dividends proportional to their holdings

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_FAILED_TO_CLAIM (err u102))

;; Define the fungible token
(define-fungible-token dividend-token)

;; Track total supply
(define-data-var total-supply uint u0)

;; Track accumulated dividends per token
(define-data-var dividends-per-token uint u0)

;; Track user's last recorded dividends-per-token
(define-map user-dividends-paid 
    principal 
    uint)

;; Track claimable dividends for each user
(define-map claimable-dividends 
    principal 
    uint)

;; Mint new tokens
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (try! (ft-mint? dividend-token amount recipient))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true)))

;; Distribute dividends
(define-public (distribute-dividends (amount uint))
    (let ((supply (var-get total-supply)))
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
            (asserts! (> supply u0) ERR_INSUFFICIENT_BALANCE)
            ;; Update dividends per token
            (var-set dividends-per-token 
                (+ (var-get dividends-per-token) 
                   (/ (* amount u1000000) supply))) ;; Scale factor for precision
            (ok true))))

;; Calculate pending dividends for a user
(define-read-only (get-pending-dividends (user principal))
    (let ((balance (ft-get-balance dividend-token user))
          (paid (default-to u0 (map-get? user-dividends-paid user)))
          (current (var-get dividends-per-token)))
        (* balance (- current paid))))

;; Claim accumulated dividends
(define-public (claim-dividends)
    (let ((pending (get-pending-dividends tx-sender)))
        (begin
            (asserts! (> pending u0) ERR_INSUFFICIENT_BALANCE)
            (map-set user-dividends-paid 
                tx-sender 
                (var-get dividends-per-token))
            ;; Transfer dividends to user here
            (ok true))))

;; Standard SIP-010 transfer function
(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        ;; Handle any pending dividends before transfer
        (match (claim-dividends)
            success (ft-transfer? dividend-token amount sender recipient)
            error ERR_FAILED_TO_CLAIM)))  ;; Return error if claim fails