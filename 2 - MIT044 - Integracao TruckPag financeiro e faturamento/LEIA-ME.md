# Entrega — Integração TruckPag: financeiro e faturamento (MIT044, Cenário 2)

Guerra Implementos Rodoviários / TransVale (TFDRPC) · projeto TOTVS D0000083293 · MIT044 de 09/10/2026.

> **Situação em 03/11/2026: preparada, não enviada, sem aceite.** Nada foi instalado no ambiente da
> TransVale: o acesso ainda não foi liberado. Tudo foi desenvolvido e testado na nossa base de teste
> (Protheus 12.1.2510, PostgreSQL, empresa 99) em 24/10/2026. A instalação será feita por nós quando o
> acesso for liberado, seguindo a GMUD. A validação de vocês começa depois disso.
>
> **A escolha do Cenário 2 ainda depende da P-01.** Se a decisão for o Cenário 1, muda só a entrada
> (tela de importação no lugar das chamadas REST); as peças do financeiro e as tabelas servem igual.


## Como o zip está organizado

| Pasta do zip | O que tem |
|---|---|
| raiz | este LEIA-ME e o roteiro de validação e aceite |
| `1 - GMUD` | instalação técnica e reversão |
| `2 - Artefatos (fontes)` | os fontes (a pasta `Fontes` citada abaixo) e o manifesto com o SHA-256 de cada um |
| `3 - Manual de utilizacao` | como usar |
| `4 - Evidencia de teste` | relatório de teste e imagens |

## Arquivos

| Arquivo | O que é |
|---|---|
| `Relatorio de teste - Integracao TruckPag financeiro e faturamento.html` | relatório dos testes na nossa base de teste: 21 testes, 20 aprovados e 1 aprovado com ressalva (teste 9: a fatura do transportador sai pela Liquidação, a rotina padrão que substituiu a antiga Faturas a Receber; valor e resultado iguais, muda a tela de consulta). Imagens embutidas |
| `GMUD - Integracao TruckPag financeiro e faturamento.html` | roteiro técnico de instalação: pré-requisitos, ordem (dicionário em janela exclusiva com o REST fora do ar, depois compilação, ajuste dos parâmetros e reinício do REST), dicionário criado, parâmetros com o valor proposto, o que fica "a confirmar na instalação" e a reversão |
| `UTILIZACAO - Integracao TruckPag financeiro e faturamento.html` | manual de uso: é a "Prévia e Manual de Uso" revisão 1 de 25/10/2026, a mesma que vocês já receberam. Único ajuste: o link para o relatório de teste aponta para o arquivo desta pasta. Imagens embutidas |
| `Roteiro de validacao e aceite - Integracao TruckPag financeiro e faturamento.html` | o passo a passo para vocês validarem, em 7 etapas (conexão, inclusão em lote, reenvio sem duplicar, estorno, fatura do transportador, fatura do posto, baixas). Começa "não testado" e sem aceite. Faz também o papel de manual de teste: cada etapa traz o corpo da chamada, onde conferir no Protheus e o que tem que aparecer |
| `Manifesto dos fontes - Integracao TruckPag financeiro e faturamento.txt` | SHA-256 de cada arquivo de `Fontes/`, calculado em 03/11/2026 |
| `Fontes/` | cópia exata dos fontes da entrega: `fontes/ZTPG001.tlpp`, `fontes/ZTPG002.tlpp`, `fontes/ZTPG010.tlpp`, `dicionario/ATVTPG01.prw` (cp1252), `dicionario/ZTPGDIC.prw` e a especificação `dicionario/TVTPG01.json` |
| `Imagens/` | os 4 prints de Contas a Receber e Contas a Pagar usados no relatório e nos exemplos do roteiro (os documentos já levam as imagens dentro do próprio HTML) |

**Como validar:** os testes dependem da instalação no ambiente de vocês e de um cliente REST
(Postman ou o próprio Sistema Gestão). Abra o roteiro, siga as etapas na ordem e, em cada uma, marque
como foi. Se precisar, cole prints e escreva observações no próprio documento; no fim, clique em
"Baixar preenchimento" e nos devolva o arquivo. Se preferir, pode responder por mensagem dizendo se a
entrega está aprovada ou quais pontos precisam de ajuste.

