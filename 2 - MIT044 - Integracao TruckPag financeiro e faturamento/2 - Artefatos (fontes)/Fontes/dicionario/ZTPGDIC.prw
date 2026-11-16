#include "protheus.ch"

/*/{Protheus.doc} ZTPGDIC
Roda o aplicador de dicionario do TruckPag (ATVTPG01) sem tela de selecao, na empresa 99 filial 01
da base de teste. Programa inicial do webapp: U_ZTPGDIC (modo exclusivo, REST fora do ar).
@type function
@author TOTVS (projeto TruckPag)
@since 24/10/2026
/*/
User Function ZTPGDIC()
    U_ATVTPG01("99", "01")
Return Nil
