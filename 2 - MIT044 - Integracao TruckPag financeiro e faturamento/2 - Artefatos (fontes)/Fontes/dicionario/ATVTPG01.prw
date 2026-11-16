#INCLUDE "protheus.ch"

#DEFINE SIMPLES Char( 39 )
#DEFINE DUPLAS  Char( 34 )

#DEFINE CSSBOTAO	"QPushButton { color: #024670; "+;
"    border-image: url(rpo:fwstd_btn_nml.png) 3 3 3 3 stretch; "+;
"    border-top-width: 3px; "+;
"    border-left-width: 3px; "+;
"    border-right-width: 3px; "+;
"    border-bottom-width: 3px }"+;
"QPushButton:pressed {	color: #FFFFFF; "+;
"    border-image: url(rpo:fwstd_btn_prd.png) 3 3 3 3 stretch; "+;
"    border-top-width: 3px; "+;
"    border-left-width: 3px; "+;
"    border-right-width: 3px; "+;
"    border-bottom-width: 3px }"

//--------------------------------------------------------------------
/*/{Protheus.doc} ATVTPG01

Função de update de dicionários para compatibilização

@author UPDATE gerado automaticamente
@since  12/11/2024
@obs    Aplicador de SXs
@version 1.0
/*/
//--------------------------------------------------------------------
User Function ATVTPG01( cEmpAmb, cFilAmb )
Local   aSay      := {}
Local   aButton   := {}
Local   aMarcadas := {}
Local   cTitulo   := "ATUALIZAÇÃO DE DICIONÁRIOS E TABELAS"
Local   cDesc1    := "Esta rotina tem como função fazer  a atualização  dos dicionários do Sistema ( SX?/SIX )"
Local   cDesc2    := "Este processo deve ser executado em modo EXCLUSIVO, ou seja não podem haver outros"
Local   cDesc3    := "usuários  ou  jobs utilizando  o sistema.  É EXTREMAMENTE recomendavél  que  se  faça"
Local   cDesc4    := "um BACKUP  dos DICIONÁRIOS  e da  BASE DE DADOS antes desta atualização, para"
Local   cDesc5    := "que caso ocorram eventuais falhas, esse backup possa ser recuperado."
Local   cDesc6    := ""
Local   cDesc7    := ""
Local   cMsg      := ""
Local   lOk       := .F.
Local   lAuto     := ( cEmpAmb <> NIL .or. cFilAmb <> NIL )

Private oMainWnd  := NIL
Private oProcess  := NIL

#IFDEF TOP
    TCInternal( 5, "*OFF" ) // Desliga Refresh no Lock do Top
#ENDIF

__cInterNet := NIL
__lPYME     := .F.

Set Dele On

// Mensagens de Tela Inicial
aAdd( aSay, cDesc1 )
aAdd( aSay, cDesc2 )
aAdd( aSay, cDesc3 )
aAdd( aSay, cDesc4 )
aAdd( aSay, cDesc5 )
//aAdd( aSay, cDesc6 )
//aAdd( aSay, cDesc7 )

// Botoes Tela Inicial
aAdd(  aButton, {  1, .T., { || lOk := .T., FechaBatch() } } )
aAdd(  aButton, {  2, .T., { || lOk := .F., FechaBatch() } } )

If lAuto
	lOk := .T.
Else
	FormBatch(  cTitulo,  aSay,  aButton )
EndIf

If lOk

	If GetVersao(.F.) < "12" .OR. ( FindFunction( "MPDicInDB" ) .AND. !MPDicInDB() )
		cMsg := "Este update NÃO PODE ser executado neste Ambiente." + CRLF + CRLF + ;
				"Os arquivos de dicionários se encontram em formato ISAM" + " (" + GetDbExtension() + ") " + "Os arquivos de dicionários se encontram em formato ISAM" + " " + ;
				"para atualizar apenas ambientes com dicionários no Banco de Dados."

		If lAuto
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( "LOG DA ATUALIZAÇÃO DOS DICIONÁRIOS" )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( cMsg )
			FwLogMsg( "ERROR", , , , , , DToC(Date()) + "|" + Time() + cMsg )
		Else
			MsgInfo( cMsg )
		EndIf

		Return NIL
	EndIf

	If lAuto
		aMarcadas :={{ cEmpAmb, cFilAmb, "" }}
	Else
		aMarcadas := EscEmpresa()
	EndIf

	If !Empty( aMarcadas )
		If lAuto .OR. MsgNoYes( "Confirma a atualização dos dicionários ?", cTitulo )
			If IsBlind()
				// Ajuste TruckPag (24/10/2026): em job nao ha tela; MsNewProcess recusa thread de job
				oProcess := ZTPGPRC():New()
				lOk := FSTProc( .F., aMarcadas, lAuto )
			Else
				oProcess := MsNewProcess():New( { | lEnd | lOk := FSTProc( @lEnd, aMarcadas, lAuto ) }, "Atualizando", "Aguarde, atualizando ...", .F. )
				oProcess:Activate()
			EndIf

			If lAuto
				If IsBlind()
					FwLogMsg( "INFO", , "ATVTPG01", , , , "ATVTPG01 " + IIf( lOk, "Atualizacao realizada.", "Atualizacao NAO realizada." ) )
				ElseIf lOk
					MsgInfo( "Atualização realizada.", "ATVTPG01" )
				Else
					MsgStop( "Atualização não realizada.", "ATVTPG01" )
				EndIf
				dbCloseAll()
			Else
				If lOk
					Final( "Atualização realizada." )
				Else
					Final( "Atualização não realizada." )
				EndIf
			EndIf

		Else
			Final( "Atualização não realizada." )

		EndIf

	Else
		Final( "Atualização não realizada." )

	EndIf

EndIf

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} FSTProc

Função de processamento da gravação dos arquivos

@author UPDATE gerado automaticamente
@since  12/11/2024
@obs    Aplicador de SXs
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSTProc( lEnd, aMarcadas, lAuto )
Local   aInfo     := {}
Local   aRecnoSM0 := {}
Local   cAux      := ""
Local   cFile     := ""
Local   cFileLog  := ""
Local   cMask     := "Arquivos Texto" + "(*.TXT)|*.txt|"
Local   cTCBuild  := "TCGetBuild"
Local   cTexto    := ""
Local   cTopBuild := ""
Local   lOpen     := .F.
Local   lRet      := .T.
Local   nI        := 0
Local   nPos      := 0
Local   nRecno    := 0
Local   nX        := 0
Local   oDlg      := NIL
Local   oFont     := NIL
Local   oMemo     := NIL

Private aArqUpd   := {}