## Entregue nesta versão

| O quê | Situação |
|---|---|
| API 01 · inclusão das transações em lote (conta a receber do transportador e a pagar ao posto, achados pelo CNPJ; item com erro volta com o motivo e não grava) | pronta e testada na nossa base de teste |
| API 02 · estorno (crédito ao transportador e débito ao posto, ligados à transação original, que continua lá) | pronta e testada |
| API 03 · fatura do transportador (crédito do estorno compensado antes; fatura de parcela única pela Liquidação) | pronta e testada, com a ressalva do teste 9 |
| API 04 · fatura do posto (débito do estorno abatido) | pronta e testada |
| APIs 06 e 07 · baixa das faturas com movimento no banco | prontas e testadas |
| Reenvio sem duplicar e recusa de pedido conflitante, em todas as APIs acima | testado (lote de 100 com queda no meio e reenvio incluído) |
| Dicionário: tabelas ZB0 a ZB4, 64 campos, 13 índices, 19 parâmetros | aplicado na nossa base de teste |

Os nomes técnicos (fontes `ZTPG*`, tabelas `ZB0` a `ZB4`, parâmetros `MV_ZB*`, prefixos `TPG`/`TPF`)
são provisórios até o padrão de nomes do projeto ser definido com a TOTVS.

## Ainda não entregue e por quê

| O quê | Por quê |
|---|---|
| API 08 · nota de serviço do mês | só a viabilidade foi provada (nota de R$ 84,00 com ISS e nenhuma conta a receber, não transmitida). Falta o município e o código de serviço da TruckPag e definir a transmissão da nota de serviço |
| API 05 · negociação de dívida | fora desta etapa: não há definição de como o Sistema Gestão a usa |
| Prova no ambiente da TransVale | sem acesso ao ambiente até 03/11/2026. Release, banco, configuração do REST e cadastros de vocês ainda não foram vistos: a GMUD marca esses pontos como "a confirmar na instalação" |

**Decisões em aberto, com a nossa proposta:**

- **P-01** · Cenário 2 (esta integração por API) ou Cenário 1 (tela de importação). Proposta: Cenário 2.
- **P-04** · a fatura de cada fechamento vence numa data só. Proposta: parcela única, vencimento pela condição do cadastro.
- **P-06** · resposta item a item e reenvio. Proposta: HTTP 200 item a item com o número da transação; reenvio igual devolve os mesmos números; mesmo número com outro conteúdo é recusado. Ligado ao tamanho do lote (P-07: proposta de até 100 transações por chamada).
- **P-15** · estorno que chega depois de a transação ser faturada ou paga. Proposta: o crédito fica em aberto para a próxima fatura; fechamento que daria zero ou negativo não gera fatura.

**Materiais que precisamos receber:**

- **P-02** · o contrato da integração (`integracao-contabilidade.md`), a MIT041 TruckPag V02, a MIT044 V01 (Cenário 1) e as páginas 14 a 16 da MIT044.
- **P-10** · do contador: contas e lançamentos padrão da inclusão e da nota.
- **P-14** · quem faz e quando a carga dos transportadores (clientes) e postos (fornecedores) com CNPJ.

## O que a integração não faz

- Não tem tela própria no Protheus: quem chama é o Sistema Gestão; o financeiro confere nas telas padrão de Contas a Receber e Contas a Pagar. O erro de um item volta na resposta ao Sistema Gestão.
- Não cadastra transportador nem posto: transação de quem não está cadastrado volta com o motivo e não grava.
- Não apaga a transação errada: o estorno lança ao contrário e a original continua no Protheus.
- Não desfaz fatura já paga por causa de um estorno posterior (proposta P-15).
- Baixa sempre a fatura inteira, no banco definido por parâmetro.
- Não emite boleto, não gera remessa ou retorno bancário e não concilia extrato.
- Tirar a integração do ar não desfaz o que já foi lançado no financeiro: isso se desfaz pelas rotinas padrão.
