#!/bin/bash
# filepath: ./rabbitmq-init.sh

# Espera o RabbitMQ subir
sleep 10

# Cria usuário, define como admin e dá permissões
rabbitmqctl add_user connectsports C0nn3ct_Sp0rts_P4ss
rabbitmqctl set_user_tags connectsports administrator
rabbitmqctl set_permissions -p / connectsports ".*" ".*" ".*"