If ( lOpen := MyOpenSm0(.T.) )

	dbSelectArea( "SM0" )
	dbGoTop()

	While !SM0->( EOF() )
		// Só adiciona no aRecnoSM0 se a empresa for diferente
		If aScan( aRecnoSM0, { |x| x[2] == SM0->M0_CODIGO } ) == 0 ;
		   .AND. aScan( aMarcadas, { |x| x[1] == SM0->M0_CODIGO } ) > 0
			aAdd( aRecnoSM0, { Recno(), SM0->M0_CODIGO } )
		EndIf
		SM0->( dbSkip() )
	End

	SM0->( dbCloseArea() )

	If lOpen

		For nI := 1 To Len( aRecnoSM0 )

			If !( lOpen := MyOpenSm0(.F.) )
				MsgStop( "Atualização da empresa " + aRecnoSM0[nI][2] + " não efetuada." )
				Exit
			EndIf

			SM0->( dbGoTo( aRecnoSM0[nI][1] ) )

			RpcSetEnv( SM0->M0_CODIGO, SM0->M0_CODFIL )

			lMsFinalAuto := .F.
			lMsHelpAuto  := .F.

			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( "LOG DA ATUALIZAÇÃO DOS DICIONÁRIOS" )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( " " )
			AutoGrLog( " Dados Ambiente" )
			AutoGrLog( " --------------------" )
			AutoGrLog( " Empresa / Filial...: " + cEmpAnt + "/" + cFilAnt )
			AutoGrLog( " Nome Empresa.......: " + Capital( AllTrim( GetAdvFVal( "SM0", "M0_NOMECOM", cEmpAnt + cFilAnt, 1, "" ) ) ) )
			AutoGrLog( " Nome Filial........: " + Capital( AllTrim( GetAdvFVal( "SM0", "M0_FILIAL" , cEmpAnt + cFilAnt, 1, "" ) ) ) )
			AutoGrLog( " DataBase...........: " + DtoC( dDataBase ) )
			AutoGrLog( " Data / Hora Ínicio.: " + DtoC( Date() )  + " / " + Time() )
			AutoGrLog( " Environment........: " + GetEnvServer()  )
			AutoGrLog( " StartPath..........: " + GetSrvProfString( "StartPath", "" ) )
			AutoGrLog( " RootPath...........: " + GetSrvProfString( "RootPath" , "" ) )
			AutoGrLog( " Versão.............: " + GetVersao(.T.) )
			AutoGrLog( " Usuário TOTVS .....: " + __cUserId + " " +  cUserName )
			AutoGrLog( " Computer Name......: " + GetComputerName() )

			aInfo   := GetUserInfo()
			If ( nPos    := aScan( aInfo,{ |x,y| x[3] == ThreadId() } ) ) > 0
				AutoGrLog( " " )
				AutoGrLog( " Dados Thread" )
				AutoGrLog( " --------------------" )
				AutoGrLog( " Usuário da Rede....: " + aInfo[nPos][1] )
				AutoGrLog( " Estação............: " + aInfo[nPos][2] )
				AutoGrLog( " Programa Inicial...: " + aInfo[nPos][5] )
				AutoGrLog( " Environment........: " + aInfo[nPos][6] )
				AutoGrLog( " Conexão............: " + AllTrim( StrTran( StrTran( aInfo[nPos][7], Chr( 13 ), "" ), Chr( 10 ), "" ) ) )
			EndIf
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( " " )

			If !lAuto
				AutoGrLog( Replicate( "-", 128 ) )
				AutoGrLog( "Empresa : " + SM0->M0_CODIGO + "/" + SM0->M0_NOME + CRLF )
			EndIf

			oProcess:SetRegua1( 5 )

			FSAtuSX2()
			FSAtuSX3()
			FSAtuSIX()
			FSAtuSX6()

			// Alteração física dos arquivos
			__SetX31Mode( .F. )

			If FindFunction(cTCBuild)
				cTopBuild := &cTCBuild.()
			EndIf

			For nX := 1 To Len( aArqUpd )

				If cTopBuild >= "20090811" .AND. TcInternal( 89 ) == "CLOB_SUPPORTED"
					If ( ( aArqUpd[nX] >= "NQ " .AND. aArqUpd[nX] <= "NZZ" ) .OR. ( aArqUpd[nX] >= "O0 " .AND. aArqUpd[nX] <= "NZZ" ) ) .AND.;
						!aArqUpd[nX] $ "NQD,NQF,NQP,NQT"
						TcInternal( 25, "CLOB" )
					EndIf
				EndIf

				If Select( aArqUpd[nX] ) > 0
					dbSelectArea( aArqUpd[nX] )
					dbCloseArea()
				EndIf

				X31UpdTable( aArqUpd[nX] )

				If __GetX31Error()
					Alert( __GetX31Trace() )
					MsgStop( "Ocorreu um erro desconhecido durante a atualização da tabela : " + aArqUpd[nX] + ". Verifique a integridade do dicionário e da tabela.", "ATENÇÃO" )
					AutoGrLog( "Ocorreu um erro desconhecido durante a atualização da estrutura da tabela : " + aArqUpd[nX] )
				EndIf

				If cTopBuild >= "20090811" .AND. TcInternal( 89 ) == "CLOB_SUPPORTED"
					TcInternal( 25, "OFF" )
				EndIf

			Next nX

			//------------------------------------
			// Atualiza os helps
			//------------------------------------
			oProcess:IncRegua1( "Helps de Campo" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			FSAtuHlp()

			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( " Data / Hora Final.: " + DtoC( Date() ) + " / " + Time() )
			AutoGrLog( Replicate( "-", 128 ) )

			RpcClearEnv()

		Next nI

		If !lAuto

			cTexto := LeLog()

			Define Font oFont Name "Mono AS" Size 5, 12

			Define MsDialog oDlg Title "Atualização concluida." From 3, 0 to 340, 417 Pixel

			@ 5, 5 Get oMemo Var cTexto Memo Size 200, 145 Of oDlg Pixel
			oMemo:bRClicked := { || AllwaysTrue() }
			oMemo:oFont     := oFont

			Define SButton From 153, 175 Type  1 Action oDlg:End() Enable Of oDlg Pixel // Apaga
			Define SButton From 153, 145 Type 13 Action ( cFile := cGetFile( cMask, "" ), If( cFile == "", .T., ;
			MemoWrite( cFile, cTexto ) ) ) Enable Of oDlg Pixel

			Activate MsDialog oDlg Center

		EndIf

	EndIf

Else

	lRet := .F.

EndIf

Return lRet


//------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSX2

Funcao de processamento da gravacao do SX2 - Arquivos

@author UPDATE gerado automaticamente
@obs    Aplicador de SXs
@version 1.0
/*/
//------------------------------------------------------------------
Static Function FSAtuSX2()
Local aEstrut   := {}
Local aIncl     := {}
Local aSX2      := {}
Local cCpoUpd   := "X2_ROTINA /X2_UNICO  /X2_DISPLAY/X2_SYSOBJ /X2_USROBJ /X2_POSLGT /"
Local nI        := 0
Local nJ        := 0
Local nPosChv   := 0
Local nPosUni   := 0

AutoGrLog( "Inicio da Atualizacao" + " SX2" + CRLF )

aEstrut := { { "X2_CHAVE", 0 }, { "X2_PATH", 0 }, { "X2_ARQUIVO", 0 }, { "X2_NOME", 0 }, ;
             { "X2_NOMESPA", 0 }, { "X2_NOMEENG", 0 }, { "X2_MODO", 0 }, { "X2_TTS", 0 }, ;
             { "X2_ROTINA", 0 }, { "X2_PYME", 0 }, { "X2_UNICO", 0 }, { "X2_DISPLAY", 0 }, ;
             { "X2_SYSOBJ", 0 }, { "X2_USROBJ", 0 }, { "X2_POSLGT", 0 }, { "X2_CLOB", 0 }, ;
             { "X2_AUTREC", 0 }, { "X2_MODOEMP", 0 }, { "X2_MODOUN", 0 }, { "X2_MODULO", 0 } }

aEval( aEstrut, { |x| x[2] := SX2->( FieldPos( x[1] ) ) } )

//
// Arquivos (aSX2)
//
aAdd( aSX2, { ;
	'ZB0', ; //X2_CHAVE
	'', ; //X2_PATH
	'ZB0', ; //X2_ARQUIVO
	'TruckPag transacoes', ; //X2_NOME
	'TruckPag transacoes', ; //X2_NOMESPA
	'TruckPag transacoes', ; //X2_NOMEENG
	'E', ; //X2_MODO
	'', ; //X2_TTS
	'', ; //X2_ROTINA
	'', ; //X2_PYME
	'ZB0_FILIAL+ZB0_IDTRAN', ; //X2_UNICO
	'', ; //X2_DISPLAY
	'', ; //X2_SYSOBJ
	'', ; //X2_USROBJ
	'', ; //X2_POSLGT
	'', ; //X2_CLOB
	'', ; //X2_AUTREC
	'E', ; //X2_MODOEMP
	'E', ; //X2_MODOUN
	0 } ) //X2_MODULO

aAdd( aSX2, { ;
	'ZB1', ; //X2_CHAVE
	'', ; //X2_PATH
	'ZB1', ; //X2_ARQUIVO
	'TruckPag titulos integracao', ; //X2_NOME
	'TruckPag titulos integracao', ; //X2_NOMESPA
	'TruckPag titulos integracao', ; //X2_NOMEENG
	'E', ; //X2_MODO
	'', ; //X2_TTS
	'', ; //X2_ROTINA
	'', ; //X2_PYME
	'ZB1_FILIAL+ZB1_ID', ; //X2_UNICO
	'', ; //X2_DISPLAY
	'', ; //X2_SYSOBJ
	'', ; //X2_USROBJ
	'', ; //X2_POSLGT
	'', ; //X2_CLOB
	'', ; //X2_AUTREC
	'E', ; //X2_MODOEMP
	'E', ; //X2_MODOUN
	0 } ) //X2_MODULO

aAdd( aSX2, { ;
	'ZB2', ; //X2_CHAVE
	'', ; //X2_PATH
	'ZB2', ; //X2_ARQUIVO
	'TruckPag faturas e baixas', ; //X2_NOME
	'TruckPag faturas e baixas', ; //X2_NOMESPA
	'TruckPag faturas e baixas', ; //X2_NOMEENG
	'E', ; //X2_MODO
	'', ; //X2_TTS
	'', ; //X2_ROTINA
	'', ; //X2_PYME
	'ZB2_FILIAL+ZB2_ID', ; //X2_UNICO
	'', ; //X2_DISPLAY
	'', ; //X2_SYSOBJ
	'', ; //X2_USROBJ
	'', ; //X2_POSLGT
	'', ; //X2_CLOB
	'', ; //X2_AUTREC
	'E', ; //X2_MODOEMP
	'E', ; //X2_MODOUN
	0 } ) //X2_MODULO

aAdd( aSX2, { ;
	'ZB3', ; //X2_CHAVE
	'', ; //X2_PATH
	'ZB3', ; //X2_ARQUIVO
	'TruckPag itens fatura/baixa', ; //X2_NOME
	'TruckPag itens fatura/baixa', ; //X2_NOMESPA
	'TruckPag itens fatura/baixa', ; //X2_NOMEENG
	'E', ; //X2_MODO
	'', ; //X2_TTS
	'', ; //X2_ROTINA
	'', ; //X2_PYME
	'ZB3_FILIAL+ZB3_ID+ZB3_ITEM', ; //X2_UNICO
	'', ; //X2_DISPLAY
	'', ; //X2_SYSOBJ
	'', ; //X2_USROBJ
	'', ; //X2_POSLGT
	'', ; //X2_CLOB
	'', ; //X2_AUTREC
	'E', ; //X2_MODOEMP
	'E', ; //X2_MODOUN
	0 } ) //X2_MODULO

aAdd( aSX2, { ;
	'ZB4', ; //X2_CHAVE
	'', ; //X2_PATH
	'ZB4', ; //X2_ARQUIVO
	'TruckPag log das chamadas', ; //X2_NOME
	'TruckPag log das chamadas', ; //X2_NOMESPA
	'TruckPag log das chamadas', ; //X2_NOMEENG
	'E', ; //X2_MODO
	'', ; //X2_TTS
	'', ; //X2_ROTINA
	'', ; //X2_PYME
	'ZB4_FILIAL+ZB4_ID', ; //X2_UNICO
	'', ; //X2_DISPLAY
	'', ; //X2_SYSOBJ
	'', ; //X2_USROBJ
	'', ; //X2_POSLGT
	'', ; //X2_CLOB
	'', ; //X2_AUTREC
	'E', ; //X2_MODOEMP
	'E', ; //X2_MODOUN
	0 } ) //X2_MODULO

nPosChv := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X2_CHAVE" } )
nPosUni := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X2_UNICO" } )

oProcess:SetRegua2( Len( aSX2 ) )

dbSelectArea( "SX2" )
dbSetOrder( 1 )

For nI := 1 To Len( aSX2 )

	oProcess:IncRegua2( "Atualizando Arquivos (SX2) ..." )

	If aScan( aArqUpd, { |x| x == aSX2[nI][nPosChv] } ) == 0
		aAdd( aArqUpd, aSX2[nI][nPosChv] )
	EndIf

	If !SX2->( dbSeek( aSX2[nI][nPosChv] ) )

		If aScan( aIncl, { |x| x == aSX2[nI][nPosChv] } ) == 0
			aAdd( aIncl, aSX2[nI][nPosChv] )
			AutoGrLog( "Foi incluida a tabela " + aSX2[nI][nPosChv] )
		EndIf

		RecLock( "SX2", .T. )
		For nJ := 1 To Len( aSX2[nI] )
			If aEstrut[nJ][2] > 0
				If AllTrim( aEstrut[nJ][1] ) == "X2_ARQUIVO"
					SX2->( FieldPut( aEstrut[nJ][2], SubStr( aSX2[nI][nJ], 1, 3 ) + cEmpAnt + "0" ) )
				Else
					SX2->( FieldPut( aEstrut[nJ][2], aSX2[nI][nJ] ) )
				EndIf
			EndIf
		Next nJ

		dbCommit()
		MsUnLock()

	Else

		If !( StrTran( Upper( AllTrim( SX2->X2_UNICO ) ), " ", "" ) == ;
		      StrTran( Upper( AllTrim( aSX2[nI][nPosUni] ) ), " ", "" ) )
			RecLock( "SX2", .F. )
			SX2->X2_UNICO := aSX2[nI][nPosUni]
			dbCommit()
			MsUnLock()

			If MSFILE( RetSqlName( aSX2[nI][nPosChv] ), RetSqlName( aSX2[nI][nPosChv] ) + "_UNQ" )
				TcInternal( 60, RetSqlName( aSX2[nI][nPosChv] ) + "|" + RetSqlName( aSX2[nI][nPosChv] ) + "_UNQ" )
			EndIf

			AutoGrLog( "Foi alterada a chave unica da tabela " + aSX2[nI][nPosChv] )
		EndIf

		RecLock( "SX2", .F. )
		For nJ := 1 To Len( aSX2[nI] )
			If aEstrut[nJ][2] > 0 .And. PadR( aEstrut[nJ][1], 10 ) $ cCpoUpd
				SX2->( FieldPut( aEstrut[nJ][2], aSX2[nI][nJ] ) )
			EndIf
		Next nJ

		dbCommit()
		MsUnLock()

	EndIf

Next nI

AutoGrLog( CRLF + "Final da Atualizacao" + " SX2" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL

//------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSX3

Funcao de processamento da gravacao do SX3 - Campos

@author UPDATE gerado automaticamente
@obs    Aplicador de SXs
@version 1.0
/*/
//------------------------------------------------------------------
Static Function FSAtuSX3()
Local aEstrut   := {}
Local aSX3      := {}
Local cAliasAtu := ""
Local cSeqAtu   := ""
Local nI        := 0
Local nJ        := 0
Local nPosArq   := 0
Local nPosCpo   := 0
Local nPosOrd   := 0
Local nPosSXG   := 0
Local nPosTam   := 0
Local nSeqAtu   := 0
Local nTamSeek  := Len( SX3->X3_CAMPO )

AutoGrLog( "Inicio da Atualizacao" + " SX3" + CRLF )

aEstrut := { { "X3_ARQUIVO", 0 }, { "X3_ORDEM", 0 }, { "X3_CAMPO", 0 }, { "X3_TIPO", 0 }, ;
             { "X3_TAMANHO", 0 }, { "X3_DECIMAL", 0 }, { "X3_TITULO", 0 }, { "X3_TITSPA", 0 }, ;
             { "X3_TITENG", 0 }, { "X3_DESCRIC", 0 }, { "X3_DESCSPA", 0 }, { "X3_DESCENG", 0 }, ;
             { "X3_PICTURE", 0 }, { "X3_VALID", 0 }, { "X3_USADO", 0 }, { "X3_RELACAO", 0 }, ;
             { "X3_F3", 0 }, { "X3_NIVEL", 0 }, { "X3_RESERV", 0 }, { "X3_CHECK", 0 }, ;
             { "X3_TRIGGER", 0 }, { "X3_PROPRI", 0 }, { "X3_BROWSE", 0 }, { "X3_VISUAL", 0 }, ;
             { "X3_CONTEXT", 0 }, { "X3_OBRIGAT", 0 }, { "X3_VLDUSER", 0 }, { "X3_CBOX", 0 }, ;
             { "X3_CBOXSPA", 0 }, { "X3_CBOXENG", 0 }, { "X3_PICTVAR", 0 }, { "X3_WHEN", 0 }, ;
             { "X3_INIBRW", 0 }, { "X3_GRPSXG", 0 }, { "X3_FOLDER", 0 }, { "X3_CONDSQL", 0 }, ;
             { "X3_CHKSQL", 0 }, { "X3_IDXSRV", 0 }, { "X3_ORTOGRA", 0 }, { "X3_TELA", 0 }, ;
             { "X3_POSLGT", 0 }, { "X3_IDXFLD", 0 }, { "X3_AGRUP", 0 }, { "X3_MODAL", 0 }, ;
             { "X3_PYME", 0 }, { "X3_INIT", 0 } }

aEval( aEstrut, { |x| x[2] := SX3->( FieldPos( x[1] ) ) } )

//
// Campos (aSX3)
//
aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'01', ; //X3_ORDEM
	'ZB0_FILIAL', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Filial', ; //X3_TITULO
	'Filial', ; //X3_TITSPA
	'Filial', ; //X3_TITENG
	'Filial do sistema', ; //X3_DESCRIC
	'Filial do sistema', ; //X3_DESCSPA
	'Filial do sistema', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'033', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'02', ; //X3_ORDEM
	'ZB0_IDTRAN', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id transacao', ; //X3_TITULO
	'Id transacao', ; //X3_TITSPA
	'Id transacao', ; //X3_TITENG
	'Id da transacao (idEstorno no estorno)', ; //X3_DESCRIC
	'Id da transacao (idEstorno no estorno)', ; //X3_DESCSPA
	'Id da transacao (idEstorno no estorno)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'03', ; //X3_ORDEM
	'ZB0_OPER', ; //X3_CAMPO
	'C', ; //X3_TIPO
	1, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Operacao', ; //X3_TITULO
	'Operacao', ; //X3_TITSPA
	'Operacao', ; //X3_TITENG
	'I=inclusao API 01, E=estorno API 02', ; //X3_DESCRIC
	'I=inclusao API 01, E=estorno API 02', ; //X3_DESCSPA
	'I=inclusao API 01, E=estorno API 02', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'I=Inclusao;E=Estorno', ; //X3_CBOX
	'I=Inclusao;E=Estorno', ; //X3_CBOXSPA
	'I=Inclusao;E=Estorno', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'04', ; //X3_ORDEM
	'ZB0_NRNF', ; //X3_CAMPO
	'C', ; //X3_TIPO
	20, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'nrNfFornec', ; //X3_TITULO
	'nrNfFornec', ; //X3_TITSPA
	'nrNfFornec', ; //X3_TITENG
	'Id da transacao no Sistema Gestao', ; //X3_DESCRIC
	'Id da transacao no Sistema Gestao', ; //X3_DESCSPA
	'Id da transacao no Sistema Gestao', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'05', ; //X3_ORDEM
	'ZB0_CNPJBE', ; //X3_CAMPO
	'C', ; //X3_TIPO
	14, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'CNPJ benefic.', ; //X3_TITULO
	'CNPJ benefic.', ; //X3_TITSPA
	'CNPJ benefic.', ; //X3_TITENG
	'CNPJ do beneficiario', ; //X3_DESCRIC
	'CNPJ do beneficiario', ; //X3_DESCSPA
	'CNPJ do beneficiario', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'06', ; //X3_ORDEM
	'ZB0_CNPJPG', ; //X3_CAMPO
	'C', ; //X3_TIPO
	14, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'CNPJ pagador', ; //X3_TITULO
	'CNPJ pagador', ; //X3_TITSPA
	'CNPJ pagador', ; //X3_TITENG
	'CNPJ do pagador', ; //X3_DESCRIC
	'CNPJ do pagador', ; //X3_DESCSPA
	'CNPJ do pagador', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'07', ; //X3_ORDEM
	'ZB0_MUNBE', ; //X3_CAMPO
	'C', ; //X3_TIPO
	7, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Mun. benefic.', ; //X3_TITULO
	'Mun. benefic.', ; //X3_TITSPA
	'Mun. benefic.', ; //X3_TITENG
	'IBGE do municipio do beneficiario', ; //X3_DESCRIC
	'IBGE do municipio do beneficiario', ; //X3_DESCSPA
	'IBGE do municipio do beneficiario', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'08', ; //X3_ORDEM
	'ZB0_MUNPG', ; //X3_CAMPO
	'C', ; //X3_TIPO
	7, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Mun. pagador', ; //X3_TITULO
	'Mun. pagador', ; //X3_TITSPA
	'Mun. pagador', ; //X3_TITENG
	'IBGE do municipio do pagador', ; //X3_DESCRIC
	'IBGE do municipio do pagador', ; //X3_DESCSPA
	'IBGE do municipio do pagador', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'09', ; //X3_ORDEM
	'ZB0_DTEMIS', ; //X3_CAMPO
	'D', ; //X3_TIPO
	8, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Data transac.', ; //X3_TITULO
	'Data transac.', ; //X3_TITSPA
	'Data transac.', ; //X3_TITENG
	'Data da transacao (dtEmissaoFornec)', ; //X3_DESCRIC
	'Data da transacao (dtEmissaoFornec)', ; //X3_DESCSPA
	'Data da transacao (dtEmissaoFornec)', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'10', ; //X3_ORDEM
	'ZB0_VLREC', ; //X3_CAMPO
	'N', ; //X3_TIPO
	16, ; //X3_TAMANHO
	2, ; //X3_DECIMAL
	'Vl recebido', ; //X3_TITULO
	'Vl recebido', ; //X3_TITSPA
	'Vl recebido', ; //X3_TITENG
	'Valor a receber do transportador', ; //X3_DESCRIC
	'Valor a receber do transportador', ; //X3_DESCSPA
	'Valor a receber do transportador', ; //X3_DESCENG
	'@E 99,999,999,999.99', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'11', ; //X3_ORDEM
	'ZB0_VLPAG', ; //X3_CAMPO
	'N', ; //X3_TIPO
	16, ; //X3_TAMANHO
	2, ; //X3_DECIMAL
	'Vl pago', ; //X3_TITULO
	'Vl pago', ; //X3_TITSPA
	'Vl pago', ; //X3_TITENG
	'Valor a pagar ao posto', ; //X3_DESCRIC
	'Valor a pagar ao posto', ; //X3_DESCSPA
	'Valor a pagar ao posto', ; //X3_DESCENG
	'@E 99,999,999,999.99', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'12', ; //X3_ORDEM
	'ZB0_IDREC', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'idRecebimento', ; //X3_TITULO
	'idRecebimento', ; //X3_TITSPA
	'idRecebimento', ; //X3_TITENG
	'Id da perna a receber (ZB1)', ; //X3_DESCRIC
	'Id da perna a receber (ZB1)', ; //X3_DESCSPA
	'Id da perna a receber (ZB1)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'13', ; //X3_ORDEM
	'ZB0_IDPAG', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'idPagamento', ; //X3_TITULO
	'idPagamento', ; //X3_TITSPA
	'idPagamento', ; //X3_TITENG
	'Id da perna a pagar (ZB1)', ; //X3_DESCRIC
	'Id da perna a pagar (ZB1)', ; //X3_DESCSPA
	'Id da perna a pagar (ZB1)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'14', ; //X3_ORDEM
	'ZB0_IDORIG', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'idNotaFiscal', ; //X3_TITULO
	'idNotaFiscal', ; //X3_TITSPA
	'idNotaFiscal', ; //X3_TITENG
	'Estorno: idPagamento da original', ; //X3_DESCRIC
	'Estorno: idPagamento da original', ; //X3_DESCSPA
	'Estorno: idPagamento da original', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'15', ; //X3_ORDEM
	'ZB0_TRORIG', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Transac. orig.', ; //X3_TITULO
	'Transac. orig.', ; //X3_TITSPA
	'Transac. orig.', ; //X3_TITENG
	'Estorno: id da transacao original', ; //X3_DESCRIC
	'Estorno: id da transacao original', ; //X3_DESCSPA
	'Estorno: id da transacao original', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'16', ; //X3_ORDEM
	'ZB0_HASH', ; //X3_CAMPO
	'C', ; //X3_TIPO
	32, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Hash', ; //X3_TITULO
	'Hash', ; //X3_TITSPA
	'Hash', ; //X3_TITENG
	'Hash MD5 do conteudo enviado', ; //X3_DESCRIC
	'Hash MD5 do conteudo enviado', ; //X3_DESCSPA
	'Hash MD5 do conteudo enviado', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'17', ; //X3_ORDEM
	'ZB0_DTHR', ; //X3_CAMPO
	'C', ; //X3_TIPO
	14, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Data/hora', ; //X3_TITULO
	'Data/hora', ; //X3_TITSPA
	'Data/hora', ; //X3_TITENG
	'Data e hora (AAAAMMDDHHMMSS)', ; //X3_DESCRIC
	'Data e hora (AAAAMMDDHHMMSS)', ; //X3_DESCSPA
	'Data e hora (AAAAMMDDHHMMSS)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB0', ; //X3_ARQUIVO
	'18', ; //X3_ORDEM
	'ZB0_LOG', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id chamada', ; //X3_TITULO
	'Id chamada', ; //X3_TITSPA
	'Id chamada', ; //X3_TITENG
	'Id da chamada no log (ZB4)', ; //X3_DESCRIC
	'Id da chamada no log (ZB4)', ; //X3_DESCSPA
	'Id da chamada no log (ZB4)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'01', ; //X3_ORDEM
	'ZB1_FILIAL', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Filial', ; //X3_TITULO
	'Filial', ; //X3_TITSPA
	'Filial', ; //X3_TITENG
	'Filial do sistema', ; //X3_DESCRIC
	'Filial do sistema', ; //X3_DESCSPA
	'Filial do sistema', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'033', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'02', ; //X3_ORDEM
	'ZB1_ID', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id titulo', ; //X3_TITULO
	'Id titulo', ; //X3_TITSPA
	'Id titulo', ; //X3_TITENG
	'idRecebimento/idPagamento devolvido', ; //X3_DESCRIC
	'idRecebimento/idPagamento devolvido', ; //X3_DESCSPA
	'idRecebimento/idPagamento devolvido', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'03', ; //X3_ORDEM
	'ZB1_CART', ; //X3_CAMPO
	'C', ; //X3_TIPO
	1, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Carteira', ; //X3_TITULO
	'Carteira', ; //X3_TITSPA
	'Carteira', ; //X3_TITENG
	'R=receber, P=pagar', ; //X3_DESCRIC
	'R=receber, P=pagar', ; //X3_DESCSPA
	'R=receber, P=pagar', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'R=Receber;P=Pagar', ; //X3_CBOX
	'R=Receber;P=Pagar', ; //X3_CBOXSPA
	'R=Receber;P=Pagar', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'04', ; //X3_ORDEM
	'ZB1_IDTRAN', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id transacao', ; //X3_TITULO
	'Id transacao', ; //X3_TITSPA
	'Id transacao', ; //X3_TITENG
	'Transacao de origem (ZB0)', ; //X3_DESCRIC
	'Transacao de origem (ZB0)', ; //X3_DESCSPA
	'Transacao de origem (ZB0)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'05', ; //X3_ORDEM
	'ZB1_OPER', ; //X3_CAMPO
	'C', ; //X3_TIPO
	1, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Operacao', ; //X3_TITULO
	'Operacao', ; //X3_TITSPA
	'Operacao', ; //X3_TITENG
	'I=inclusao, E=estorno', ; //X3_DESCRIC
	'I=inclusao, E=estorno', ; //X3_DESCSPA
	'I=inclusao, E=estorno', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'I=Inclusao;E=Estorno', ; //X3_CBOX
	'I=Inclusao;E=Estorno', ; //X3_CBOXSPA
	'I=Inclusao;E=Estorno', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'06', ; //X3_ORDEM
	'ZB1_PREFIX', ; //X3_CAMPO
	'C', ; //X3_TIPO
	3, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Prefixo', ; //X3_TITULO
	'Prefixo', ; //X3_TITSPA
	'Prefixo', ; //X3_TITENG
	'Prefixo do titulo', ; //X3_DESCRIC
	'Prefixo do titulo', ; //X3_DESCSPA
	'Prefixo do titulo', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'07', ; //X3_ORDEM
	'ZB1_NUM', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Numero', ; //X3_TITULO
	'Numero', ; //X3_TITSPA
	'Numero', ; //X3_TITENG
	'Numero do titulo', ; //X3_DESCRIC
	'Numero do titulo', ; //X3_DESCSPA
	'Numero do titulo', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'018', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'08', ; //X3_ORDEM
	'ZB1_PARCEL', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Parcela', ; //X3_TITULO
	'Parcela', ; //X3_TITSPA
	'Parcela', ; //X3_TITENG
	'Parcela do titulo', ; //X3_DESCRIC
	'Parcela do titulo', ; //X3_DESCSPA
	'Parcela do titulo', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'011', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'09', ; //X3_ORDEM
	'ZB1_TIPO', ; //X3_CAMPO
	'C', ; //X3_TIPO
	3, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Tipo', ; //X3_TITULO
	'Tipo', ; //X3_TITSPA
	'Tipo', ; //X3_TITENG
	'Tipo do titulo', ; //X3_DESCRIC
	'Tipo do titulo', ; //X3_DESCSPA
	'Tipo do titulo', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'10', ; //X3_ORDEM
	'ZB1_CLIFOR', ; //X3_CAMPO
	'C', ; //X3_TIPO
	6, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Cli/Fornec', ; //X3_TITULO
	'Cli/Fornec', ; //X3_TITSPA
	'Cli/Fornec', ; //X3_TITENG
	'Cliente ou fornecedor', ; //X3_DESCRIC
	'Cliente ou fornecedor', ; //X3_DESCSPA
	'Cliente ou fornecedor', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'001', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'11', ; //X3_ORDEM
	'ZB1_LOJA', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Loja', ; //X3_TITULO
	'Loja', ; //X3_TITSPA
	'Loja', ; //X3_TITENG
	'Loja', ; //X3_DESCRIC
	'Loja', ; //X3_DESCSPA
	'Loja', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'002', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'12', ; //X3_ORDEM
	'ZB1_VALOR', ; //X3_CAMPO
	'N', ; //X3_TIPO
	16, ; //X3_TAMANHO
	2, ; //X3_DECIMAL
	'Valor', ; //X3_TITULO
	'Valor', ; //X3_TITSPA
	'Valor', ; //X3_TITENG
	'Valor do titulo', ; //X3_DESCRIC
	'Valor do titulo', ; //X3_DESCSPA
	'Valor do titulo', ; //X3_DESCENG
	'@E 99,999,999,999.99', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'13', ; //X3_ORDEM
	'ZB1_IDAGR', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id fatura', ; //X3_TITULO
	'Id fatura', ; //X3_TITSPA
	'Id fatura', ; //X3_TITENG
	'Fatura que agrupou o titulo (ZB2)', ; //X3_DESCRIC
	'Fatura que agrupou o titulo (ZB2)', ; //X3_DESCSPA
	'Fatura que agrupou o titulo (ZB2)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB1', ; //X3_ARQUIVO
	'14', ; //X3_ORDEM
	'ZB1_STATUS', ; //X3_CAMPO
	'C', ; //X3_TIPO
	1, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Situacao', ; //X3_TITULO
	'Situacao', ; //X3_TITSPA
	'Situacao', ; //X3_TITENG
	'1=em aberto, 2=em fatura', ; //X3_DESCRIC
	'1=em aberto, 2=em fatura', ; //X3_DESCSPA
	'1=em aberto, 2=em fatura', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'1=Em aberto;2=Em fatura', ; //X3_CBOX
	'1=Em aberto;2=Em fatura', ; //X3_CBOXSPA
	'1=Em aberto;2=Em fatura', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'01', ; //X3_ORDEM
	'ZB2_FILIAL', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Filial', ; //X3_TITULO
	'Filial', ; //X3_TITSPA
	'Filial', ; //X3_TITENG
	'Filial do sistema', ; //X3_DESCRIC
	'Filial do sistema', ; //X3_DESCSPA
	'Filial do sistema', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'033', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'02', ; //X3_ORDEM
	'ZB2_ID', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id', ; //X3_TITULO
	'Id', ; //X3_TITSPA
	'Id', ; //X3_TITENG
	'idFatura ou idProcesso devolvido', ; //X3_DESCRIC
	'idFatura ou idProcesso devolvido', ; //X3_DESCSPA
	'idFatura ou idProcesso devolvido', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'03', ; //X3_ORDEM
	'ZB2_OPER', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Operacao', ; //X3_TITULO
	'Operacao', ; //X3_TITSPA
	'Operacao', ; //X3_TITENG
	'FR/FP fatura, BR/BP baixa', ; //X3_DESCRIC
	'FR/FP fatura, BR/BP baixa', ; //X3_DESCSPA
	'FR/FP fatura, BR/BP baixa', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'FR=Fatura receber;FP=Fatura pagar;BR=Baixa receber;BP=Baixa pagar', ; //X3_CBOX
	'FR=Fatura receber;FP=Fatura pagar;BR=Baixa receber;BP=Baixa pagar', ; //X3_CBOXSPA
	'FR=Fatura receber;FP=Fatura pagar;BR=Baixa receber;BP=Baixa pagar', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'04', ; //X3_ORDEM
	'ZB2_HASH', ; //X3_CAMPO
	'C', ; //X3_TIPO
	32, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Hash', ; //X3_TITULO
	'Hash', ; //X3_TITSPA
	'Hash', ; //X3_TITENG
	'Hash do pedido (idempotencia)', ; //X3_DESCRIC
	'Hash do pedido (idempotencia)', ; //X3_DESCSPA
	'Hash do pedido (idempotencia)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'05', ; //X3_ORDEM
	'ZB2_CNPJ', ; //X3_CAMPO
	'C', ; //X3_TIPO
	14, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'CNPJ', ; //X3_TITULO
	'CNPJ', ; //X3_TITSPA
	'CNPJ', ; //X3_TITENG
	'CNPJ do cliente ou fornecedor', ; //X3_DESCRIC
	'CNPJ do cliente ou fornecedor', ; //X3_DESCSPA
	'CNPJ do cliente ou fornecedor', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'06', ; //X3_ORDEM
	'ZB2_CLIFOR', ; //X3_CAMPO
	'C', ; //X3_TIPO
	6, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Cli/Fornec', ; //X3_TITULO
	'Cli/Fornec', ; //X3_TITSPA
	'Cli/Fornec', ; //X3_TITENG
	'Cliente ou fornecedor', ; //X3_DESCRIC
	'Cliente ou fornecedor', ; //X3_DESCSPA
	'Cliente ou fornecedor', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'001', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'07', ; //X3_ORDEM
	'ZB2_LOJA', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Loja', ; //X3_TITULO
	'Loja', ; //X3_TITSPA
	'Loja', ; //X3_TITENG
	'Loja', ; //X3_DESCRIC
	'Loja', ; //X3_DESCSPA
	'Loja', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'002', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'08', ; //X3_ORDEM
	'ZB2_PREFIX', ; //X3_CAMPO
	'C', ; //X3_TIPO
	3, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Prefixo', ; //X3_TITULO
	'Prefixo', ; //X3_TITSPA
	'Prefixo', ; //X3_TITENG
	'Prefixo da fatura', ; //X3_DESCRIC
	'Prefixo da fatura', ; //X3_DESCSPA
	'Prefixo da fatura', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'09', ; //X3_ORDEM
	'ZB2_NUM', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Numero', ; //X3_TITULO
	'Numero', ; //X3_TITSPA
	'Numero', ; //X3_TITENG
	'Numero da fatura', ; //X3_DESCRIC
	'Numero da fatura', ; //X3_DESCSPA
	'Numero da fatura', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'018', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'10', ; //X3_ORDEM
	'ZB2_PARCEL', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Parcela', ; //X3_TITULO
	'Parcela', ; //X3_TITSPA
	'Parcela', ; //X3_TITENG
	'Parcela da fatura', ; //X3_DESCRIC
	'Parcela da fatura', ; //X3_DESCSPA
	'Parcela da fatura', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'011', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'11', ; //X3_ORDEM
	'ZB2_TIPO', ; //X3_CAMPO
	'C', ; //X3_TIPO
	3, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Tipo', ; //X3_TITULO
	'Tipo', ; //X3_TITSPA
	'Tipo', ; //X3_TITENG
	'Tipo da fatura', ; //X3_DESCRIC
	'Tipo da fatura', ; //X3_DESCSPA
	'Tipo da fatura', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'12', ; //X3_ORDEM
	'ZB2_VALOR', ; //X3_CAMPO
	'N', ; //X3_TIPO
	16, ; //X3_TAMANHO
	2, ; //X3_DECIMAL
	'Valor', ; //X3_TITULO
	'Valor', ; //X3_TITSPA
	'Valor', ; //X3_TITENG
	'Valor da fatura ou da baixa', ; //X3_DESCRIC
	'Valor da fatura ou da baixa', ; //X3_DESCSPA
	'Valor da fatura ou da baixa', ; //X3_DESCENG
	'@E 99,999,999,999.99', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'13', ; //X3_ORDEM
	'ZB2_DTREF', ; //X3_CAMPO
	'D', ; //X3_TIPO
	8, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Data', ; //X3_TITULO
	'Data', ; //X3_TITSPA
	'Data', ; //X3_TITENG
	'Data da fatura ou do pagamento', ; //X3_DESCRIC
	'Data da fatura ou do pagamento', ; //X3_DESCSPA
	'Data da fatura ou do pagamento', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'14', ; //X3_ORDEM
	'ZB2_QTDOC', ; //X3_CAMPO
	'N', ; //X3_TIPO
	6, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Qtd docs', ; //X3_TITULO
	'Qtd docs', ; //X3_TITSPA
	'Qtd docs', ; //X3_TITENG
	'Quantidade de documentos', ; //X3_DESCRIC
	'Quantidade de documentos', ; //X3_DESCSPA
	'Quantidade de documentos', ; //X3_DESCENG
	'@E 999999', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'15', ; //X3_ORDEM
	'ZB2_IDBX', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id baixa', ; //X3_TITULO
	'Id baixa', ; //X3_TITSPA
	'Id baixa', ; //X3_TITENG
	'Fatura: processo que a baixou', ; //X3_DESCRIC
	'Fatura: processo que a baixou', ; //X3_DESCSPA
	'Fatura: processo que a baixou', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'16', ; //X3_ORDEM
	'ZB2_NUMLIQ', ; //X3_CAMPO
	'C', ; //X3_TIPO
	6, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Liquidacao', ; //X3_TITULO
	'Liquidacao', ; //X3_TITSPA
	'Liquidacao', ; //X3_TITENG
	'Liquidacao da fatura a receber', ; //X3_DESCRIC
	'Liquidacao da fatura a receber', ; //X3_DESCSPA
	'Liquidacao da fatura a receber', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'158', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'17', ; //X3_ORDEM
	'ZB2_DTHR', ; //X3_CAMPO
	'C', ; //X3_TIPO
	14, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Data/hora', ; //X3_TITULO
	'Data/hora', ; //X3_TITSPA
	'Data/hora', ; //X3_TITENG
	'Data e hora do registro', ; //X3_DESCRIC
	'Data e hora do registro', ; //X3_DESCSPA
	'Data e hora do registro', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB2', ; //X3_ARQUIVO
	'18', ; //X3_ORDEM
	'ZB2_LOG', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id chamada', ; //X3_TITULO
	'Id chamada', ; //X3_TITSPA
	'Id chamada', ; //X3_TITENG
	'Id da chamada no log (ZB4)', ; //X3_DESCRIC
	'Id da chamada no log (ZB4)', ; //X3_DESCSPA
	'Id da chamada no log (ZB4)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB3', ; //X3_ARQUIVO
	'01', ; //X3_ORDEM
	'ZB3_FILIAL', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Filial', ; //X3_TITULO
	'Filial', ; //X3_TITSPA
	'Filial', ; //X3_TITENG
	'Filial do sistema', ; //X3_DESCRIC
	'Filial do sistema', ; //X3_DESCSPA
	'Filial do sistema', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'033', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB3', ; //X3_ARQUIVO
	'02', ; //X3_ORDEM
	'ZB3_ID', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id', ; //X3_TITULO
	'Id', ; //X3_TITSPA
	'Id', ; //X3_TITENG
	'Fatura ou processo (ZB2)', ; //X3_DESCRIC
	'Fatura ou processo (ZB2)', ; //X3_DESCSPA
	'Fatura ou processo (ZB2)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB3', ; //X3_ARQUIVO
	'03', ; //X3_ORDEM
	'ZB3_ITEM', ; //X3_CAMPO
	'C', ; //X3_TIPO
	4, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Item', ; //X3_TITULO
	'Item', ; //X3_TITSPA
	'Item', ; //X3_TITENG
	'Item', ; //X3_DESCRIC
	'Item', ; //X3_DESCSPA
	'Item', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB3', ; //X3_ARQUIVO
	'04', ; //X3_ORDEM
	'ZB3_REF', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Documento', ; //X3_TITULO
	'Documento', ; //X3_TITSPA
	'Documento', ; //X3_TITENG
	'Titulo (ZB1) ou fatura (ZB2)', ; //X3_DESCRIC
	'Titulo (ZB1) ou fatura (ZB2)', ; //X3_DESCSPA
	'Titulo (ZB1) ou fatura (ZB2)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'01', ; //X3_ORDEM
	'ZB4_FILIAL', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Filial', ; //X3_TITULO
	'Filial', ; //X3_TITSPA
	'Filial', ; //X3_TITENG
	'Filial do sistema', ; //X3_DESCRIC
	'Filial do sistema', ; //X3_DESCSPA
	'Filial do sistema', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'033', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'02', ; //X3_ORDEM
	'ZB4_ID', ; //X3_CAMPO
	'C', ; //X3_TIPO
	9, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Id', ; //X3_TITULO
	'Id', ; //X3_TITSPA
	'Id', ; //X3_TITENG
	'Id da chamada', ; //X3_DESCRIC
	'Id da chamada', ; //X3_DESCSPA
	'Id da chamada', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'03', ; //X3_ORDEM
	'ZB4_API', ; //X3_CAMPO
	'C', ; //X3_TIPO
	2, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'API', ; //X3_TITULO
	'API', ; //X3_TITSPA
	'API', ; //X3_TITENG
	'Numero da API (01 a 08)', ; //X3_DESCRIC
	'Numero da API (01 a 08)', ; //X3_DESCSPA
	'Numero da API (01 a 08)', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'04', ; //X3_ORDEM
	'ZB4_DTHR', ; //X3_CAMPO
	'C', ; //X3_TIPO
	14, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Data/hora', ; //X3_TITULO
	'Data/hora', ; //X3_TITSPA
	'Data/hora', ; //X3_TITENG
	'Data e hora da chamada', ; //X3_DESCRIC
	'Data e hora da chamada', ; //X3_DESCSPA
	'Data e hora da chamada', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'05', ; //X3_ORDEM
	'ZB4_USER', ; //X3_CAMPO
	'C', ; //X3_TIPO
	25, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Usuario', ; //X3_TITULO
	'Usuario', ; //X3_TITSPA
	'Usuario', ; //X3_TITENG
	'Usuario da chamada', ; //X3_DESCRIC
	'Usuario da chamada', ; //X3_DESCSPA
	'Usuario da chamada', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'06', ; //X3_ORDEM
	'ZB4_HTTP', ; //X3_CAMPO
	'C', ; //X3_TIPO
	3, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'HTTP', ; //X3_TITULO
	'HTTP', ; //X3_TITSPA
	'HTTP', ; //X3_TITENG
	'Codigo HTTP devolvido', ; //X3_DESCRIC
	'Codigo HTTP devolvido', ; //X3_DESCSPA
	'Codigo HTTP devolvido', ; //X3_DESCENG
	'@!', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'07', ; //X3_ORDEM
	'ZB4_QTD', ; //X3_CAMPO
	'N', ; //X3_TIPO
	6, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Itens', ; //X3_TITULO
	'Itens', ; //X3_TITSPA
	'Itens', ; //X3_TITENG
	'Itens recebidos', ; //X3_DESCRIC
	'Itens recebidos', ; //X3_DESCSPA
	'Itens recebidos', ; //X3_DESCENG
	'@E 999999', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'08', ; //X3_ORDEM
	'ZB4_QTDERR', ; //X3_CAMPO
	'N', ; //X3_TIPO
	6, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Com erro', ; //X3_TITULO
	'Com erro', ; //X3_TITSPA
	'Com erro', ; //X3_TITENG
	'Itens com erro', ; //X3_DESCRIC
	'Itens com erro', ; //X3_DESCSPA
	'Itens com erro', ; //X3_DESCENG
	'@E 999999', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'S', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'09', ; //X3_ORDEM
	'ZB4_BODY', ; //X3_CAMPO
	'M', ; //X3_TIPO
	10, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Pedido', ; //X3_TITULO
	'Pedido', ; //X3_TITSPA
	'Pedido', ; //X3_TITENG
	'Corpo recebido', ; //X3_DESCRIC
	'Corpo recebido', ; //X3_DESCSPA
	'Corpo recebido', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

aAdd( aSX3, { ;
	'ZB4', ; //X3_ARQUIVO
	'10', ; //X3_ORDEM
	'ZB4_RESP', ; //X3_CAMPO
	'M', ; //X3_TIPO
	10, ; //X3_TAMANHO
	0, ; //X3_DECIMAL
	'Resposta', ; //X3_TITULO
	'Resposta', ; //X3_TITSPA
	'Resposta', ; //X3_TITENG
	'Corpo devolvido', ; //X3_DESCRIC
	'Corpo devolvido', ; //X3_DESCSPA
	'Corpo devolvido', ; //X3_DESCENG
	'', ; //X3_PICTURE
	'', ; //X3_VALID
	'x       x       x       x       x       x       x       x       x       x       x       x       x       x       x x', ; //X3_USADO
	'', ; //X3_RELACAO
	'', ; //X3_F3
	0, ; //X3_NIVEL
	'xxxxxx x', ; //X3_RESERV
	'', ; //X3_CHECK
	'', ; //X3_TRIGGER
	'U', ; //X3_PROPRI
	'N', ; //X3_BROWSE
	'A', ; //X3_VISUAL
	'R', ; //X3_CONTEXT
	'', ; //X3_OBRIGAT
	'', ; //X3_VLDUSER
	'', ; //X3_CBOX
	'', ; //X3_CBOXSPA
	'', ; //X3_CBOXENG
	'', ; //X3_PICTVAR
	'', ; //X3_WHEN
	'', ; //X3_INIBRW
	'', ; //X3_GRPSXG
	'', ; //X3_FOLDER
	'', ; //X3_CONDSQL
	'', ; //X3_CHKSQL
	'', ; //X3_IDXSRV
	'N', ; //X3_ORTOGRA
	'', ; //X3_TELA
	'', ; //X3_POSLGT
	'N', ; //X3_IDXFLD
	'', ; //X3_AGRUP
	'', ; //X3_MODAL
	'', ; //X3_PYME
	'' } ) //X3_INIT

nPosArq := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_ARQUIVO" } )
nPosOrd := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_ORDEM"   } )
nPosCpo := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_CAMPO"   } )
nPosTam := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_TAMANHO" } )
nPosSXG := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_GRPSXG"  } )

aSort( aSX3,,, { |x,y| x[nPosArq]+x[nPosOrd]+x[nPosCpo] < y[nPosArq]+y[nPosOrd]+y[nPosCpo] } )

oProcess:SetRegua2( Len( aSX3 ) )

dbSelectArea( "SX3" )
dbSetOrder( 2 )
cAliasAtu := ""

For nI := 1 To Len( aSX3 )

	//
	// Verifica se o campo faz parte de um grupo e ajusta tamanho
	//
	If !Empty( aSX3[nI][nPosSXG] )
		SXG->( dbSetOrder( 1 ) )
		If SXG->( MSSeek( aSX3[nI][nPosSXG] ) )
			If aSX3[nI][nPosTam] <> SXG->XG_SIZE
				aSX3[nI][nPosTam] := SXG->XG_SIZE
				AutoGrLog( "O tamanho do campo " + aSX3[nI][nPosCpo] + " foi mantido em [" + ;
				AllTrim( Str( SXG->XG_SIZE ) ) + "]" + CRLF + ;
				" por pertencer ao grupo de campos [" + SXG->XG_GRUPO + "]" + CRLF )
			EndIf
		EndIf
	EndIf

	SX3->( dbSetOrder( 2 ) )

	If aScan( aArqUpd, { |x| x == aSX3[nI][nPosArq] } ) == 0
		aAdd( aArqUpd, aSX3[nI][nPosArq] )
	EndIf

	If !SX3->( dbSeek( PadR( aSX3[nI][nPosCpo], nTamSeek ) ) )

		//
		// Busca ultima ocorrencia do alias
		//
		If ( aSX3[nI][nPosArq] <> cAliasAtu )
			cSeqAtu   := "00"
			cAliasAtu := aSX3[nI][nPosArq]

			dbSetOrder( 1 )
			SX3->( dbSeek( cAliasAtu + "ZZ", .T. ) )
			dbSkip( -1 )

			If ( SX3->X3_ARQUIVO == cAliasAtu )
				cSeqAtu := SX3->X3_ORDEM
			EndIf

			nSeqAtu := Val( RetAsc( cSeqAtu, 3, .F. ) )
		EndIf

		nSeqAtu++
		cSeqAtu := RetAsc( Str( nSeqAtu ), 2, .T. )

		RecLock( "SX3", .T. )
		For nJ := 1 To Len( aSX3[nI] )
			If     nJ == nPosOrd
				SX3->( FieldPut( FieldPos( aEstrut[nJ][1] ), cSeqAtu ) )

			ElseIf aEstrut[nJ][2] > 0
				SX3->( FieldPut( FieldPos( aEstrut[nJ][1] ), aSX3[nI][nJ] ) )

			EndIf
		Next nJ

		dbCommit()
		MsUnLock()

		AutoGrLog( "Criado campo " + aSX3[nI][nPosCpo] )

	EndIf

	oProcess:IncRegua2( "Atualizando Campos de Tabelas (SX3) ..." )

Next nI

AutoGrLog( CRLF + "Final da Atualizacao" + " SX3" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL

//------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSIX

Funcao de processamento da gravacao do SIX - Indices

@author UPDATE gerado automaticamente
@obs    Aplicador de SXs
@version 1.0
/*/
//------------------------------------------------------------------
Static Function FSAtuSIX()
Local aEstrut   := {}
Local aSIX      := {}
Local lAlt      := .F.
Local lDelInd   := .F.
Local nI        := 0
Local nJ        := 0
Local nPosInd   := 0
Local nPosOrd   := 0
Local nPosChv   := 0

AutoGrLog( "Inicio da Atualizacao" + " SIX" + CRLF )

aEstrut := { { "INDICE", 0 }, { "ORDEM", 0 }, { "CHAVE", 0 }, { "DESCRICAO", 0 }, ;
             { "DESCSPA", 0 }, { "DESCENG", 0 }, { "PROPRI", 0 }, { "F3", 0 }, ;
             { "NICKNAME", 0 }, { "SHOWPESQ", 0 } }

aEval( aEstrut, { |x| x[2] := SIX->( FieldPos( x[1] ) ) } )

//
// Indices (aSIX)
//
aAdd( aSIX, { ;
	'ZB0', ; //INDICE
	'1', ; //ORDEM
	'ZB0_FILIAL+ZB0_IDTRAN', ; //CHAVE
	'Id transacao', ; //DESCRICAO
	'Id transacao', ; //DESCSPA
	'Id transacao', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB0', ; //INDICE
	'2', ; //ORDEM
	'ZB0_FILIAL+ZB0_OPER+ZB0_NRNF', ; //CHAVE
	'Operacao + nrNfFornec', ; //DESCRICAO
	'Operacao + nrNfFornec', ; //DESCSPA
	'Operacao + nrNfFornec', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB0', ; //INDICE
	'3', ; //ORDEM
	'ZB0_FILIAL+ZB0_TRORIG', ; //CHAVE
	'Transacao original', ; //DESCRICAO
	'Transacao original', ; //DESCSPA
	'Transacao original', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB1', ; //INDICE
	'1', ; //ORDEM
	'ZB1_FILIAL+ZB1_ID', ; //CHAVE
	'Id titulo', ; //DESCRICAO
	'Id titulo', ; //DESCSPA
	'Id titulo', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB1', ; //INDICE
	'2', ; //ORDEM
	'ZB1_FILIAL+ZB1_IDTRAN+ZB1_CART', ; //CHAVE
	'Transacao + carteira', ; //DESCRICAO
	'Transacao + carteira', ; //DESCSPA
	'Transacao + carteira', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB1', ; //INDICE
	'3', ; //ORDEM
	'ZB1_FILIAL+ZB1_IDAGR', ; //CHAVE
	'Fatura', ; //DESCRICAO
	'Fatura', ; //DESCSPA
	'Fatura', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB2', ; //INDICE
	'1', ; //ORDEM
	'ZB2_FILIAL+ZB2_ID', ; //CHAVE
	'Id', ; //DESCRICAO
	'Id', ; //DESCSPA
	'Id', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB2', ; //INDICE
	'2', ; //ORDEM
	'ZB2_FILIAL+ZB2_OPER+ZB2_HASH', ; //CHAVE
	'Operacao + hash', ; //DESCRICAO
	'Operacao + hash', ; //DESCSPA
	'Operacao + hash', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB2', ; //INDICE
	'3', ; //ORDEM
	'ZB2_FILIAL+ZB2_IDBX', ; //CHAVE
	'Processo de baixa', ; //DESCRICAO
	'Processo de baixa', ; //DESCSPA
	'Processo de baixa', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB3', ; //INDICE
	'1', ; //ORDEM
	'ZB3_FILIAL+ZB3_ID+ZB3_ITEM', ; //CHAVE
	'Id + item', ; //DESCRICAO
	'Id + item', ; //DESCSPA
	'Id + item', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB3', ; //INDICE
	'2', ; //ORDEM
	'ZB3_FILIAL+ZB3_REF+ZB3_ID', ; //CHAVE
	'Documento', ; //DESCRICAO
	'Documento', ; //DESCSPA
	'Documento', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB4', ; //INDICE
	'1', ; //ORDEM
	'ZB4_FILIAL+ZB4_ID', ; //CHAVE
	'Id chamada', ; //DESCRICAO
	'Id chamada', ; //DESCSPA
	'Id chamada', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

aAdd( aSIX, { ;
	'ZB4', ; //INDICE
	'2', ; //ORDEM
	'ZB4_FILIAL+ZB4_API+ZB4_DTHR', ; //CHAVE
	'API + data/hora', ; //DESCRICAO
	'API + data/hora', ; //DESCSPA
	'API + data/hora', ; //DESCENG
	'U', ; //PROPRI
	'', ; //F3
	'', ; //NICKNAME
	'S' } ) //SHOWPESQ

nPosInd := aScan( aEstrut, { |x| AllTrim( x[1] ) == "INDICE" } )
nPosOrd := aScan( aEstrut, { |x| AllTrim( x[1] ) == "ORDEM"  } )
nPosChv := aScan( aEstrut, { |x| AllTrim( x[1] ) == "CHAVE"  } )

oProcess:SetRegua2( Len( aSIX ) )

dbSelectArea( "SIX" )
dbSetOrder( 1 )

For nI := 1 To Len( aSIX )

	lAlt    := .F.
	lDelInd := .F.

	If !SIX->( dbSeek( aSIX[nI][nPosInd] + aSIX[nI][nPosOrd] ) )
		AutoGrLog( "Indice criado " + aSIX[nI][nPosInd] + "/" + aSIX[nI][nPosOrd] + " - " + aSIX[nI][nPosChv] )
	Else
		lAlt := .T.

		If aScan( aArqUpd, { |x| x == aSIX[nI][nPosInd] } ) == 0
			aAdd( aArqUpd, aSIX[nI][nPosInd] )
		EndIf

		If !( StrTran( Upper( AllTrim( SIX->CHAVE ) ), " ", "" ) == ;
		      StrTran( Upper( AllTrim( aSIX[nI][nPosChv] ) ), " ", "" ) )
			AutoGrLog( "Chave do indice alterada " + aSIX[nI][nPosInd] + "/" + aSIX[nI][nPosOrd] + " - " + aSIX[nI][nPosChv] )
			lDelInd := .T. // Se for alteracao precisa apagar o indice do banco
		EndIf
	EndIf

	RecLock( "SIX", !lAlt )
	For nJ := 1 To Len( aSIX[nI] )
		If aEstrut[nJ][2] > 0
			SIX->( FieldPut( aEstrut[nJ][2], aSIX[nI][nJ] ) )
		EndIf
	Next nJ

	dbCommit()
	MsUnLock()

	If lDelInd
		TcInternal( 60, RetSqlName( aSIX[nI][nPosInd] ) + "|" + RetSqlName( aSIX[nI][nPosInd] ) + aSIX[nI][nPosOrd] )
	EndIf

	oProcess:IncRegua2( "Atualizando Indices (SIX) ..." )

Next nI

AutoGrLog( CRLF + "Final da Atualizacao" + " SIX" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL

//------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSX6

Funcao de processamento da gravacao do SX6 - Parametros

@author UPDATE gerado automaticamente
@obs    Aplicador de SXs
@version 1.0
/*/
//------------------------------------------------------------------
Static Function FSAtuSX6()
Local aEstrut   := {}
Local aSX6      := {}
Local nI        := 0
Local nJ        := 0
Local nPosFil   := 0
Local nPosVar   := 0
Local nTamFil   := Len( SX6->X6_FIL )
Local nTamVar   := Len( SX6->X6_VAR )

AutoGrLog( "Inicio da Atualizacao" + " SX6" + CRLF )

aEstrut := { { "X6_FIL", 0 }, { "X6_VAR", 0 }, { "X6_TIPO", 0 }, { "X6_DESCRIC", 0 }, ;
             { "X6_DSCSPA", 0 }, { "X6_DSCENG", 0 }, { "X6_DESC1", 0 }, { "X6_DSCSPA1", 0 }, ;
             { "X6_DSCENG1", 0 }, { "X6_DESC2", 0 }, { "X6_DSCSPA2", 0 }, { "X6_DSCENG2", 0 }, ;
             { "X6_CONTEUD", 0 }, { "X6_CONTSPA", 0 }, { "X6_CONTENG", 0 }, { "X6_PROPRI", 0 }, ;
             { "X6_VALID", 0 }, { "X6_INIT", 0 }, { "X6_DEFPOR", 0 }, { "X6_DEFSPA", 0 }, ;
             { "X6_DEFENG", 0 }, { "X6_PYME", 0 } }

aEval( aEstrut, { |x| x[2] := SX6->( FieldPos( x[1] ) ) } )

//
// Parametros (aSX6)
//
aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBPREFR', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: prefixo titulos a receber', ; //X6_DESCRIC
	'TruckPag: prefixo titulos a receber', ; //X6_DSCSPA
	'TruckPag: prefixo titulos a receber', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPG', ; //X6_CONTEUD
	'TPG', ; //X6_CONTSPA
	'TPG', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBPREFP', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: prefixo titulos a pagar', ; //X6_DESCRIC
	'TruckPag: prefixo titulos a pagar', ; //X6_DSCSPA
	'TruckPag: prefixo titulos a pagar', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPG', ; //X6_CONTEUD
	'TPG', ; //X6_CONTSPA
	'TPG', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBTIPOR', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: tipo provisorio a receber', ; //X6_DESCRIC
	'TruckPag: tipo provisorio a receber', ; //X6_DSCSPA
	'TruckPag: tipo provisorio a receber', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'DP', ; //X6_CONTEUD
	'DP', ; //X6_CONTSPA
	'DP', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBTIPOP', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: tipo provisorio a pagar', ; //X6_DESCRIC
	'TruckPag: tipo provisorio a pagar', ; //X6_DSCSPA
	'TruckPag: tipo provisorio a pagar', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'DP', ; //X6_CONTEUD
	'DP', ; //X6_CONTSPA
	'DP', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBNATRP', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: natureza provisorio a receber', ; //X6_DESCRIC
	'TruckPag: natureza provisorio a receber', ; //X6_DSCSPA
	'TruckPag: natureza provisorio a receber', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPGPRVREC', ; //X6_CONTEUD
	'TPGPRVREC', ; //X6_CONTSPA
	'TPGPRVREC', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBNATPP', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: natureza provisorio a pagar', ; //X6_DESCRIC
	'TruckPag: natureza provisorio a pagar', ; //X6_DSCSPA
	'TruckPag: natureza provisorio a pagar', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPGPRVPAG', ; //X6_CONTEUD
	'TPGPRVPAG', ; //X6_CONTSPA
	'TPGPRVPAG', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBNATFR', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: natureza fatura a receber', ; //X6_DESCRIC
	'TruckPag: natureza fatura a receber', ; //X6_DSCSPA
	'TruckPag: natureza fatura a receber', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPGFATREC', ; //X6_CONTEUD
	'TPGFATREC', ; //X6_CONTSPA
	'TPGFATREC', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBNATFP', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: natureza fatura a pagar', ; //X6_DESCRIC
	'TruckPag: natureza fatura a pagar', ; //X6_DSCSPA
	'TruckPag: natureza fatura a pagar', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPGFATPAG', ; //X6_CONTEUD
	'TPGFATPAG', ; //X6_CONTSPA
	'TPGFATPAG', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBPRFFR', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: prefixo fatura a receber', ; //X6_DESCRIC
	'TruckPag: prefixo fatura a receber', ; //X6_DSCSPA
	'TruckPag: prefixo fatura a receber', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPF', ; //X6_CONTEUD
	'TPF', ; //X6_CONTSPA
	'TPF', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBPRFFP', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: prefixo fatura a pagar', ; //X6_DESCRIC
	'TruckPag: prefixo fatura a pagar', ; //X6_DSCSPA
	'TruckPag: prefixo fatura a pagar', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPF', ; //X6_CONTEUD
	'TPF', ; //X6_CONTSPA
	'TPF', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBTIPFT', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: tipo do titulo da fatura', ; //X6_DESCRIC
	'TruckPag: tipo do titulo da fatura', ; //X6_DSCSPA
	'TruckPag: tipo do titulo da fatura', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'FT', ; //X6_CONTEUD
	'FT', ; //X6_CONTSPA
	'FT', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBCOND', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: condicao fatura (sem cadastro)', ; //X6_DESCRIC
	'TruckPag: condicao fatura (sem cadastro)', ; //X6_DSCSPA
	'TruckPag: condicao fatura (sem cadastro)', ; //X6_DSCENG
	'Precisa ser de parcela unica (P-04)', ; //X6_DESC1
	'Precisa ser de parcela unica (P-04)', ; //X6_DSCSPA1
	'Precisa ser de parcela unica (P-04)', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'TPG', ; //X6_CONTEUD
	'TPG', ; //X6_CONTSPA
	'TPG', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBBCOR', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: banco/ag/conta baixa a receber', ; //X6_DESCRIC
	'TruckPag: banco/ag/conta baixa a receber', ; //X6_DSCSPA
	'TruckPag: banco/ag/conta baixa a receber', ; //X6_DSCENG
	'Separados por barra (P-05)', ; //X6_DESC1
	'Separados por barra (P-05)', ; //X6_DSCSPA1
	'Separados por barra (P-05)', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'001/00000/00000001', ; //X6_CONTEUD
	'001/00000/00000001', ; //X6_CONTSPA
	'001/00000/00000001', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBBCOP', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: banco/ag/conta baixa a pagar', ; //X6_DESCRIC
	'TruckPag: banco/ag/conta baixa a pagar', ; //X6_DSCSPA
	'TruckPag: banco/ag/conta baixa a pagar', ; //X6_DSCENG
	'Separados por barra (P-05)', ; //X6_DESC1
	'Separados por barra (P-05)', ; //X6_DSCSPA1
	'Separados por barra (P-05)', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'001/00000/00000001', ; //X6_CONTEUD
	'001/00000/00000001', ; //X6_CONTSPA
	'001/00000/00000001', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBMOTBX', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: motivo da baixa das faturas', ; //X6_DESCRIC
	'TruckPag: motivo da baixa das faturas', ; //X6_DSCSPA
	'TruckPag: motivo da baixa das faturas', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'NOR', ; //X6_CONTEUD
	'NOR', ; //X6_CONTSPA
	'NOR', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBRETOR', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: retorno 1=item a item 2=MIT', ; //X6_DESCRIC
	'TruckPag: retorno 1=item a item 2=MIT', ; //X6_DSCSPA
	'TruckPag: retorno 1=item a item 2=MIT', ; //X6_DSCENG
	'1=HTTP 200 e eco nrNfFornec (P-06)', ; //X6_DESC1
	'1=HTTP 200 e eco nrNfFornec (P-06)', ; //X6_DSCSPA1
	'1=HTTP 200 e eco nrNfFornec (P-06)', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'1', ; //X6_CONTEUD
	'1', ; //X6_CONTSPA
	'1', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBIDEMP', ; //X6_VAR
	'L', ; //X6_TIPO
	'TruckPag: nrNfFornec chave anti-duplicar', ; //X6_DESCRIC
	'TruckPag: nrNfFornec chave anti-duplicar', ; //X6_DSCSPA
	'TruckPag: nrNfFornec chave anti-duplicar', ; //X6_DSCENG
	'Reenvio igual = mesmos ids; outro recusa', ; //X6_DESC1
	'Reenvio igual = mesmos ids; outro recusa', ; //X6_DSCSPA1
	'Reenvio igual = mesmos ids; outro recusa', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'.T.', ; //X6_CONTEUD
	'.T.', ; //X6_CONTSPA
	'.T.', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBLOTE', ; //X6_VAR
	'N', ; //X6_TIPO
	'TruckPag: max. transacoes por chamada', ; //X6_DESCRIC
	'TruckPag: max. transacoes por chamada', ; //X6_DSCSPA
	'TruckPag: max. transacoes por chamada', ; //X6_DSCENG
	'', ; //X6_DESC1
	'', ; //X6_DSCSPA1
	'', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'1000', ; //X6_CONTEUD
	'1000', ; //X6_CONTSPA
	'1000', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

aAdd( aSX6, { ;
	'  ', ; //X6_FIL
	'MV_ZBFIL', ; //X6_VAR
	'C', ; //X6_TIPO
	'TruckPag: filial (vazio = da chamada)', ; //X6_DESCRIC
	'TruckPag: filial (vazio = da chamada)', ; //X6_DSCSPA
	'TruckPag: filial (vazio = da chamada)', ; //X6_DSCENG
	'P-03', ; //X6_DESC1
	'P-03', ; //X6_DSCSPA1
	'P-03', ; //X6_DSCENG1
	'', ; //X6_DESC2
	'', ; //X6_DSCSPA2
	'', ; //X6_DSCENG2
	'', ; //X6_CONTEUD
	'', ; //X6_CONTSPA
	'', ; //X6_CONTENG
	'U', ; //X6_PROPRI
	'', ; //X6_VALID
	'', ; //X6_INIT
	'', ; //X6_DEFPOR
	'', ; //X6_DEFSPA
	'', ; //X6_DEFENG
	'' } ) //X6_PYME

nPosFil := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X6_FIL" } )
nPosVar := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X6_VAR" } )

oProcess:SetRegua2( Len( aSX6 ) )

dbSelectArea( "SX6" )
dbSetOrder( 1 )

For nI := 1 To Len( aSX6 )

	oProcess:IncRegua2( "Atualizando Parametros (SX6) ..." )

	If !SX6->( dbSeek( PadR( aSX6[nI][nPosFil], nTamFil ) + PadR( aSX6[nI][nPosVar], nTamVar ) ) )

		RecLock( "SX6", .T. )
		For nJ := 1 To Len( aSX6[nI] )
			If aEstrut[nJ][2] > 0
				SX6->( FieldPut( aEstrut[nJ][2], aSX6[nI][nJ] ) )
			EndIf
		Next nJ

		dbCommit()
		MsUnLock()

		AutoGrLog( "Foi incluido o parametro " + aSX6[nI][nPosFil] + aSX6[nI][nPosVar] )

	EndIf

Next nI

AutoGrLog( CRLF + "Final da Atualizacao" + " SX6" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL


Static Function FSAtuHlp()
Local aHlpPor   := {}
Local aHlpEng   := {}
Local aHlpSpa   := {}

AutoGrLog( "Ínicio da Atualização" + " " + "Helps de Campos" + CRLF )


oProcess:IncRegua2( "Atualizando Helps de Campos ..." )

//
// (sem helps de campo neste aplicador)
//
AutoGrLog( CRLF + "Final da Atualização" + " " + "Helps de Campos" + CRLF + Replicate( "-", 128 ) + CRLF )

Return {}


//--------------------------------------------------------------------
/*/{Protheus.doc} EscEmpresa
Função genérica para escolha de Empresa, montada pelo SM0

@return aRet Vetor contendo as seleções feitas.
             Se não for marcada nenhuma o vetor volta vazio

@author TOTVS
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function EscEmpresa()

//---------------------------------------------
// Parâmetro  nTipo
// 1 - Monta com Todas Empresas/Filiais
// 2 - Monta só com Empresas
// 3 - Monta só com Filiais de uma Empresa
//
// Parâmetro  aMarcadas
// Vetor com Empresas/Filiais pré marcadas
//
// Parâmetro  cEmpSel
// Empresa que será usada para montar seleção
//---------------------------------------------
Local   aRet      := {}
Local   aSalvAmb  := GetArea()
Local   aSalvSM0  := {}
Local   aVetor    := {}
Local   cMascEmp  := "??"
Local   cVar      := ""
Local   lChk      := .F.
Local   lOk       := .F.
Local   lTeveMarc := .F.
Local   oNo       := LoadBitmap( GetResources(), "LBNO" )
Local   oOk       := LoadBitmap( GetResources(), "LBOK" )
Local   oDlg, oChkMar, oLbx, oMascEmp, oSay
Local   oButDMar, oButInv, oButMarc, oButOk, oButCanc

Local   aMarcadas := {}


If !MyOpenSm0(.F.)
	Return aRet
EndIf


dbSelectArea( "SM0" )
aSalvSM0 := SM0->( GetArea() )
dbSetOrder( 1 )
dbGoTop()

While !SM0->( EOF() )

	If aScan( aVetor, {|x| x[2] == SM0->M0_CODIGO} ) == 0
		aAdd(  aVetor, { aScan( aMarcadas, {|x| x[1] == SM0->M0_CODIGO .and. x[2] == SM0->M0_CODFIL} ) > 0, SM0->M0_CODIGO, SM0->M0_CODFIL, SM0->M0_NOME, SM0->M0_FILIAL } )
	EndIf

	dbSkip()
End

RestArea( aSalvSM0 )

Define MSDialog  oDlg Title "" From 0, 0 To 280, 395 Pixel

oDlg:cToolTip := "Tela para Múltiplas Seleções de Empresas/Filiais"

oDlg:cTitle   := "Selecione a(s) Empresa(s) para Atualização"

@ 10, 10 Listbox  oLbx Var  cVar Fields Header " ", " ", "Empresa" Size 178, 095 Of oDlg Pixel
oLbx:SetArray(  aVetor )
oLbx:bLine := {|| {IIf( aVetor[oLbx:nAt, 1], oOk, oNo ), ;
aVetor[oLbx:nAt, 2], ;
aVetor[oLbx:nAt, 4]}}
oLbx:BlDblClick := { || aVetor[oLbx:nAt, 1] := !aVetor[oLbx:nAt, 1], VerTodos( aVetor, @lChk, oChkMar ), oChkMar:Refresh(), oLbx:Refresh()}
oLbx:cToolTip   :=  oDlg:cTitle
oLbx:lHScroll   := .F. // NoScroll

@ 112, 10 CheckBox oChkMar Var  lChk Prompt "Todos" Message "Marca / Desmarca"+ CRLF + "Todos" Size 40, 007 Pixel Of oDlg;
on Click MarcaTodos( lChk, @aVetor, oLbx )

// Marca/Desmarca por mascara
@ 113, 51 Say   oSay Prompt "Empresa" Size  40, 08 Of oDlg Pixel
@ 112, 80 MSGet oMascEmp Var  cMascEmp Size  05, 05 Pixel Picture "@!"  Valid (  cMascEmp := StrTran( cMascEmp, " ", "?" ), oMascEmp:Refresh(), .T. ) ;
Message "Máscara Empresa ( ?? )"  Of oDlg
oSay:cToolTip := oMascEmp:cToolTip

@ 128, 10 Button oButInv    Prompt "&Inverter"  Size 32, 12 Pixel Action ( InvSelecao( @aVetor, oLbx ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
Message "Inverter Seleção" Of oDlg
oButInv:SetCss( CSSBOTAO )
@ 128, 50 Button oButMarc   Prompt "&Marcar"    Size 32, 12 Pixel Action ( MarcaMas( oLbx, aVetor, cMascEmp, .T. ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
Message "Marcar usando" + CRLF + "máscara ( ?? )"    Of oDlg
oButMarc:SetCss( CSSBOTAO )
@ 128, 80 Button oButDMar   Prompt "&Desmarcar" Size 32, 12 Pixel Action ( MarcaMas( oLbx, aVetor, cMascEmp, .F. ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
Message "Desmarcar usando" + CRLF + "máscara ( ?? )" Of oDlg
oButDMar:SetCss( CSSBOTAO )
@ 112, 157  Button oButOk   Prompt "Processar"  Size 32, 12 Pixel Action (  RetSelecao( @aRet, aVetor ), IIf( Len( aRet ) > 0, oDlg:End(), MsgStop( "Ao menos um grupo deve ser selecionado", "ATVTPG01" ) ) ) ;
Message "Confirma a seleção e efetua" + CRLF + "o processamento" Of oDlg
oButOk:SetCss( CSSBOTAO )
@ 128, 157  Button oButCanc Prompt "Cancelar"   Size 32, 12 Pixel Action ( IIf( lTeveMarc, aRet :=  aMarcadas, .T. ), oDlg:End() ) ;
Message "Cancela o processamento" + CRLF + "e abandona a aplicação" Of oDlg
oButCanc:SetCss( CSSBOTAO )

Activate MSDialog  oDlg Center

RestArea( aSalvAmb )
dbSelectArea( "SM0" )
dbCloseArea()

Return  aRet


//--------------------------------------------------------------------
/*/{Protheus.doc} MarcaTodos
Função auxiliar para marcar/desmarcar todos os ítens do ListBox ativo

@param lMarca  Contéudo para marca .T./.F.
@param aVetor  Vetor do ListBox
@param oLbx    Objeto do ListBox

@author TOTVS
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function MarcaTodos( lMarca, aVetor, oLbx )
Local  nI := 0

For nI := 1 To Len( aVetor )
	aVetor[nI][1] := lMarca
Next nI

oLbx:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} InvSelecao
Função auxiliar para inverter a seleção do ListBox ativo

@param aVetor  Vetor do ListBox
@param oLbx    Objeto do ListBox

@author TOTVS
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function InvSelecao( aVetor, oLbx )
Local  nI := 0

For nI := 1 To Len( aVetor )
	aVetor[nI][1] := !aVetor[nI][1]
Next nI

oLbx:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} RetSelecao
Função auxiliar que monta o retorno com as seleções

@param aRet    Array que terá o retorno das seleções (é alterado internamente)
@param aVetor  Vetor do ListBox

@author TOTVS
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function RetSelecao( aRet, aVetor )
Local  nI    := 0

aRet := {}
For nI := 1 To Len( aVetor )
	If aVetor[nI][1]
		aAdd( aRet, { aVetor[nI][2] , aVetor[nI][3], aVetor[nI][2] +  aVetor[nI][3] } )
	EndIf
Next nI

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} MarcaMas
Função para marcar/desmarcar usando máscaras

