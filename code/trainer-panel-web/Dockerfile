# Estágio 1: Servidor Web com Nginx
FROM nginx:1.25-alpine

# Remove a configuração padrão do Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copia a nossa configuração customizada do Nginx para o container
COPY nginx.conf /etc/nginx/conf.d/

# Copia os arquivos estáticos do nosso painel (HTML, CSS, JS)
# para o diretório que o Nginx usa para servir arquivos
COPY . /usr/share/nginx/html