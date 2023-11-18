#! /usr/bin/env bash

ssh 10.0.1.6 -i /secrets/todo "cd ~/compose/todo && docker compose pull && docker compose up -d && docker image prune -af"
ssh 10.0.1.7 -i /secrets/todo2 "cd ~/compose/todo && docker compose pull && docker compose up -d && docker image prune -af"