@param oLbx     Objeto do ListBox
@param aVetor   Vetor do ListBox
@param cMascEmp Campo com a máscara (???)
@param lMarDes  Marca a ser atribuída .T./.F.

@author TOTVS
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function MarcaMas( oLbx, aVetor, cMascEmp, lMarDes )
Local cPos1 := SubStr( cMascEmp, 1, 1 )
Local cPos2 := SubStr( cMascEmp, 2, 1 )
Local nPos  := oLbx:nAt
Local nZ    := 0

For nZ := 1 To Len( aVetor )
	If cPos1 == "?" .or. SubStr( aVetor[nZ][2], 1, 1 ) == cPos1
		If cPos2 == "?" .or. SubStr( aVetor[nZ][2], 2, 1 ) == cPos2
			aVetor[nZ][1] := lMarDes
		EndIf
	EndIf
Next

oLbx:nAt := nPos
oLbx:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} VerTodos
Função auxiliar para verificar se estão todos marcados ou não

@param aVetor   Vetor do ListBox
@param lChk     Marca do CheckBox do marca todos (referncia)
@param oChkMar  Objeto de CheckBox do marca todos

@author TOTVS
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function VerTodos( aVetor, lChk, oChkMar )
Local lTTrue := .T.
Local nI     := 0

For nI := 1 To Len( aVetor )
	lTTrue := IIf( !aVetor[nI][1], .F., lTTrue )
