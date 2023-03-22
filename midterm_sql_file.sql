# exporting dimension table data

# for film dimension table (exported as json):
SELECT * FROM sakila.film_category
LEFT JOIN sakila.category
ON film_category.category_id = category.category_id
RIGHT JOIN sakila.film
ON film_category.film_id = film.film_id
;

# for customer dimension table (exported as csv):
SELECT * FROM sakila.customer
LEFT JOIN sakila.address
ON customer.address_id=address.address_id;


# for staff dimension table (exported as csv):
SELECT * FROM sakila.staff
LEFT JOIN sakila.address
ON staff.address_id=address.address_id; 

# for date dimension table:

USE sakila_dw;

DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date(
 date_key int NOT NULL,
 full_date date NULL,
 date_name char(11) NOT NULL,
 date_name_us char(11) NOT NULL,
 date_name_eu char(11) NOT NULL,
 day_of_week tinyint NOT NULL,
 day_name_of_week char(10) NOT NULL,
 day_of_month tinyint NOT NULL,
 day_of_year smallint NOT NULL,
 weekday_weekend char(10) NOT NULL,
 week_of_year tinyint NOT NULL,
 month_name char(10) NOT NULL,
 month_of_year tinyint NOT NULL,
 is_last_day_of_month char(1) NOT NULL,
 calendar_quarter tinyint NOT NULL,
 calendar_year smallint NOT NULL,
 calendar_year_month char(10) NOT NULL,
 calendar_year_qtr char(10) NOT NULL,
 fiscal_month_of_year tinyint NOT NULL,
 fiscal_quarter tinyint NOT NULL,
 fiscal_year int NOT NULL,
 fiscal_year_month char(10) NOT NULL,
 fiscal_year_qtr char(10) NOT NULL,
  PRIMARY KEY (`date_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# Here is the PopulateDateDimension Stored Procedure: 
delimiter //

DROP PROCEDURE IF EXISTS PopulateDateDimension//
CREATE PROCEDURE PopulateDateDimension(BeginDate DATETIME, EndDate DATETIME)
BEGIN

	# =============================================
	# Description: http://arcanecode.com/2009/11/18/populating-a-kimball-date-dimension/
	# =============================================

	# A few notes, this code does nothing to the existing table, no deletes are triggered before hand.
    # Because the DateKey is uniquely indexed, it will simply produce errors if you attempt to insert duplicates.
	# You can however adjust the Begin/End dates and rerun to safely add new dates to the table every year.
	# If the begin date is after the end date, no errors occur but nothing happens as the while loop never executes.

	# Holds a flag so we can determine if the date is the last day of month
	DECLARE LastDayOfMon CHAR(1);

	# Number of months to add to the date to get the current Fiscal date
	DECLARE FiscalYearMonthsOffset INT;

	# These two counters are used in our loop.
	DECLARE DateCounter DATETIME;    #Current date in loop
	DECLARE FiscalCounter DATETIME;  #Fiscal Year Date in loop

	# Set this to the number of months to add to the current date to get the beginning of the Fiscal year.
    # For example, if the Fiscal year begins July 1, put a 6 there.
	# Negative values are also allowed, thus if your 2010 Fiscal year begins in July of 2009, put a -6.
	SET FiscalYearMonthsOffset = 6;

	# Start the counter at the begin date
	SET DateCounter = BeginDate;

	WHILE DateCounter <= EndDate DO
		# Calculate the current Fiscal date as an offset of the current date in the loop
		SET FiscalCounter = DATE_ADD(DateCounter, INTERVAL FiscalYearMonthsOffset MONTH);

		# Set value for IsLastDayOfMonth
		IF MONTH(DateCounter) = MONTH(DATE_ADD(DateCounter, INTERVAL 1 DAY)) THEN
			SET LastDayOfMon = 'N';
		ELSE
			SET LastDayOfMon = 'Y';
		END IF;

		# add a record into the date dimension table for this date
		INSERT INTO dim_date
			(date_key
			, full_date
			, date_name
			, date_name_us
			, date_name_eu
			, day_of_week
			, day_name_of_week
			, day_of_month
			, day_of_year
			, weekday_weekend
			, week_of_year
			, month_name
			, month_of_year
			, is_last_day_of_month
			, calendar_quarter
			, calendar_year
			, calendar_year_month
			, calendar_year_qtr
			, fiscal_month_of_year
			, fiscal_quarter
			, fiscal_year
			, fiscal_year_month
			, fiscal_year_qtr)
		VALUES  (
			( YEAR(DateCounter) * 10000 ) + ( MONTH(DateCounter) * 100 ) + DAY(DateCounter)  #DateKey
			, DateCounter #FullDate
			, CONCAT(CAST(YEAR(DateCounter) AS CHAR(4)),'/', DATE_FORMAT(DateCounter,'%m'),'/', DATE_FORMAT(DateCounter,'%d')) #DateName
			, CONCAT(DATE_FORMAT(DateCounter,'%m'),'/', DATE_FORMAT(DateCounter,'%d'),'/', CAST(YEAR(DateCounter) AS CHAR(4)))#DateNameUS
			, CONCAT(DATE_FORMAT(DateCounter,'%d'),'/', DATE_FORMAT(DateCounter,'%m'),'/', CAST(YEAR(DateCounter) AS CHAR(4)))#DateNameEU
			, DAYOFWEEK(DateCounter) #DayOfWeek
			, DAYNAME(DateCounter) #DayNameOfWeek
			, DAYOFMONTH(DateCounter) #DayOfMonth
			, DAYOFYEAR(DateCounter) #DayOfYear
			, CASE DAYNAME(DateCounter)
				WHEN 'Saturday' THEN 'Weekend'
				WHEN 'Sunday' THEN 'Weekend'
				ELSE 'Weekday'
			END #WeekdayWeekend
			, WEEKOFYEAR(DateCounter) #WeekOfYear
			, MONTHNAME(DateCounter) #MonthName
			, MONTH(DateCounter) #MonthOfYear
			, LastDayOfMon #IsLastDayOfMonth
			, QUARTER(DateCounter) #CalendarQuarter
			, YEAR(DateCounter) #CalendarYear
			, CONCAT(CAST(YEAR(DateCounter) AS CHAR(4)),'-',DATE_FORMAT(DateCounter,'%m')) #CalendarYearMonth
			, CONCAT(CAST(YEAR(DateCounter) AS CHAR(4)),'Q',QUARTER(DateCounter)) #CalendarYearQtr
			, MONTH(FiscalCounter) #[FiscalMonthOfYear]
			, QUARTER(FiscalCounter) #[FiscalQuarter]
			, YEAR(FiscalCounter) #[FiscalYear]
			, CONCAT(CAST(YEAR(FiscalCounter) AS CHAR(4)),'-',DATE_FORMAT(FiscalCounter,'%m')) #[FiscalYearMonth]
			, CONCAT(CAST(YEAR(FiscalCounter) AS CHAR(4)),'Q',QUARTER(FiscalCounter)) #[FiscalYearQtr]
		);
		# Increment the date counter for next pass thru the loop
		SET DateCounter = DATE_ADD(DateCounter, INTERVAL 1 DAY);
	END WHILE;
END//

CALL PopulateDateDimension('2000/01/01', '2008/12/31'); 

Select * from sakila_dw.dim_customers
where dim_customers.customer_key=518;

SELECT * FROM dim_date
LIMIT 20;

# data exploration:

# rentals is fact table (center where all other dim tables come out of)
	# keys: rental key (primary), film key (add in from inventory id table)
    #,customer key,employee key,
    # columns: rental date, return date, payment amount (from payment id), payment date
    # rental duration, rental rate, replacement cost

# dimension tables:

# films (film_actor, actor, film, category, film_text, film_category, language)
	# keys: film key (primary key that links to rentals)
    # columns: actor id (join from film_actor), first name, last name, film title, description,
    # release year, language (from language id), length,
    # special features, category id
# customers (address, city, country, payment, rental)
	# key: customer key
    # columns: address, city, country, store, first name, last name, email, active, create_date
# employees (staff, store, address, city, country,
	# key: employee key
    # columns: store, first name, last name, email, active, username, password
# date dimension



Select * from sakila.actor; # actor id
Select * from sakila.address; # address id, city id
Select * from sakila.category; # category id
Select * from sakila.city; # city id, country id
Select * from sakila.country; # country id
Select * from sakila.customer; # customer id, store id, address id
Select * from sakila.film; # film id, language id
Select * from sakila.film_actor; # actor id and film_id
Select * from sakila.film_category; # film id, category id
Select * from sakila.film_text; # has film id (everything is already in film)
Select * from sakila.inventory; # inventory id, film id, store id (links ids)
Select * from sakila.language; # language id
Select * from sakila.payment; # payment id, customer id, staff id, rental id
Select * from sakila.rental; # rental id, inventory id, customer id,  staff id
Select * from sakila.staff; # staff id, address id, store id
Select * from sakila.store; # store id, manager staff id, address id


