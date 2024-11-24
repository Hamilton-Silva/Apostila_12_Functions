-- Criação das tabelas necessárias para a realização das tarefas
CREATE TABLE tb_cliente(
cod_cliente SERIAL PRIMARY KEY,
nome VARCHAR(200) NOT NULL
);
INSERT INTO tb_cliente (nome) VALUES ('João Santos'), ('Maria Andrade');
SELECT * FROM tb_cliente;
CREATE TABLE tb_tipo_conta(
cod_tipo_conta SERIAL PRIMARY KEY,
descricao VARCHAR(200) NOT NULL
);
INSERT INTO tb_tipo_conta (descricao) VALUES ('Conta Corrente'), ('Conta Poupança');
SELECT * FROM tb_tipo_conta;
CREATE TABLE tb_conta (
cod_conta SERIAL PRIMARY KEY,
status VARCHAR(200) NOT NULL DEFAULT 'aberta',
data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
data_ultima_transacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
saldo NUMERIC(10, 2) NOT NULL DEFAULT 1000 CHECK (saldo >= 1000),
cod_cliente INT NOT NULL,
cod_tipo_conta INT NOT NULL,
CONSTRAINT fk_cliente FOREIGN KEY (cod_cliente) REFERENCES
tb_cliente(cod_cliente),
CONSTRAINT fk_tipo_conta FOREIGN KEY (cod_tipo_conta) REFERENCES
tb_tipo_conta(cod_tipo_conta)
);
SELECT * FROM tb_conta

DROP FUNCTION IF EXISTS fn_abrir_conta;
CREATE OR REPLACE FUNCTION fn_abrir_conta (IN p_cod_cli INT, IN p_saldo
NUMERIC(10, 2), IN p_cod_tipo_conta INT) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
INSERT INTO tb_conta (cod_cliente, saldo, cod_tipo_conta) VALUES ($1, $2, $3);
RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
RETURN FALSE;
END;
$$
DO $$
DECLARE
v_cod_cliente INT := 1;
v_saldo NUMERIC (10, 2) := 500;
v_cod_tipo_conta INT := 1;
v_resultado BOOLEAN;
BEGIN
SELECT fn_abrir_conta (v_cod_cliente, v_saldo, v_cod_tipo_conta) INTO
v_resultado;
RAISE NOTICE '%', format('Conta com saldo R$%s%s foi aberta', v_saldo, CASE
WHEN v_resultado THEN '' ELSE ' não' END);
v_saldo := 1000;
SELECT fn_abrir_conta (v_cod_cliente, v_saldo, v_cod_tipo_conta) INTO
v_resultado;
RAISE NOTICE '%', format('Conta com saldo R$%s%s foi aberta', v_saldo, CASE
WHEN v_resultado THEN '' ELSE ' não' END);
END;
$$

--routine se aplica a funções e procedimentos
DROP ROUTINE IF EXISTS fn_depositar;
CREATE OR REPLACE FUNCTION fn_depositar (IN p_cod_cliente INT, IN p_cod_conta INT,
IN p_valor NUMERIC(10, 2)) RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
v_saldo_resultante NUMERIC(10, 2);
BEGIN
UPDATE tb_conta SET saldo = saldo + p_valor WHERE cod_cliente = p_cod_cliente
AND cod_conta = p_cod_conta;
SELECT saldo FROM tb_conta c WHERE c.cod_cliente = p_cod_cliente AND
c.cod_conta = p_cod_conta INTO v_saldo_resultante;
RETURN v_saldo_resultante;
END;
$$
DO $$
DECLARE
v_cod_cliente INT := 1;
v_cod_conta INT := 2;
v_valor NUMERIC(10, 2) := 200;
v_saldo_resultante NUMERIC (10, 2);
BEGIN
SELECT fn_depositar (v_cod_cliente, v_cod_conta, v_valor) INTO
v_saldo_resultante;
RAISE NOTICE '%', format('Após depositar R$%s, o saldo resultante é de R$%s',
v_valor, v_saldo_resultante);
END;
$$;

-- Exercício 1.1 da Apostila 12
DROP FUNCTION IF EXISTS fn_consultar_saldo;

