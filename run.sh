#!/bin/bash
STACK_NAME="backup"
mkdir -p BACKUP
docker stack rm ${STACK_NAME};
sleep 5;
docker stack deploy --compose-file=docker-compose.yml ${STACK_NAME};
sleep 5;
docker stack rm ${STACK_NAME};
docker stack rm ${STACK_NAME};
docker stack deploy --compose-file=docker-compose.yml ${STACK_NAME};
docker ps | grep '${STACK_NAME}'