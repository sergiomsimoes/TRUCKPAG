#include "rwmake.ch"
#include "tbiconn.ch"
#include "topconn.ch" 
#include "fileio.ch"
#include "protheus.ch"
#include "totvs.ch" 
#include "fwfilter.ch"
#INCLUDE 'fwmvcdef.ch' // Obrigatorio esse include para MVC

/*=====================================================================================================================================*/
// Função principal do módulo chamada a partir do Menu.
/*=====================================================================================================================================*/
/*/{Protheus.doc} ULOGAPI
Função principal do módulo chamada a partir do Menu.
Tela de visualização dos LOG's de Integração
@type function
@version V 1.00
@author Leandro Massafera
@since 05/11/2026
/*/
User Function ULOGAPI()

    Private aRotina := MenuDef()
    Private cMark   := ""
    Private oBrowse
    
    oBrowse := FwMBrowse():NEW() // Instanciamento da Classe de Browse

    oBrowse:SetDataTable()
    oBrowse:SetProfileID('1')
    oBrowse:SetAlias('ZGL')
    oBrowse:SetDescription('Log de Processamentos API')
           
    oBrowse:Activate()   // Ativando a classe - obrigatorio
    oBrowse:DeActivate() // Desativando a classe

Return Nil


/*=====================================================================================================================================*/
/*/{Protheus.doc} MenuDef
Função para montar o Menu padrão
@type function
@version V 1.00
@author Leandro Massafera
@since 05/11/2026
@return array, Array com o menu
/*/
Static Function MenuDef()
/*=====================================================================================================================================*/
    Local aBotao := {}
    
    aAdd( aBotao, { "Visualizar", "VIEWDEF.CTBZGL_RDM", 0, 2, 0, NIL } )
    //aAdd( aBotao, { "Incluir"   , "VIEWDEF.CTBZGL_RDM", 0, 3, 0, NIL } )
    //aAdd( aBotao, { "Alterar"   , "VIEWDEF.CTBZGL_RDM", 0, 4, 0, NIL } )
    //aAdd( aBotao, { "Excluir"   , "VIEWDEF.CTBZGL_RDM", 0, 5, 0, NIL } )

Return aBotao


/*=====================================================================================================================================*/
/*/{Protheus.doc} ModelDef
Função para montar o Modelo de Dados
@type function
@version V 1.00
@author Leandro Massafera
@since 05/11/2026
@return object, Objeto de Modelo de Dados
/*/
Static Function ModelDef()
/*=====================================================================================================================================*/
    Local oModel
    Local oStr1 := FWFormStruct(1,'ZGL')
    
    oModel := MPFormModel():New('ZGLMODEL')
    oModel:SetDescription('Log de Processamentos API')
    
    oModel:AddFields('MASTERZGL',,oStr1)

    oModel:SetPrimaryKey({ 'ZGL_FILIAL', 'ZGL_CODREF' })

Return oModel


/*=====================================================================================================================================*/
/*/{Protheus.doc} ViewDef
Função para montagem de View dos dados
@type function
@version V 1.00
@author Leandro Massafera
@since 05/11/2026
@return object, Objeto de View de Dados
/*/
Static Function ViewDef()
/*=====================================================================================================================================*/
    Local oView
    Local oModel := ModelDef()
    Local oStr1  := FWFormStruct(2, 'ZGL')

    oView := FWFormView():New()
    oView:SetModel(oModel)
    
    oView:AddField('VIEWZGL', oStr1, 'MASTERZGL')
    oView:CreateHorizontalBox('LOG_ZGL' , 100)
    oView:SetOwnerView('VIEWZGL', 'LOG_ZGL')
    oView:SetCloseOnOk({||.T.})
    oView:showUpdateMsg(.F.)
    
Return oView
