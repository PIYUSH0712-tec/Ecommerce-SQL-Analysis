/********************************************************************
 E-COMMERCE (UK ONLINE RETAIL) – SQLITE PROJECT
 Author: Piyush
 Description:
   - Source CSV imported as table: online_retail_raw
   - This script:
       * Explores the raw data
       * Builds relational tables
       * Demonstrates SELECT / WHERE / GROUP BY
       * Demonstrates JOINS (INNER, LEFT, RIGHT-style)
       * Uses subqueries and aggregates
       * Creates views for analysis
       * Adds indexes for basic optimisation
********************************************************************/

-------------------------------------------------------------------
-- SECTION 0: ASSUMPTION ABOUT RAW TABLE
-------------------------------------------------------------------
-- Assumes the CSV has already been imported into SQLite as:
--   online_retail_raw(InvoiceNo, StockCode, Description,
--                     Quantity, InvoiceDate, UnitPrice,
--                     CustomerID, Country);
--
-- You did this using sqliteonline.com Import → CSV.

-------------------------------------------------------------------
-- SECTION 1: BASIC DATA EXPLORATION
-------------------------------------------------------------------

-- 1.1 Total number of rows in the raw table
SELECT COUNT(*) AS total_rows
FROM online_retail_raw;

-- 1.2 Check missing values in key columns
SELECT
    SUM(CASE WHEN InvoiceNo IS NULL OR InvoiceNo = '' THEN 1 ELSE 0 END) AS missing_InvoiceNo,
    SUM(CASE WHEN StockCode IS NULL OR StockCode = '' THEN 1 ELSE 0 END) AS missing_StockCode,
    SUM(CASE WHEN Description IS NULL OR Description = '' THEN 1 ELSE 0 END) AS missing_Description,
    SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS missing_Quantity,
    SUM(CASE WHEN InvoiceDate IS NULL OR InvoiceDate = '' THEN 1 ELSE 0 END) AS missing_InvoiceDate,
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS missing_UnitPrice,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS missing_CustomerID,
    SUM(CASE WHEN Country IS NULL OR Country = '' THEN 1 ELSE 0 END) AS missing_Country
FROM online_retail_raw;

-- 1.3 Sample of latest invoices (by date)
SELECT *
FROM online_retail_raw
ORDER BY InvoiceDate DESC
LIMIT 10;

-- 1.4 Number of unique countries
SELECT COUNT(DISTINCT Country) AS unique_countries
FROM online_retail_raw;


-------------------------------------------------------------------
-- SECTION 2: BUILD RELATIONAL TABLES FROM RAW DATA
-------------------------------------------------------------------

-- 2.1 Customers table
DROP TABLE IF EXISTS customers;

CREATE TABLE customers AS
SELECT DISTINCT
    CAST(CustomerID AS INTEGER) AS CustomerID,
    Country
FROM online_retail_raw
WHERE CustomerID IS NOT NULL;

-- 2.2 Products table
DROP TABLE IF EXISTS products;

CREATE TABLE products AS
SELECT DISTINCT
    StockCode,
    Description,
    UnitPrice
FROM online_retail_raw
WHERE StockCode IS NOT NULL;

-- 2.3 Invoices (order headers)
DROP TABLE IF EXISTS invoices;

CREATE TABLE invoices AS
SELECT DISTINCT
    InvoiceNo,
    InvoiceDate,
    CAST(CustomerID AS INTEGER) AS CustomerID
FROM online_retail_raw
WHERE InvoiceNo IS NOT NULL;

-- 2.4 Invoice items (order line items)
DROP TABLE IF EXISTS invoice_items;

CREATE TABLE invoice_items AS
SELECT
    InvoiceNo,
    StockCode,
    Quantity,
    UnitPrice
FROM online_retail_raw
WHERE InvoiceNo IS NOT NULL
  AND StockCode IS NOT NULL;


-------------------------------------------------------------------
-- SECTION 3: CORE SELECT / WHERE / ORDER BY / GROUP BY
-------------------------------------------------------------------

-- 3.1 Recent invoices for a specific customer
SELECT 
    InvoiceNo,
    InvoiceDate,
    CustomerID
FROM invoices
WHERE CustomerID = 17850
ORDER BY InvoiceDate DESC
LIMIT 20;

-- 3.2 Revenue by country (descending)
SELECT 
    Country,
    SUM(Quantity * UnitPrice) AS total_revenue
FROM online_retail_raw
GROUP BY Country
ORDER BY total_revenue DESC;

-- 3.3 Total quantity sold per product
SELECT 
    p.StockCode,
    p.Description,
    SUM(ii.Quantity) AS total_quantity_sold
FROM products AS p
JOIN invoice_items AS ii
      ON p.StockCode = ii.StockCode
GROUP BY p.StockCode, p.Description
ORDER BY total_quantity_sold DESC
LIMIT 20;

-- 3.4 Revenue for the United Kingdom only
SELECT 
    SUM(Quantity * UnitPrice) AS uk_revenue
FROM online_retail_raw
WHERE Country = 'United Kingdom';


-------------------------------------------------------------------
-- SECTION 4: JOINS (INNER, LEFT, RIGHT-STYLE, MULTI-TABLE)
-------------------------------------------------------------------

-- 4.1 INNER JOIN: invoices with customers
SELECT 
    i.InvoiceNo,
    i.InvoiceDate,
    i.CustomerID,
    c.Country
