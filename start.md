Привет!
Ниже описание моего первого мини-проекта по docker и postgresql

	git add .
	git commit -m "readme"
	git push -u https://github.com/pastashkin/hello_sql_world.git master


Для работы нам потребуются:
1. Убунта (у меня Ubuntu 18.04.1 LTS)
2. Docker и docker-compose (у меня 18.06.1-ce и 1.17.1)

Лично у меня, в ходе обучения, набралось огромное количество контейнеров и образов. 
Первым делом решиль почистить докер.
ВАЖНО: Не выполняй эти команды, если у тебя все настроено.
Эти команды нужны только мне, чтобы убедиться, что я нормально развернул контейнеры

Останавливаем и удаляем все контейнеры, а затем и образы

	sudo docker stop $(sudo docker ps -aq)
	sudo docker rm $(sudo docker ps -aq)
    sudo docker rmi $(sudo docker images -aq) -f

Поехали!
Первым делом клонируем мой репозиторий:
    
	sudo git clone https://github.com/pastashkin/hello_sql_world.git

У меня он клонируется в /home/data)hello_sql_world 
Далее будем работать именно с этой директорией

Переходим в директория с файлами докера:

	cd /home/data/hello_sql_world/docker-compose

Перед сборкой контейнера протянем наши папки внутрь контейнера.
Для этого изменим файл docker-compose.yml:

    volumes:
      - /home/data/hello_sql_world:/data

Теперь собираем

	sudo docker-compose --project-name hellosql -f docker-compose.yml up --build -d

И запускаем контейнер
    
	sudo docker-compose --project-name hellosql -f docker-compose.yml run --rm ubuntu

Если все прошло удачно, мы попадаем в кмандную строку убунты
Из нее запускаем postgres. 
User: postgres Password: postgres
    
	psql --host $POSTGRES_HOST -U postgres

Отлично!
Теперь нам нужно создать и наполнить наши таблицы.
Создаем:

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

Наполняем:

	\copy skus FROM '/data/tables/skus.csv' DELIMITER ';' CSV HEADER
	\copy calendars FROM '/data/tables/calendars.csv' DELIMITER ';' CSV HEADER
	\copy prices FROM '/data/tables/prices.csv' DELIMITER ';' CSV HEADER
	\copy customers FROM '/data/tables/customers.csv' DELIMITER ';' CSV HEADER
	\copy sales FROM '/data/tables/sales.csv' DELIMITER ';' CSV HEADER

Запросы к БД:

	SELECT sa.dt, sk.sku_name, sk.sku_brand, sa.customer_id, sa.wrhs_name, sa.qnt FROM sales sa JOIN skus sk ON sa.sku_id = sk.sku_id LIMIT 10;
