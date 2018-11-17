# как запускать контейнер
# sudo docker-compose --project-name data-cli -f docker-compose.yml up --build -d
# sudo docker-compose --project-name data-cli -f docker-compose.yml run --rm data-client

FROM continuumio/miniconda3

ENTRYPOINT ["/bin/bash"]

# для корректной версии psql
RUN apt-get update &&  apt-get -y install sudo gnupg2

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

RUN apt-get update && apt-get install -y  postgresql-client-10

