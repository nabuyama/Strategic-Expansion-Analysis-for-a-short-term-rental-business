-- Importing data

COPY revenue
FROM 'C:\Lz\DA portfolio\Airbnb performance analysis\csv\revenue.csv' --full file path
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ','
);

COPY expenses
FROM 'C:\Lz\DA portfolio\Airbnb performance analysis\csv\expenses.csv' --file path
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ','
);