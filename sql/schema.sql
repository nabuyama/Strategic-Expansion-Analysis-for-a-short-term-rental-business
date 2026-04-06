-- Airbnb Analytics Database Setup
-- This script initializes the database and core tables

CREATE DATABASE airbnb_analytics;


CREATE TABLE public.revenue (
    visit_id INT PRIMARY KEY,
    
    year INT,
    month INT,
    
    pay_from DATE,
    pay_to DATE,
    
    amount_ugx NUMERIC(12,2),

    platform VARCHAR(50),
    
    is_extended_booking BOOLEAN,
    
    booking_duration INT,

    client_name VARCHAR(50),
    client_id VARCHAR(50)  
);

DROP TABLE revenue

CREATE TABLE public.expenses (
    expense_id INT PRIMARY KEY,
    
    expense_date DATE,
    
    expense VARCHAR(100),
    expense_category VARCHAR(50),
    
    amount_ugx NUMERIC(12,2)
);

-- Set ownership of the tables to the postgres user
ALTER TABLE public.revenue OWNER to postgres;
ALTER TABLE public.expenses OWNER to postgres;
