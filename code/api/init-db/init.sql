-- Schema: Sistema de Gestão de Atletas e Treinadores

-- Tabela de usuários
DROP TABLE IF EXISTS usuarios CASCADE;
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    senha_hash VARCHAR(100) NOT NULL,
    telefone VARCHAR(20) NULL,
    cpf VARCHAR(14) UNIQUE NULL,
    data_nascimento DATE NULL,
    tipo_usuario INT NOT NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de esportes
DROP TABLE IF EXISTS esportes CASCADE;
CREATE TABLE IF NOT EXISTS esportes (
    id SERIAL PRIMARY KEY,
    nome_esporte VARCHAR(50) NOT NULL
);

-- Tabela de eventos
DROP TABLE IF EXISTS eventos CASCADE;
CREATE TABLE IF NOT EXISTS eventos (
    id SERIAL PRIMARY KEY,
    nome_evento VARCHAR(100) NOT NULL,
    tipo_evento INT NOT NULL,
    data_evento TIMESTAMP WITH TIME ZONE NOT NULL,
    descricao TEXT NULL,
    status_evento INT NOT NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    criado_por INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Tabela de convites para treinadores
DROP TABLE IF EXISTS treinador_convite CASCADE;
CREATE TABLE IF NOT EXISTS treinador_convite (
    id SERIAL PRIMARY KEY,
    id_treinador INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    convite VARCHAR(100) NOT NULL
);

-- Tabela de vínculo entre atletas e treinadores
DROP TABLE IF EXISTS atleta_treinador CASCADE;
CREATE TABLE IF NOT EXISTS atleta_treinador (
    id SERIAL PRIMARY KEY,
    id_atleta INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    id_treinador INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    CONSTRAINT unique_atleta_vinculo UNIQUE (id_atleta)
);

-- Tabela de inscrição de atletas em eventos
DROP TABLE IF EXISTS atleta_evento CASCADE;
CREATE TABLE IF NOT EXISTS atleta_evento (
    id SERIAL PRIMARY KEY,
    id_atleta INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    id_evento INT NOT NULL REFERENCES eventos(id) ON DELETE CASCADE
);

-- Tabela de fichas de acompanhamento
DROP TABLE IF EXISTS fichas CASCADE;
CREATE TABLE IF NOT EXISTS fichas (
    id SERIAL PRIMARY KEY,
    nome_ficha VARCHAR(100) NOT NULL,
    id_atleta INT REFERENCES usuarios(id) ON DELETE CASCADE,
    id_treinador INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    categoria INT NOT NULL, --1 leve, 2 intermediário, 3 avançado
    id_esporte INT NOT NULL REFERENCES esportes(id) ON DELETE CASCADE,
    data_ficha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    descricao TEXT NULL,
    status_ficha INT NOT NULL, --1 ativo, 2--iniciado, 3--finalizado
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    iniciado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    finalizado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de feedbacks enviados por atletas aos treinadores
DROP TABLE IF EXISTS feedbacks CASCADE;
CREATE TABLE IF NOT EXISTS feedbacks (
    id SERIAL PRIMARY KEY,
    id_atleta INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    id_treinador INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo_feedback INT NOT NULL,
    texto_feedback TEXT NOT NULL,
    data_envio TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status_feedback INT NOT NULL DEFAULT 0,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Inserts iniciais na tabela de esportes
INSERT INTO esportes (nome_esporte) VALUES
('Futebol'),
('Basquete'),
('Vôlei'),
('Tênis'),
('Natação'),
('Atletismo'),
('Handebol'),
('Beisebol'),
('Rugby'),
('Golfe'),
('Boxe'),
('Surfe'),
('Skate'),
('Ciclismo'),
('Esgrima');

-- Índices para otimização de consultas
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios (email);
CREATE INDEX IF NOT EXISTS idx_usuarios_cpf ON usuarios (cpf);
CREATE INDEX IF NOT EXISTS idx_esportes_id ON esportes (id);
CREATE INDEX IF NOT EXISTS idx_eventos_nome ON eventos (nome_evento);
CREATE INDEX IF NOT EXISTS idx_feedbacks_id_treinador ON feedbacks (id_treinador);
CREATE INDEX IF NOT EXISTS idx_feedbacks_id_atleta ON feedbacks (id_atleta);
CREATE INDEX IF NOT EXISTS idx_feedbacks_status ON feedbacks (status_feedback);