FROM invoices AS i
INNER JOIN customers AS c
    ON i.CustomerID = c.CustomerID
LIMIT 20;

-- 4.2 LEFT JOIN: all invoices, customers if they exist
SELECT 
    i.InvoiceNo,
    i.InvoiceDate,
    i.CustomerID,
    c.Country
FROM invoices AS i
LEFT JOIN customers AS c
    ON i.CustomerID = c.CustomerID
ORDER BY i.InvoiceDate
LIMIT 20;

-- 4.3 RIGHT JOIN style (emulated):
--     all customers who have at least one invoice
SELECT 
    c.CustomerID,
    c.Country,
    i.InvoiceNo,
    i.InvoiceDate
FROM customers AS c
LEFT JOIN invoices AS i
    ON i.CustomerID = c.CustomerID
WHERE i.InvoiceNo IS NOT NULL
ORDER BY c.CustomerID
LIMIT 20;

-- 4.4 Multi-table join:
--     product performance (quantity + revenue)
SELECT 
    p.StockCode,
    p.Description,
    SUM(ii.Quantity) AS total_qty,
    SUM(ii.Quantity * ii.UnitPrice) AS revenue
FROM invoice_items AS ii
JOIN products AS p
    ON ii.StockCode = p.StockCode
JOIN invoices AS i
    ON ii.InvoiceNo = i.InvoiceNo
GROUP BY p.StockCode, p.Description
ORDER BY revenue DESC
LIMIT 15;


-------------------------------------------------------------------
-- SECTION 5: SUBQUERIES & AGGREGATE ANALYSIS
-------------------------------------------------------------------

-- 5.1 High-value customers:
--     customers whose revenue is above average customer revenue
WITH customer_sales AS (
    SELECT 
        i.CustomerID,
        SUM(ii.Quantity * ii.UnitPrice) AS revenue
    FROM invoices AS i
    JOIN invoice_items AS ii
        ON i.InvoiceNo = ii.InvoiceNo
    WHERE i.CustomerID IS NOT NULL
    GROUP BY i.CustomerID
)
SELECT *
FROM customer_sales
WHERE revenue > (SELECT AVG(revenue) FROM customer_sales)
ORDER BY revenue DESC
LIMIT 20;

-- 5.2 Top 5 countries by revenue (subquery in FROM)
SELECT 
    Country,
    total_revenue
FROM (
    SELECT 
        Country,
        SUM(Quantity * UnitPrice) AS total_revenue
    FROM online_retail_raw
    GROUP BY Country
) AS t
ORDER BY total_revenue DESC
LIMIT 5;

-- 5.3 Overall revenue and average line revenue
SELECT
    SUM(Quantity * UnitPrice) AS total_revenue,
    AVG(Quantity * UnitPrice) AS avg_line_revenue
FROM online_retail_raw;

-- 5.4 Average revenue per invoice
SELECT 
    AVG(invoice_revenue) AS avg_invoice_revenue
FROM (
    SELECT 
        InvoiceNo,
        SUM(Quantity * UnitPrice) AS invoice_revenue
    FROM online_retail_raw
    GROUP BY InvoiceNo
) AS per_invoice;


-------------------------------------------------------------------
-- SECTION 6: VIEWS FOR REUSABLE ANALYSIS
-------------------------------------------------------------------

-- 6.1 View: revenue per country
DROP VIEW IF EXISTS v_country_revenue;

CREATE VIEW v_country_revenue AS
SELECT 
    Country,
    SUM(Quantity * UnitPrice) AS total_revenue
FROM online_retail_raw
GROUP BY Country;

-- Example usage of v_country_revenue
SELECT *
FROM v_country_revenue
ORDER BY total_revenue DESC
LIMIT 10;

-- 6.2 View: detailed invoice analysis
DROP VIEW IF EXISTS v_invoice_details;

CREATE VIEW v_invoice_details AS
SELECT 
    i.InvoiceNo,
    i.InvoiceDate,
    c.CustomerID,
    c.Country,
    p.StockCode,
    p.Description,
    ii.Quantity,
    ii.UnitPrice,
    ii.Quantity * ii.UnitPrice AS line_revenue
FROM invoices AS i
JOIN invoice_items AS ii 
      ON i.InvoiceNo = ii.InvoiceNo
JOIN products AS p      
      ON ii.StockCode = p.StockCode
LEFT JOIN customers AS c 
      ON i.CustomerID = c.CustomerID;

-- Example usage of v_invoice_details
SELECT *
FROM v_invoice_details
LIMIT 20;


-------------------------------------------------------------------
-- SECTION 7: INDEXES & SIMPLE OPTIMISATION
-------------------------------------------------------------------

-- 7.1 Indexes on common join/filter columns
CREATE INDEX IF NOT EXISTS idx_invoices_customer
    ON invoices(CustomerID);

CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice
    ON invoice_items(InvoiceNo);

CREATE INDEX IF NOT EXISTS idx_invoice_items_stock
    ON invoice_items(StockCode);

CREATE INDEX IF NOT EXISTS idx_customers_country
    ON customers(Country);

-- 7.2 Example query plan to show index usage (for documentation)
EXPLAIN QUERY PLAN
SELECT *
FROM invoices AS i
JOIN invoice_items AS ii
      ON i.InvoiceNo = ii.InvoiceNo
WHERE i.CustomerID = 17850;

-------------------------------------------------------------------
-- END OF SCRIPT
-------------------------------------------------------------------
