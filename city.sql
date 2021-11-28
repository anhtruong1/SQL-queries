
WITH city AS
(
SELECT distinct OffsetNumber
FROM
(
SELECT CicmpyCode AS Relation, Debtornumber AS OffsetNumber, OffsetName, InvoiceDate AS Date, InvoiceNumber, SupplierInvoiceNumber, (InvoiceAmount + ISNULL(DiscSurc,0)) AS InvoiceAmount, (InvoiceAmount) AS InvoiceAmountWithDiscSurc, DiscSurc, (Other) AS Other, (ReceiptPaid) AS ReceiptPaid, (((ISNULL(InvoiceAmount,0) + ISNULL(Other,0) + ISNULL(DiscSurc,0)) - ISNULL(ReceiptPaid,0))) AS Saldo, DueDate AS DueDate, (CASE WHEN (InvoiceAmount + ISNULL(DiscSurc,0)) = 0 THEN NULL WHEN DATEDIFF(dd, InvoiceDate, ActiveDate) = 0 THEN NULL ELSE DATEDIFF(dd, InvoiceDate, ActiveDate) END) AS ActiveDays, (CASE WHEN ISNULL(ReceiptPaid,0) <> 0 AND
(CASE WHEN (ROUND(ISNULL(OtherInvoice,0),2) = 0.0)
THEN ReceiptPaid * -1 ELSE (ISNULL(OtherInvoice,0)) -
(CASE WHEN ( ROUND(ISNULL(ABS(ReceiptPaid),0),2) > (ROUND(ISNULL(OtherInvoice,0),2))
AND ROUND(ReceiptPaid,2) <> 0.00) THEN (ISNULL(OtherInvoice,0)) ELSE ISNULL(ABS(Receiptpaid),0) END) END) = 0
THEN 1 ELSE 0 END) AS Paid, BankTransactions.Description AS Description, (CASE PaymentType WHEN 'A' THEN 'Automatic collection'
WHEN 'B' THEN 'On credit'
WHEN 'C' THEN 'Check'
WHEN 'D' THEN 'Post dated cheque'
WHEN 'E' THEN 'EFT'
WHEN 'F' THEN 'Factoring'
WHEN 'H' THEN 'Chipknip'
WHEN 'I' THEN 'Collection'
WHEN 'K' THEN 'Cash'
WHEN 'L' THEN 'Factoring: Letter of credit'
WHEN 'O' THEN 'Debt collection'
WHEN 'P' THEN 'Payment on delivery'
WHEN 'Q' THEN 'Confirming: Cheque'
WHEN 'R' THEN 'Credit card'
WHEN 'S' THEN 'To be settled'
WHEN 'W' THEN 'Letter of credit'
WHEN 'M' THEN 'Not accepted letter of credit'
WHEN 'N' THEN 'Promissory note'
WHEN 'T' THEN 'Factoring: Collection'
WHEN 'U' THEN 'Confirming: On credit'
WHEN 'V' THEN 'ESR payments'
WHEN 'Y' THEN 'Payments in FC'
WHEN 'X' THEN 'Payments in CHF'
WHEN 'Z' THEN 'Payments abroad'
ELSE PaymentType END) AS PaymentType, AmountTC, TCCode, TransactionType, Creditline, ExchangeRate FROM ((
-- Query 1 form clause start
(
-- Query 2 sum and max from the 2 subqueries, start
SELECT MIN(InvoiceDate) AS InvoiceDate, MAX(ActiveDate) AS ActiveDate,
InvoiceNumber, MAX(SupplierInvoiceNumber) AS SupplierInvoiceNumber,
MAX(a.Description) AS Description, MAX(DueDate) AS DueDate, SUM(InvoiceAmount) AS InvoiceAmount,
SUM(ReceiptPaid) AS ReceiptPaid, SUM(Other) AS Other,
SUM(DiscSurc) AS DiscSurc,
SUM(ISNULL(InvoiceAmount,0) + ISNULL(Other,0) + ISNULL(DiscSurc,0)) AS OtherInvoice, MAX(PaymentType) AS PaymentType,
MIN(TransactionType) As TransactionType, DebtorNumber, CreditorNumber, OffsetName, CicmpyCode, MAX(Creditline) AS Creditline, SUM(AmountTC) AS AmountTC, TCCode, MAX(ExchangeRate) AS ExchangeRate
FROM ((
( -- Query 3 start, look for all imbalance S term
SELECT T.ValueDate AS InvoiceDate, NULL as ActiveDate, ISNULL(T.InvoiceNumber,T.InvoiceNumber) AS InvoiceNumber,
'' AS SupplierInvoiceNumber,(CONVERT(VARCHAR(25),T.Description)) AS Description,
T.DueDate AS DueDate, NULL AS InvoiceAmount,
T.AmountDC AS ReceiptPaid,
NULL AS Other,
NULL AS DiscSurc,
T.PaymentType AS PaymentType,T.transactiontype AS Transactiontype,
T.OffsetLedgerAccountNumber, T.EntryNumber , T.OffsetReference, T.Ordernumber, T.CreditorNumber, T.DebtorNumber, ci.cmp_name AS OffsetName,
T.AmountTC, T.TCCode,
ci.debcode AS CicmpyCode,
creditline, NULL AS ExchangeRate
FROM BankTransactions T
LEFT OUTER JOIN cicmpy ci ON DebtorNumber = ci.debnr
AND DebtorNumber IS NOT NULL AND ci.debnr IS NOT NULL
LEFT JOIN (
SELECT btx.MatchID, ROUND(SUM(ROUND(btx.AmountDC,2)), 2) AS AmountDC FROM BankTransactions btx
WHERE btx.Type = 'W' AND btx.Status IN ('C','A','P','J') AND (NOT ISNULL(btx.EntryNumber,'')='')
GROUP BY btx.MatchID
HAVING btx.MatchID IS NOT NULL ) AS bts ON bts.MatchID = T.ID
WHERE T.Type = 'S' AND T.Status <> 'V'
AND ABS(ROUND(ISNULL(T.AmountDC,0),2)) <> ABS(ROUND(ISNULL(bts.AmountDC,0),2))
AND T.OffsetLedgerAccountNumber IN (SELECT reknr FROM grtbk WHERE omzrek IN ('D','C'))
AND ISNULL(ci.debcode,'') <> ''
AND ci.cmp_type = 'C'
AND ((T.Type = 'S' AND T.ProcessingDate IS NULL) OR CAST(FLOOR(CAST(T.ProcessingDate AS FLOAT)) AS DATETIME) BETWEEN {​​d '1800-01-01'}​​ AND {​​d '2021-05-05'}​​)
AND T.TransactionType = 'K' -- Query 3 end.
)
UNION ALL
(
-- Query 4 start, find all W term that having gbkmut, entrynumber is not null.
SELECT InvoiceDate , ISNULL((SELECT TOP 1 ValueDate FROM BankTransactions c WHERE c.ID = t.MatchID),{​​d '2021-05-05'}​​) As ActiveDate, InvoiceNumber AS InvoiceNumber, SupplierInvoiceNumber AS SupplierInvoiceNumber,
(CONVERT(varchar(25),T.Description)) AS Description,T.DueDate AS DueDate,
(CASE WHEN (T.Transactiontype IN ('C','K','T','Q','W') AND ISNULL(T.StatementType,'') <> 'F') OR (T.TransactionType IN ('K','T','D','C','Q') AND ISNULL(T.StatementType,'') = 'F') THEN T.AmountDC ELSE NULL END) AS InvoiceAmount,
(CASE WHEN T.MatchID IS NOT NULL AND T.TransactionType NOT IN ('Y','Z') THEN T.AmountDC ELSE NULL END) AS ReceiptPaid,
(CASE WHEN (T.Transactiontype NOT IN ('C','K','T','Q','W','Y','Z','F','U') AND ISNULL(T.StatementType,'') <> 'F') OR (T.TransactionType IN ('Y','Z') AND T.MatchID IS NULL ) OR (T.TransactionType IN ('N') OR (T.TransactionType IN ('F','U') AND ISNULL(T.StatementType, '') = 'F')) THEN T.AmountDC ELSE NULL END) AS Other,
(CASE WHEN (T.TransactionType IN ('F','U') AND ISNULL(T.StatementType,'') <> 'F') THEN T.AmountDC ELSE NULL END) AS DiscSurc,
T.PaymentType AS PaymentType,
(CASE WHEN (T.TransactionType IN ('C','K','T','Q','W') OR (T.TransactionType IN ('F','U') AND ISNULL(T.StatementType, '') = 'F')) THEN T.TransactionType ELSE NULL END) AS TransactionType,
T.OffsetLedgerAccountNumber, T.EntryNumber , T.OffsetReference, T.Ordernumber,
T.CreditorNumber, T.DebtorNumber, ci.cmp_name AS OffsetName,
T.AmountTC, T.TCCode,
ci.debcode AS CicmpyCode,
creditline, (CASE WHEN T.ExchangeRate = 0 THEN T.ExchangeRate ELSE (1/ExchangeRate) END) AS ExchangeRate
FROM BankTransactions T
LEFT OUTER JOIN cicmpy ci ON DebtorNumber = ci.debnr
AND DebtorNumber IS NOT NULL AND ci.debnr IS NOT NULL WHERE T.Type = 'W' AND T.Status IN ('C','A','P','J') AND (NOT ISNULL(T.EntryNumber,'')='')
AND NOT (T.TransactionType IN ('Y','Z') AND T.MatchID IS NOT NULL)
AND ISNULL(ci.debcode,'') <> ''
AND ci.cmp_type = 'C'
AND ((T.Type = 'S' AND T.ProcessingDate IS NULL) OR CAST(FLOOR(CAST(T.ProcessingDate AS FLOAT)) AS DATETIME) BETWEEN {​​d '1800-01-01'}​​ AND {​​d '2021-05-05'}​​)
AND T.TransactionType = 'K' -- Query 4 end
))) a
GROUP BY InvoiceNumber, EntryNumber, DebtorNumber, CreditorNumber, OffsetName, CicmpyCode, TCCode
-- Query 2 sum and max from the 2 subqueries, end
)
UNION ALL
(
-- Query 5 start, find imbalance S term
SELECT MIN(T.ValueDate) AS InvoiceDate, MAX(T.ValueDate) AS ActiveDate, T.InvoiceNumber AS InvoiceNumber, '' AS SupplierInvoiceNumber,
MAX((CONVERT(VARCHAR(25),T.Description))) AS Description, MAX(T.DueDate) AS DueDate, NULL AS InvoiceAmount, SUM(T.AmountDC - bts.AmountDC) AS ReceiptPaid,
NULL AS Other,
NULL AS DiscSurc,
NULL AS OtherInvoice, MAX(T.PaymentType) AS PaymentType, MAX(T.TransactionType) AS TransactionType, MAX(T.CreditorNumber) AS CreditorNumber, MAX(T.DebtorNumber) AS DebtorNumber, MAX(ci.cmp_name) AS OffsetName,
MAX(ci.debcode) AS CicmpyCode,
MAX(creditline),
SUM(AmountTC) AS AmountTC, TCCode, NULL AS ExchangeRate
FROM BankTransactions T
LEFT OUTER JOIN cicmpy ci ON DebtorNumber = ci.debnr
AND DebtorNumber IS NOT NULL AND ci.debnr IS NOT NULL
INNER JOIN (
SELECT btx.MatchID,ROUND(SUM(ROUND(btx.AmountDC,2)), 2) AS AmountDC
FROM BankTransactions btx
WHERE btx.Type = 'W' AND btx.Status IN ('C','A','P','J') AND (NOT ISNULL(btx.EntryNumber,'')='')
GROUP BY btx.MatchID
HAVING btx.MatchID IS NOT NULL
) AS bts ON bts.MatchID = T.ID
WHERE T.Type = 'S' AND T.Status <> 'V' AND (NOT ISNULL(T.EntryNumber,'')='')
AND ISNULL(ci.debcode,'') <> ''
AND ci.cmp_type = 'C'
AND ((T.Type = 'S' AND T.ProcessingDate IS NULL) OR CAST(FLOOR(CAST(T.ProcessingDate AS FLOAT)) AS DATETIME) BETWEEN {​​d '1800-01-01'}​​ AND {​​d '2021-05-05'}​​)
AND T.TransactionType = 'K'
GROUP BY T.ID, T.InvoiceNumber, T.EntryNumber, TCCode
HAVING (ROUND(SUM(ISNULL(T.AmountDC, 0) - ISNULL(bts.AmountDC, 0)), 2) <> 0)
-- Query 5 End
)
-- Query 1 from clause end
)) banktransactions) r),
fact AS
(
SELECT CicmpyCode AS Relation, Debtornumber AS OffsetNumber, OffsetName, InvoiceDate AS Date, InvoiceNumber, SupplierInvoiceNumber, (InvoiceAmount + ISNULL(DiscSurc,0)) AS InvoiceAmount, (InvoiceAmount) AS InvoiceAmountWithDiscSurc, DiscSurc, (Other) AS Other, (ReceiptPaid) AS ReceiptPaid, (((ISNULL(InvoiceAmount,0) + ISNULL(Other,0) + ISNULL(DiscSurc,0)) - ISNULL(ReceiptPaid,0))) AS Saldo, DueDate AS DueDate, (CASE WHEN (InvoiceAmount + ISNULL(DiscSurc,0)) = 0 THEN NULL WHEN DATEDIFF(dd, InvoiceDate, ActiveDate) = 0 THEN NULL ELSE DATEDIFF(dd, InvoiceDate, ActiveDate) END) AS ActiveDays, (CASE WHEN ISNULL(ReceiptPaid,0) <> 0 AND 
       (CASE WHEN (ROUND(ISNULL(OtherInvoice,0),2) = 0.0) 
       THEN ReceiptPaid * -1 ELSE (ISNULL(OtherInvoice,0)) - 
       (CASE WHEN ( ROUND(ISNULL(ABS(ReceiptPaid),0),2) > (ROUND(ISNULL(OtherInvoice,0),2)) 
       AND ROUND(ReceiptPaid,2) <> 0.00) THEN (ISNULL(OtherInvoice,0)) ELSE ISNULL(ABS(Receiptpaid),0) END) END) = 0 
       THEN 1 ELSE 0 END) AS Paid, BankTransactions.Description AS Description, (CASE PaymentType WHEN 'A' THEN 'Automatic collection'
 WHEN 'B' THEN 'On credit'
 WHEN 'C' THEN 'Check'
 WHEN 'D' THEN 'Post dated cheque'
 WHEN 'E' THEN 'EFT'
 WHEN 'F' THEN 'Factoring'
 WHEN 'H' THEN 'Chipknip'
 WHEN 'I' THEN 'Collection'
 WHEN 'K' THEN 'Cash'
 WHEN 'L' THEN 'Factoring: Letter of credit'
 WHEN 'O' THEN 'Debt collection'
 WHEN 'P' THEN 'Payment on delivery'
 WHEN 'Q' THEN 'Confirming: Cheque'
 WHEN 'R' THEN 'Credit card'
 WHEN 'S' THEN 'To be settled'
 WHEN 'W' THEN 'Letter of credit'
 WHEN 'M' THEN 'Not accepted letter of credit'
 WHEN 'N' THEN 'Promissory note'
 WHEN 'T' THEN 'Factoring: Collection'
 WHEN 'U' THEN 'Confirming: On credit'
 WHEN 'V' THEN 'ESR payments'
 WHEN 'Y' THEN 'Payments in FC'
 WHEN 'X' THEN 'Payments in CHF'
 WHEN 'Z' THEN 'Payments abroad'
 ELSE  PaymentType END) AS PaymentType, AmountTC, TCCode, TransactionType, Creditline, ExchangeRate FROM (( 
 -- Query 1 form clause start 
       ( 
       -- Query 2 sum and max from the 2 subqueries, start 
       SELECT MIN(InvoiceDate) AS InvoiceDate, MAX(ActiveDate) AS ActiveDate,
            InvoiceNumber, MAX(SupplierInvoiceNumber) AS SupplierInvoiceNumber, 
            MAX(a.Description) AS Description, MAX(DueDate) AS DueDate, SUM(InvoiceAmount) AS InvoiceAmount,
            SUM(ReceiptPaid) AS ReceiptPaid, SUM(Other) AS Other, 
            SUM(DiscSurc) AS DiscSurc, 
            SUM(ISNULL(InvoiceAmount,0) + ISNULL(Other,0) + ISNULL(DiscSurc,0)) AS OtherInvoice,             MAX(PaymentType) AS PaymentType,
            MIN(TransactionType) As TransactionType, DebtorNumber, CreditorNumber, OffsetName, CicmpyCode, MAX(Creditline) AS Creditline, SUM(AmountTC) AS AmountTC, TCCode, MAX(ExchangeRate) AS ExchangeRate
       FROM (( 
           ( -- Query 3 start, look for all imbalance S term 
           SELECT T.ValueDate AS InvoiceDate, NULL as ActiveDate, ISNULL(T.InvoiceNumber,T.InvoiceNumber) AS InvoiceNumber, 
                '' AS SupplierInvoiceNumber,(CONVERT(VARCHAR(25),T.Description)) AS Description, 
                T.DueDate AS DueDate, NULL AS InvoiceAmount,
                 T.AmountDC AS ReceiptPaid,
                NULL AS Other,
                NULL AS DiscSurc,
                T.PaymentType AS PaymentType,T.transactiontype AS Transactiontype,
                T.OffsetLedgerAccountNumber, T.EntryNumber , T.OffsetReference, T.Ordernumber, T.CreditorNumber, T.DebtorNumber, ci.cmp_name AS OffsetName,
                T.AmountTC, T.TCCode, 
                ci.debcode AS CicmpyCode, 
                creditline, NULL AS ExchangeRate
           FROM BankTransactions T 
           LEFT OUTER JOIN cicmpy ci ON DebtorNumber = ci.debnr
           AND DebtorNumber IS NOT NULL AND ci.debnr IS NOT NULL
           LEFT JOIN (
                SELECT btx.MatchID, ROUND(SUM(ROUND(btx.AmountDC,2)), 2) AS AmountDC FROM BankTransactions btx 
                WHERE btx.Type = 'W' AND btx.Status IN ('C','A','P','J') AND (NOT ISNULL(btx.EntryNumber,'')='') 
                GROUP BY btx.MatchID 
                HAVING btx.MatchID IS NOT NULL ) AS bts ON bts.MatchID = T.ID 
           WHERE T.Type = 'S' AND T.Status <> 'V' 
             AND ABS(ROUND(ISNULL(T.AmountDC,0),2)) <> ABS(ROUND(ISNULL(bts.AmountDC,0),2))
             AND T.OffsetLedgerAccountNumber IN (SELECT reknr FROM grtbk WHERE omzrek IN ('D','C'))
           AND ISNULL(ci.debcode,'') <> ''
 AND ci.cmp_type = 'C'
 AND T.TransactionType = 'K'

           -- Query 3 end. 
           ) 
           UNION ALL 
           (
           -- Query 4 start, find all W term that having gbkmut, entrynumber is not null. 
           SELECT InvoiceDate , ISNULL((SELECT TOP 1 ValueDate FROM BankTransactions c WHERE c.ID = t.MatchID),{d '2021-05-12'}) As ActiveDate, InvoiceNumber AS InvoiceNumber, SupplierInvoiceNumber AS SupplierInvoiceNumber, 
                (CONVERT(varchar(25),T.Description)) AS Description,T.DueDate AS DueDate,
                (CASE WHEN (T.Transactiontype IN ('C','K','T','Q','W') AND ISNULL(T.StatementType,'') <> 'F') OR (T.TransactionType IN ('K','T','D','C','Q') AND ISNULL(T.StatementType,'') = 'F') THEN T.AmountDC ELSE NULL END) AS InvoiceAmount,
                (CASE WHEN T.MatchID IS NOT NULL AND T.TransactionType NOT IN ('Y','Z') THEN T.AmountDC ELSE NULL END) AS ReceiptPaid,
                (CASE WHEN (T.Transactiontype NOT IN ('C','K','T','Q','W','Y','Z','F','U') AND ISNULL(T.StatementType,'') <> 'F') OR (T.TransactionType IN ('Y','Z') AND T.MatchID IS NULL ) OR (T.TransactionType IN ('N') OR (T.TransactionType IN ('F','U') AND ISNULL(T.StatementType, '') = 'F')) THEN T.AmountDC ELSE NULL END) AS Other,
                (CASE WHEN (T.TransactionType IN ('F','U') AND ISNULL(T.StatementType,'') <> 'F') THEN T.AmountDC ELSE NULL END) AS DiscSurc,
                T.PaymentType AS PaymentType,
                (CASE WHEN (T.TransactionType IN ('C','K','T','Q','W') OR (T.TransactionType IN ('F','U') AND ISNULL(T.StatementType, '') = 'F')) THEN T.TransactionType ELSE NULL END) AS TransactionType,
                T.OffsetLedgerAccountNumber, T.EntryNumber , T.OffsetReference, T.Ordernumber,
                T.CreditorNumber, T.DebtorNumber, ci.cmp_name AS OffsetName,
                T.AmountTC, T.TCCode, 
                ci.debcode AS CicmpyCode,
                creditline,           (CASE WHEN T.ExchangeRate = 0 THEN T.ExchangeRate ELSE (1/ExchangeRate) END) AS ExchangeRate
           FROM BankTransactions T 
           LEFT OUTER JOIN cicmpy ci ON DebtorNumber = ci.debnr 
           AND DebtorNumber IS NOT NULL AND ci.debnr IS NOT NULL            WHERE T.Type = 'W' AND T.Status IN ('C','A','P','J') AND (NOT ISNULL(T.EntryNumber,'')='') 
             AND NOT (T.TransactionType IN ('Y','Z') AND T.MatchID IS NOT NULL) 
           AND ISNULL(ci.debcode,'') <> ''
 AND ci.cmp_type = 'C'
 AND T.TransactionType = 'K'

           -- Query 4 end 
           ))) a 
           GROUP BY InvoiceNumber, EntryNumber, DebtorNumber, CreditorNumber, OffsetName, CicmpyCode, TCCode 
           -- Query 2 sum and max from the 2 subqueries, end 
           )
       UNION ALL 
       ( 
       -- Query 5 start, find imbalance S term  
       SELECT  MIN(T.ValueDate) AS InvoiceDate, MAX(T.ValueDate) AS ActiveDate, T.InvoiceNumber AS InvoiceNumber, '' AS SupplierInvoiceNumber,
            MAX((CONVERT(VARCHAR(25),T.Description))) AS Description, MAX(T.DueDate) AS DueDate, NULL AS InvoiceAmount, SUM(T.AmountDC - bts.AmountDC) AS ReceiptPaid,
            NULL AS Other, 
            NULL AS DiscSurc, 
            NULL AS OtherInvoice, MAX(T.PaymentType) AS PaymentType, MAX(T.TransactionType) AS TransactionType, MAX(T.CreditorNumber) AS CreditorNumber, MAX(T.DebtorNumber) AS DebtorNumber, MAX(ci.cmp_name) AS OffsetName,
            MAX(ci.debcode) AS CicmpyCode,
            MAX(creditline), 
            SUM(AmountTC) AS AmountTC, TCCode, NULL AS ExchangeRate
       FROM BankTransactions T 
       LEFT OUTER JOIN cicmpy ci ON DebtorNumber = ci.debnr
       AND DebtorNumber IS NOT NULL AND ci.debnr IS NOT NULL 
       INNER JOIN ( 
            SELECT btx.MatchID,ROUND(SUM(ROUND(btx.AmountDC,2)), 2) AS AmountDC
            FROM BankTransactions btx
            WHERE btx.Type = 'W' AND btx.Status IN ('C','A','P','J') AND (NOT ISNULL(btx.EntryNumber,'')='') 
            GROUP BY btx.MatchID 
            HAVING btx.MatchID IS NOT NULL 
            ) AS bts ON bts.MatchID = T.ID 
       WHERE T.Type = 'S' AND T.Status <> 'V' AND (NOT ISNULL(T.EntryNumber,'')='') 
       AND ISNULL(ci.debcode,'') <> ''
 AND ci.cmp_type = 'C'
 AND T.TransactionType = 'K'
       GROUP BY T.ID, T.InvoiceNumber, T.EntryNumber, TCCode
       HAVING (ROUND(SUM(ISNULL(T.AmountDC, 0) - ISNULL(bts.AmountDC, 0)), 2) <> 0)
       -- Query 5 End 
       ) 
 -- Query 1 from clause end 
 )) banktransactions ) 
 SELECT  DATEADD(day, ActiveDays, Date) PayDate
 FROM fact c
LEFT JOIN
(SELECT OffsetNumber as AccountNumber,cmp_name as AccountName, cmp_fcity as City, cmp_fctry as Country
FROM city 
INNER JOIN cicmpy
ON city.OffsetNumber = cicmpy.debnr) d
ON c.OffsetNumber = d.AccountName
WHERE Date < DATEADD(day, ActiveDays, Date)
GROUP BY City