CREATE OR REPLACE FUNCTION fn_consultar_saldo (
    IN p_cod_cliente INT, 
    IN p_cod_conta INT
) RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_saldo NUMERIC(10, 2);
BEGIN
    -- Consulta o saldo de uma conta especificada
    SELECT saldo 
    INTO v_saldo
    FROM tb_conta
    WHERE cod_cliente = p_cod_cliente
    AND cod_conta = p_cod_conta;

    -- Caso a conta não exista, o saldo deve ser NULL
    RETURN v_saldo;
EXCEPTION WHEN OTHERS THEN
    -- E, em caso de erro, retorna NULL
    RETURN NULL;
END;
$$;

-- Exercício 1.2 da Apostila 12
DROP FUNCTION IF EXISTS fn_transferir;

CREATE OR REPLACE FUNCTION fn_transferir (
    IN p_cod_cliente_remetente INT,
    IN p_cod_conta_remetente INT,
    IN p_cod_cliente_destinatario INT,
    IN p_cod_conta_destinatario INT,
    IN p_valor NUMERIC(10, 2)
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_saldo_remetente NUMERIC(10, 2);
    v_saldo_destinatario NUMERIC(10, 2);
BEGIN
    -- Consulta o saldo da conta do remetente
    SELECT saldo
    INTO v_saldo_remetente
    FROM tb_conta
    WHERE cod_cliente = p_cod_cliente_remetente
    AND cod_conta = p_cod_conta_remetente;

    -- Consulta o saldo da conta do destinatário
    SELECT saldo
    INTO v_saldo_destinatario
    FROM tb_conta
    WHERE cod_cliente = p_cod_cliente_destinatario
    AND cod_conta = p_cod_conta_destinatario;

    -- Verifica se o saldo do remetente é suficiente
    IF v_saldo_remetente < p_valor THEN
        RAISE NOTICE 'Saldo insuficiente para a transferência.';
        RETURN FALSE;
    END IF;

    -- Verifica se a conta do destinatário não irá ficar negativa
    IF v_saldo_destinatario + p_valor < 0 THEN
        RAISE NOTICE 'A conta destinatária se torna negativa.';
        RETURN FALSE;
    END IF;

    -- Aqui ocorre o ínicio da transferência e, em seguida, atualiza o saldo da conta do remetente
    
    UPDATE tb_conta
    SET saldo = saldo - p_valor
    WHERE cod_cliente = p_cod_cliente_remetente
    AND cod_conta = p_cod_conta_remetente;

    -- Atualiza o saldo da conta do destinatário
    UPDATE tb_conta
    SET saldo = saldo + p_valor
    WHERE cod_cliente = p_cod_cliente_destinatario
    AND cod_conta = p_cod_conta_destinatario;

    -- Caso a execução do código alcance este trecho do script, a transferência foi bem-sucedida
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    -- Por fim, caso ocorra qualquer erro, deve retornar FALSE
    RAISE NOTICE 'Erro ao tentar realizar a transferência.';
    RETURN FALSE;
END;
$$;

-- Exercício 1.3 da Apostila 12
DO $$
DECLARE
    v_cod_cliente_remetente INT := 1;  
    v_cod_conta_remetente INT := 1;    
    v_cod_cliente_destinatario INT := 2;  
    v_cod_conta_destinatario INT := 2; 
    v_valor NUMERIC(10, 2) := 57;     
    v_transferencia_sucesso BOOLEAN;    
BEGIN
    -- Chamado da função fn_transferir para a efetiva realização da transferência
    v_transferencia_sucesso := fn_transferir(v_cod_cliente_remetente, v_cod_conta_remetente,
                                              v_cod_cliente_destinatario, v_cod_conta_destinatario, v_valor);

    -- Exibição do resultado da transferência
    IF v_transferencia_sucesso THEN
        RAISE NOTICE 'Transferência de R$% para a conta % do cliente % foi bem-sucedida.',
            v_valor, v_cod_conta_destinatario, v_cod_cliente_destinatario;
    ELSE
        RAISE NOTICE 'Transferência de R$% falhou.', v_valor;
    END IF;
END;
$$;

