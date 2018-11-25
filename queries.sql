# Создаем основу БД
	CREATE TABLE skus (
		sku_id INTEGER NOT NULL,
		sku_name VARCHAR(90) NOT NULL,
		sku_brand VARCHAR(90) NOT NULL,
		PRIMARY KEY (sku_id)
	);

	CREATE TABLE calendars (
		dt DATE NOT NULL,
		dt_weekday VARCHAR(3) NOT NULL,
		wrhs_open BOOLEAN NOT NULL,
		PRIMARY KEY (dt)
	);

	CREATE TABLE customers (
		customer_id INTEGER NOT NULL,
		customer_name VARCHAR(90) NOT NULL,
		customer_region VARCHAR(90) NOT NULL,
		PRIMARY KEY (customer_id)
	);

	CREATE TABLE prices (
		dt DATE NOT NULL REFERENCES calendars(dt),
		sku_id INTEGER NOT NULL REFERENCES skus(sku_id),
		price NUMERIC NOT NULL,
		PRIMARY KEY (sku_id,dt)
	);

	CREATE TABLE sales (
		dt DATE NOT NULL REFERENCES calendars(dt),
		sku_id INTEGER NOT NULL REFERENCES skus(sku_id),
		customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
		wrhs_name VARCHAR(90) NOT NULL,
		qnt INTEGER NOT NULL
	);

# Наполняем:

	\copy skus FROM '/data/tables/skus.csv' DELIMITER ';' CSV HEADER
	\copy calendars FROM '/data/tables/calendars.csv' DELIMITER ';' CSV HEADER
	\copy prices FROM '/data/tables/prices.csv' DELIMITER ';' CSV HEADER
	\copy customers FROM '/data/tables/customers.csv' DELIMITER ';' CSV HEADER
	\copy sales FROM '/data/tables/sales.csv' DELIMITER ';' CSV HEADER

# Запросы к БД:
# Соединим таблицы sales, skus, customers:

	SELECT 
		sa.dt,
		sk.sku_name,
		sk.sku_brand,
		cu.customer_name,
		cu.customer_region,
		sa.wrhs_name,
		sa.qnt 
	FROM sales sa 
	JOIN skus sk ON sa.sku_id = sk.sku_id 
	JOIN customers cu ON cu.customer_id = sa.customer_id LIMIT 10;

# Создадим хранимую процедуру, которая будет выводить стоимость транзакции в рублях:

	CREATE OR REPLACE FUNCTION qnt_price (dt DATE, sku_id INTEGER, qnt NUMERIC) RETURNS NUMERIC language sql AS $FUNCTION$
		SELECT $3 * (SELECT price FROM prices WHERE dt = $1 AND sku_id = $2) AS qnt_price;
	$FUNCTION$;

# Проверим ее работу:

	SELECT 
		sa.dt,
		sk.sku_name,
		sk.sku_brand,
		cu.customer_name,
		cu.customer_region,
		sa.wrhs_name,
		sa.qnt,
		ROUND(qnt_price(sa.dt, sa.sku_id, sa.qnt), 2) AS price 
	FROM sales sa 
	JOIN skus sk ON sa.sku_id = sk.sku_id 
	JOIN customers cu ON cu.customer_id = sa.customer_id LIMIT 10;

# Найдем топ-10 контрагентов по продажам за январь:

	SELECT 
		DISTINCT cu.customer_name,
		ROUND(SUM(qnt_price(sa.dt, sa.sku_id, sa.qnt)) OVER (PARTITION BY sa.customer_id), 2) AS total_sales
	FROM sales sa 
	JOIN skus sk ON sa.sku_id = sk.sku_id 
	JOIN customers cu ON cu.customer_id = sa.customer_id
	WHERE sa.dt >= '2018-01-01' AND sa.dt <= '2018-01-31'
	ORDER BY total_sales DESC
	LIMIT 10;

# Узнаем, какие бренды лучше всего продавались у этих контрагентов (составим топ по брендам у лучших контрагенов):

	WITH 
	top10_jan AS (
		SELECT 
			DISTINCT cu.customer_id,
			ROUND(SUM(qnt_price(sa.dt, sa.sku_id, sa.qnt)) OVER (PARTITION BY sa.customer_id), 2) AS total_sales
		FROM sales sa 
		JOIN skus sk ON sa.sku_id = sk.sku_id 
		JOIN customers cu ON cu.customer_id = sa.customer_id
		WHERE sa.dt >= '2018-01-01' AND sa.dt <= '2018-01-31'
		ORDER BY total_sales DESC
		LIMIT 10),
	sample_jan AS (
		SELECT 
			sk.sku_brand,
			ROUND(qnt_price(sa.dt, sa.sku_id, sa.qnt), 2) AS total_sales
		FROM sales sa
		JOIN skus sk ON sa.sku_id = sk.sku_id
		WHERE 
			sa.customer_id IN (SELECT customer_id FROM top10_jan) AND dt >= '2018-01-01' AND dt <= '2018-01-31')

	SELECT 
		DISTINCT sku_brand,
		SUM(total_sales) OVER (PARTITION BY sku_brand) AS total
	FROM sample_jan ORDER BY total DESC;

# Вот и ответ. Среди топ-10 контрагентов по продажам в январе 2018 года лучше всего они продавали SKU под брендом ТопГир, на втором месте Марко:
# Создадим функцию поиска среднего значения закупки:
	
