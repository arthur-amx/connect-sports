# Usa uma imagem base oficial do Node.js (LTS)
FROM node:18-alpine

# Defina o diretório de trabalho dentro do container
WORKDIR /usr/src/app

# Copia os arquivos de definição de dependências
COPY package*.json ./

# Instala as dependências do projeto
RUN npm install

# Copia o restante do código da aplicação para o diretório de trabalho
COPY . .

# Expõe a porta que sua aplicação usa (definida no .env ou 3000 por padrão)
EXPOSE ${PORT:-3000}
EXPOSE 9229

# Comando padrão para iniciar a aplicação
# CMD [ "node", "server.js", "debug"]
CMD ["npm", "run", "debug"]