Next nI

lChk := IIf( lTTrue, .T., .F. )
oChkMar:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} MyOpenSM0

Função de processamento abertura do SM0 modo exclusivo

@author UPDATE gerado automaticamente
@since  12/11/2024
@obs    Aplicador de SXs
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function MyOpenSM0( lShared )
Local lOpen := .F.
Local nLoop := 0

If FindFunction( "OpenSM0Excl" )
	For nLoop := 1 To 20
		If OpenSM0Excl(,.F.)
			lOpen := .T.
			Exit
		EndIf
		Sleep( 500 )
	Next nLoop
Else
	For nLoop := 1 To 20
		dbUseArea( .T., , "SIGAMAT.EMP", "SM0", lShared, .F. )

		If !Empty( Select( "SM0" ) )
			lOpen := .T.
			dbSetIndex( "SIGAMAT.IND" )
			Exit
		EndIf
		Sleep( 500 )
	Next nLoop
EndIf

If !lOpen
	MsgStop( "Não foi possível a abertura da tabela " + ;
	IIf( lShared, "de empresas (SM0).", "de empresas (SM0) de forma exclusiva." ), "ATENÇÃO" )
EndIf

Return lOpen


//--------------------------------------------------------------------
/*/{Protheus.doc} LeLog

Função de leitura do LOG gerado com limitacao de string

@author UPDATE gerado automaticamente
@since  12/11/2024
@obs    Aplicador de SXs
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function LeLog()
Local cRet  := ""
Local cFile := NomeAutoLog()
Local cAux  := ""

FT_FUSE( cFile )
FT_FGOTOP()

While !FT_FEOF()

	cAux := FT_FREADLN()

	If Len( cRet ) + Len( cAux ) < 1048000
		cRet += cAux + CRLF
	Else
		cRet += CRLF
		cRet += Replicate( "=" , 128 ) + CRLF
		cRet += "Tamanho de exibição maxima do LOG alcançado." + CRLF
		cRet += "LOG Completo no arquivo " + cFile + CRLF
		cRet += Replicate( "=" , 128 ) + CRLF
		Exit
	EndIf

	FT_FSKIP()
End

FT_FUSE()

Return cRet


/////////////////////////////////////////////////////////////////////////////

//--------------------------------------------------------------------
// ZTPGPRC - regua vazia para rodar o aplicador em job (sem tela). Ajuste TruckPag 24/10/2026.
//--------------------------------------------------------------------
Class ZTPGPRC
	Method New() Constructor
	Method SetRegua1( nTot )
	Method IncRegua1( cMsg )
	Method SetRegua2( nTot )
	Method IncRegua2( cMsg )
EndClass

Method New() Class ZTPGPRC
Return Self

Method SetRegua1( nTot ) Class ZTPGPRC
Return Nil

Method IncRegua1( cMsg ) Class ZTPGPRC
	FwLogMsg( "INFO", , "ATVTPG01", , , , cValToChar( cMsg ) )
Return Nil

Method SetRegua2( nTot ) Class ZTPGPRC
Return Nil

Method IncRegua2( cMsg ) Class ZTPGPRC
Return Nil