# Функция возвращает среднее значение продаж
	
	CREATE OR REPLACE FUNCTION sales_avg () RETURNS NUMERIC language sql AS $FUNCTION$
		SELECT 1 * (SELECT avg(qnt) FROM sales LIMIT 1) AS sales_avg;
	$FUNCTION$;

# Создадим новую таблицу sales_full:

	CREATE TABLE sales_full (
		dt DATE NOT NULL,
		sku_name VARCHAR(90) NOT NULL,
		sku_brand VARCHAR(90) NOT NULL,
		customer_name VARCHAR(90) NOT NULL,
		customer_region VARCHAR(90) NOT NULL,
		wrhs_name VARCHAR(90) NOT NULL,
		qnt INTEGER NOT NULL,
		price NUMERIC NOT NULL
	);

# Создаем две таблицы для оптовых и розничных закупок:

	CREATE TABLE sales_wholesale (
	    CHECK (qnt >= sales_avg())
	) INHERITS (sales_full);

	CREATE TABLE sales_retail (
	    CHECK (qnt < sales_avg())
	) INHERITS (sales_full);

# Создаем правила для наполнения этих таблиц:

	CREATE RULE sales_are_wholesale AS ON INSERT TO sales_full
	WHERE (qnt < sales_avg())
	DO INSTEAD INSERT INTO sales_retail VALUES ( NEW.* );

	CREATE RULE sales_are_retail AS ON INSERT TO sales_full
	WHERE (qnt >= sales_avg())
	DO INSTEAD INSERT INTO sales_wholesale VALUES ( NEW.* );

# Наполняем sales_full. 
# Получился довольно прожорливый до ресурсов запрос - на моей машине его выполнение займет около 25 минут.
# Было решено ограничить запрос первой неделей января (~35 секунд):

	INSERT INTO sales_full (
		SELECT 
			sa.dt,
			sk.sku_name,
			sk.sku_brand,
			cu.customer_name,
			cu.customer_region,
			sa.wrhs_name,
			sa.qnt,
			ROUND(qnt_price(sa.dt, sa.sku_id, sa.qnt), 2) AS price 

		FROM sales sa 
		JOIN skus sk ON sa.sku_id = sk.sku_id 
		JOIN customers cu ON cu.customer_id = sa.customer_id
		WHERE sa.dt >= '2018-01-01' AND sa.dt <= '2018-01-07');

# Посчитаем средние значения в рублях наших оптовых и розничных продаж:
	
	(
	SELECT 
		'wholesale' AS sale_type,
		ROUND(AVG(price), 2) AS price
	FROM sales_wholesale LIMIT 1
	) UNION ALL 
	(
	SELECT 
		'ratail' AS sale_type,
		ROUND(AVG(price), 2) AS price
	FROM sales_retail LIMIT 1
	);

# В нашем календаре есть отметка о графике работы склада.
# Далее работать будем с таблицей sales_full.
# Узнаем сколько оптовых отгрузок пришлось на дни, когда склад был закрыт (значение calendars.wrhs_open = False)

	SELECT COUNT(*) AS sales_when_wrhs_is_closed FROM sales_wholesale sa JOIN calendars ca ON sa.dt = ca.dt WHERE ca.wrhs_open IS False;

# И сколько всего было оптовых закупок в этот период:

	SELECT COUNT(*) AS sales_total FROM sales_wholesale;

# Ого, почти 84% отгрузок были совершены, когда склад был закрыт - плохо.

# Попробуем узнать на какие дни недели приходится больше всего оптовых закупок и дадим рекомендации складу по графику работы.
# Для этого сформируем запрос к первоначальному отчету дистрибьюторов (таблица sales):

	WITH wholesale_sales AS (
		SELECT * FROM sales WHERE qnt >= 28)
	
	SELECT 
		DISTINCT ca.dt_weekday,
		SUM(sa.qnt) OVER (PARTITION BY ca.dt_weekday)
	FROM wholesale_sales sa JOIN calendars ca ON sa.dt = ca.dt;

# Как видим из выгрузки, складу лучше отыхать по субботам и воскресеньям.

# Выведем топ-10 регионов по розничным продажам в рублях из таблицы sales:	
	
	WITH retail_sales AS (
		SELECT 
			dt,
			sku_id,
			customer_id,
			wrhs_name,
			qnt,
			qnt_price(dt, sku_id, qnt) AS price 
		FROM sales WHERE qnt < 28)
	
	SELECT 
		DISTINCT cu.customer_region,
		ROUND(SUM (sa.price), 0) AS region_sum
	FROM retail_sales sa
	JOIN customers cu ON cu.customer_id = sa.customer_id
	GROUP BY cu.customer_region
	ORDER BY region_sum DESC
	LIMIT 10;

# Посчитаем среднюю продажу в рублях на одного контрагента в разрезе дней продаж:
	
	SELECT 
		dt,
		ROUND(SUM(price) / COUNT(customer_id), 2) AS sales_per_customer 
	FROM
	(
		SELECT 
			sa.dt,
			cu.customer_id,
			ROUND(qnt_price(sa.dt, sa.sku_id, sa.qnt), 2) AS price 
		FROM sales sa 
		JOIN skus sk ON sa.sku_id = sk.sku_id 
		JOIN customers cu ON cu.customer_id = sa.customer_id
	) AS sample
	GROUP BY dt
	ORDER BY dt
	LIMIT 10;

# На этом все.
