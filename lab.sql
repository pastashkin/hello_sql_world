#Запускаем контейнер
CREATE TABLE Department (
	id INT PRIMARY KEY,
	name VARCHAR NOT NULL
);

CREATE TABLE Employee (
	id INT PRIMARY KEY,
	department_id INTEGER NOT NULL,
	chief_doc_id INTEGER NOT NULL,
	name VARCHAR,
	num_public INTEGER,
	FOREIGN KEY (department_id) REFERENCES Department (id)
);

#Наполняем таблицы
INSERT INTO Department (id, name) 
VALUES	('1', 'Therapy'),
		('2', 'Neurology'),
		('3', 'Cardiology'),
		('4', 'Gastroenterology'),
		('5', 'Hematology'),
		('6', 'Oncology');

INSERT INTO Employee (id, department_id, chief_doc_id, name, num_public) 
VALUES	('1', '1', '1', 'Kate', 4),
		('2', '1', '1', 'Lidia', 2),
		('3', '1', '1', 'Alexey', 1),
		('4', '1', '2', 'Pier', 7),
		('5', '1', '2', 'Aurel', 6),
		('6', '1', '2', 'Klaudia', 1),
		('7', '2', '3', 'Klaus', 12),
		('8', '2', '3', 'Maria', 11),
		('9', '2', '4', 'Kate', 10),
		('10', '3', '5', 'Peter', 8),
		('11', '3', '5', 'Sergey', 9),
		('12', '3', '6', 'Olga', 12),
		('13', '3', '6', 'Maria', 14),
		('14', '4', '7', 'Irina', 2),
		('15', '4', '7', 'Grit', 10),
		('16', '4', '7', 'Vanessa', 16),
		('17', '5', '8', 'Sascha', 21),
		('18', '5', '8', 'Ben', 22),
		('19', '6', '9', 'Jessy', 19),
		('20', '6', '9', 'Ann', 18);

#Пишем запросы
#Вывести список названий департаментов и количество главных врачей в каждом из этих департаментов
WITH chief_counter AS
	(SELECT department_id, COUNT(DISTINCT chief_doc_id) AS chiefs FROM Employee GROUP BY department_id)
SELECT d.name AS department, c.chiefs FROM chief_counter c INNER JOIN Department d ON d.id = c.department_id;

#Вывести список департамент id в которых работаю 3 и более сотрудника
SELECT department_id FROM
	(SELECT department_id, COUNT(DISTINCT id) AS emp_qnt FROM Employee GROUP BY department_id) AS emp
WHERE emp_qnt >=3;

#Вывести список департамент id с максимальным количеством публикаций
WITH top_pubs AS
	(SELECT department_id, SUM(num_public) AS total_pubs FROM Employee GROUP BY department_id ORDER BY total_pubs DESC)
SELECT department_id FROM top_pubs WHERE total_pubs = (SELECT total_pubs FROM top_pubs LIMIT 1);

#Вывести список имен сотрудников и департаментов с минимальным количеством ПУБЛИКАЦИЙ в своем департаментe
WITH pubs_rating AS 
(
	SELECT 
		department_id,
		name,
		total_pubs,
		ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY total_pubs) AS rating
	FROM 
	(
		SELECT 
			department_id,
			name,
			SUM(num_public) AS total_pubs
		FROM Employee GROUP BY department_id, name ORDER BY department_id, total_pubs
	) AS list
)
SELECT r.name AS Employee, d.name AS Department FROM pubs_rating r INNER JOIN Department d ON r.department_id = d.id WHERE rating = 1; 

#Вывести список названий департаментов и среднее количество публикаций для тех департаментов, в которых работает более одного главного врача
WITH sample AS 
(
	WITH 
	dep_chiefs AS 
	(
		SELECT 
			department_id,
			COUNT(DISTINCT chief_doc_id) AS chiefs
		FROM Employee GROUP BY department_id
	),
	dep_avg_pubs AS
	(
		SELECT 
			department_id,
			AVG(num_public) AS avg_pubs
		FROM Employee GROUP BY department_id ORDER BY department_id, avg_pubs
	)
	SELECT c.department_id, a.avg_pubs FROM dep_chiefs c INNER JOIN dep_avg_pubs a ON c.department_id = a.department_id WHERE c.chiefs > 1
)
SELECT d.name AS Department, s.avg_pubs AS Averege_pubs FROM department d INNER JOIN sample s ON s.department_id = d.id;