Привет!
Ниже описание моего первого пмини-проекта по docker и postgresql

Для работы нам потребуются:
1. Убунта (у меня Ubuntu 18.04.1 LTS)
2. Docker и docker-compose (у меня 18.06.1-ce и 1.17.1)

Лично у меня, в ходе обучения, набралось огромное количество контейнеров и образов. 
Первым делом решиль почистить докер.
ВАЖНО: Не выполняй эти команды, если у тебя все настроено.
Эти команды нужны только мне, чтобы убедиться, что я нормально развернул контейнеры

Останавливаем все контейнеры
sudo docker stop $(sudo docker ps -aq)
Удаляем все контейнеры
sudo docker rm $(sudo docker ps -aq)
Удаляем все образы
sudo docker rmi $(sudo docker images -aq) -f


Поехали!
Первым делом клонируем мой репозиторий:
sudo git clone https://github.com/pastashkin/hello_sql_world.git

У меня он клонируется в /home/data)hello_sql_world 
Далее будем работать именно с этой директорией

Переходим в директория с файлами докера:
cd /home/data/hello_sql_world/docker-compose

Перед сборкой контейнера протянем наши папки внутрь контейнера.
Для этого измений файл docker-compose.yml:

    volumes:
      - /home/data/hello_sql_world:/data

Теперь собираем
sudo docker-compose --project-name hellosql -f docker-compose.yml up --build -d
И запускаем контейнер
sudo docker-compose --project-name hellosql -f docker-compose.yml run --rm ubuntu


