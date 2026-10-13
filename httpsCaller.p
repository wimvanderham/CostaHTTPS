
/*------------------------------------------------------------------------
    File        : httpsCaller.p
    Purpose     : Implementazione procedure per le chiamate HTTP e HTTPS

    Syntax      :

    Description : Super procedure per chiamate HTTP e HTTPS

    Author(s)   : Wim van der Ham
    Created     : Fri Sep 04 16:11:19 CEST 2026
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

BLOCK-LEVEL ON ERROR UNDO, THROW.

USING OpenEdge.Core.String.
USING OpenEdge.Core.Memptr.
USING OpenEdge.Core.WidgetHandle.
USING OpenEdge.Net.HTTP.HttpHeaderBuilder.
USING OpenEdge.Net.HTTP.IHttpClient.
USING OpenEdge.Net.HTTP.IHttpRequest.
USING OpenEdge.Net.HTTP.IHttpResponse.
USING OpenEdge.Net.HTTP.RequestBuilder.
USING OpenEdge.Net.HTTP.Credentials. 
USING OpenEdge.Net.MessagePart.
USING OpenEdge.Net.MultipartEntity.
USING OpenEdge.Net.HTTP.HttpHeader.
USING OpenEdge.Net.HTTP.ClientBuilder.
USING OpenEdge.Net.HTTP.Filter.Writer.BodyWriterRegistry.
USING OpenEdge.Net.HTTP.Filter.Payload.XmlBodyWriter.
USING Progress.Json.ObjectModel.JsonObject.
USING Progress.Lang.*.


/* Temp-table per leggere un qualsiasi documento XML */
DEFINE TEMP-TABLE ttXMLNode NO-UNDO 
   FIELD IDXMLNode  AS INTEGER
   FIELD XMLLevel   AS INTEGER 
   FIELD XMLPath    AS CHARACTER FORMAT "X(120)" 
   FIELD XMLName    AS CHARACTER FORMAT "X(30)"
   FIELD XMLValue   AS CHARACTER FORMAT "X(80)"
   FIELD XMLBLOB    AS BLOB  
   FIELD lProcessed AS LOGICAL 
   FIELD lOk        AS LOGICAL 
   FIELD cMessage   AS CHARACTER FORMAT "X(120)"
   INDEX indID IS UNIQUE IDXMLNode.

/* Variabili per leggere documento XML */
DEFINE VARIABLE lvcCurrentElement    AS CHARACTER NO-UNDO.
DEFINE VARIABLE lvcCurrentPath       AS CHARACTER NO-UNDO.
DEFINE VARIABLE lvcCurrentCharacters AS CHARACTER NO-UNDO.
DEFINE VARIABLE lviCurrentLevel      AS INTEGER   NO-UNDO.
DEFINE VARIABLE lviCurrentNode       AS INTEGER   NO-UNDO.
DEFINE VARIABLE lvcLongChar          AS LONGCHAR  NO-UNDO.

/* ********************  Preprocessor Definitions  ******************** */


/* ***************************  Main Block  *************************** */



/* **********************  Internal Procedures  *********************** */

PROCEDURE httpPostGen:
/*------------------------------------------------------------------------------
 Purpose: Chiamata POST con HTTP
 Notes:   Sostituisce util-htp-post-gen in sp-util.p
------------------------------------------------------------------------------*/
DEFINE INPUT  PARAMETER ipcHost     AS CHARACTER NO-UNDO.
DEFINE INPUT  PARAMETER ipiPort     AS INTEGER   NO-UNDO.
DEFINE INPUT  PARAMETER ipcPath     AS CHARACTER NO-UNDO.
DEFINE INPUT  PARAMETER ipcMessage  AS LONGCHAR  NO-UNDO.
DEFINE INPUT  PARAMETER ipiTimeOut  AS INTEGER   NO-UNDO.
DEFINE OUTPUT PARAMETER opcResponse AS LONGCHAR  NO-UNDO.
DEFINE OUTPUT PARAMETER oplOk       AS LOGICAL   NO-UNDO.
DEFINE OUTPUT PARAMETER opcMessage  AS CHARACTER NO-UNDO.

DEFINE VARIABLE oClient      AS IHttpClient   NO-UNDO.
DEFINE VARIABLE oRequest     AS IHttpRequest  NO-UNDO.
DEFINE VARIABLE oHeader      AS HttpHeader    NO-UNDO.
DEFINE VARIABLE oRequestBody AS STRING        NO-UNDO.
DEFINE VARIABLE oResponse    AS IHttpResponse NO-UNDO.
DEFINE VARIABLE oPayLoad     AS JsonObject    NO-UNDO.
DEFINE VARIABLE oEntity      AS Object        NO-UNDO.
DEFINE VARIABLE oJsonEntity  AS JsonObject    NO-UNDO.

DEFINE VARIABLE cPath     AS CHARACTER     NO-UNDO.
DEFINE VARIABLE cURL      AS CHARACTER     NO-UNDO.

   oClient = ClientBuilder:Build():Client.

   ASSIGN 
      cPath = ipcPath
      cURL  = SUBSTITUTE ("http://&1:&2/&3",
                          ipcHost,
                          ipiPort,
                          cPath)
   .
   
   oRequestBody = NEW STRING (ipcMessage).                          
                             
   oRequest = RequestBuilder:Post(cURL, oRequestBody)
       :ContentType("application/x-www-form-urlencoded")
       :Request.
      
   oResponse = oClient:Execute(oRequest).

   IF oResponse:StatusCode NE 200 THEN DO:
      ASSIGN 
         oplOk = FALSE 
         opcMessage = SUBSTITUTE ("Error in call: &1 (&2)",
                                  oResponse:StatusReason,
                                  oResponse:StatusCode)
      .
   END.
   ELSE DO:
      ASSIGN 
         oplOk = TRUE
         opcMessage = SUBSTITUTE ("Successful call: &1 (&2)",
                                  oResponse:StatusReason,
                                  oResponse:StatusCode,
                                  oResponse:Entity)
      .
   END.
   
   oEntity = oResponse:Entity.
   IF TYPE-OF(oEntity, JsonObject) THEN
   DO:
      oJSonEntity = CAST(oResponse:Entity, JsonObject).
      oJsonEntity:Write(opcResponse).
      
   END.
   IF TYPE-OF(oEntity, String) THEN
      opcResponse = CAST(oEntity, String):Value.
   ELSE
      opcResponse = oEntity:ToString().

   CATCH oError AS Progress.Lang.Error :
      ASSIGN 
         oplOk = FALSE 
         opcMessage = SUBSTITUTE ("Error: &1, Stack: &2",
                                 oError:GetMessage(1),
                                 oError:CallStack)
      .
   END CATCH.   

END PROCEDURE.

PROCEDURE httpsPostGen:
   /*------------------------------------------------------------------------------
    Purpose: Chiamata POST con HTTPS
    Notes:   Estensione di httpPostGen per chiamate con HTTPS
   ------------------------------------------------------------------------------*/
   DEFINE INPUT  PARAMETER ipcHost     AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipiPort     AS INTEGER   NO-UNDO.
   DEFINE INPUT  PARAMETER ipcPath     AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipcUser     AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipcPassword AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipiTimeOut  AS INTEGER   NO-UNDO.
   DEFINE INPUT  PARAMETER ipcMessage  AS LONGCHAR  NO-UNDO.
   DEFINE OUTPUT PARAMETER opcResponse AS LONGCHAR  NO-UNDO.
   DEFINE OUTPUT PARAMETER oplOk       AS LOGICAL   NO-UNDO.
   DEFINE OUTPUT PARAMETER opcMessage  AS CHARACTER NO-UNDO.

   DEFINE VARIABLE oClient      AS IHttpClient   NO-UNDO.
   DEFINE VARIABLE oRequest     AS IHttpRequest  NO-UNDO.
   DEFINE VARIABLE oHeader      AS HttpHeader    NO-UNDO.
   DEFINE VARIABLE oRequestBody AS STRING        NO-UNDO.
   DEFINE VARIABLE oResponse    AS IHttpResponse NO-UNDO.
   DEFINE VARIABLE oPayLoad     AS JsonObject    NO-UNDO.
   DEFINE VARIABLE oEntity      AS Object        NO-UNDO.
   DEFINE VARIABLE oJsonEntity  AS JsonObject    NO-UNDO.
   DEFINE VARIABLE hEntity      AS HANDLE        NO-UNDO.
   DEFINE VARIABLE lcEntity     AS LONGCHAR      NO-UNDO.
   DEFINE VARIABLE hSAXReader   AS HANDLE        NO-UNDO.
   /* Classi per Authentication Basic */
   DEFINE VARIABLE oCredentials AS Credentials   NO-UNDO.
   DEFINE VARIABLE lCredentials AS LOGICAL       NO-UNDO.
   
   DEFINE VARIABLE cPath        AS CHARACTER     NO-UNDO.
   DEFINE VARIABLE cURL         AS CHARACTER     NO-UNDO.

   IF ipcUser NE "" THEN DO:
      oCredentials = NEW Credentials (ipcHost, ipcUser, ipcPassword).
      lCredentials = TRUE.
   END.
   ELSE DO:
      lCredentials = FALSE.
   END.

   oClient = ClientBuilder:Build():Client.

   ASSIGN 
      cPath = ipcPath
      cURL  = SUBSTITUTE ("https://&1:&2/&3",
                          ipcHost,
                          ipiPort,
                          cPath)
      .
   
   oRequestBody = NEW STRING (ipcMessage).                          
                                
   IF lCredentials THEN DO:
      oRequest = RequestBuilder:Post(cURL, oRequestBody)
         :ContentType("application/x-www-form-urlencoded")
         :UsingBasicAuthentication(oCredentials)      
         :Request.      
   END.
   ELSE DO:
      oRequest = RequestBuilder:Post(cURL, oRequestBody)
          :ContentType("application/x-www-form-urlencoded")
          :Request.
   END.
      
   oResponse = oClient:Execute(oRequest).

   IF oResponse:StatusCode NE 200 THEN 
   DO:
      ASSIGN 
         oplOk      = FALSE 
         opcMessage = SUBSTITUTE ("Error in call: &1 (&2)",
                                  oResponse:StatusReason,
                                  oResponse:StatusCode)
         .
   END.
   ELSE 
   DO:
      ASSIGN 
         oplOk      = TRUE
         opcMessage = SUBSTITUTE ("Successful call: &1 (&2)",
                                  oResponse:StatusReason,
                                  oResponse:StatusCode,
                                  oResponse:Entity)
         .
   END.
   
   oEntity = oResponse:Entity.
   IF TYPE-OF(oEntity, JsonObject) THEN
   DO:
      oJSonEntity = CAST(oResponse:Entity, JsonObject).
      oJsonEntity:Write(opcResponse).
      
   END.
   IF TYPE-OF(oEntity, String) THEN
      opcResponse = CAST(oEntity, String):Value.
   ELSE DO:
      hEntity = CAST(oResponse:Entity, WidgetHandle):Value.
       // Save the response to a LONGCHAR
      hEntity:SAVE('LONGCHAR', lcEntity).
      IF oResponse:ContentType = "text/xml" THEN
      DO:
         // XML response, Parse with SAX parser
         /* Create the SAX-reader object */
         CREATE SAX-READER hSAXReader.
         /* Tell the SAX-READER which XML file to parse. */
         hSAXReader:SET-INPUT-SOURCE("LONGCHAR", lcEntity).
         hSAXReader:SAX-PARSE( ).
         
         DELETE OBJECT hSAXReader.
         opcResponse = lcEntity.
      END.
      ELSE DO:
         opcResponse = SUBSTITUTE ("Response Content Type: &1~nContents:~n&2",
                                   oResponse:ContentType,
                                   lcEntity).
      END.                                             
   END.

   CATCH oError AS Progress.Lang.Error :
      ASSIGN 
         oplOk      = FALSE 
         opcMessage = SUBSTITUTE ("Error: &1, Stack: &2",
                                 oError:GetMessage(1),
                                 oError:CallStack)
         .
   END CATCH.   

END PROCEDURE.


PROCEDURE Characters:
   /*------------------------------------------------------------------------------
    Purpose: Handle callback Characters from XML Reader
    Notes:
   ------------------------------------------------------------------------------*/
   DEFINE INPUT  PARAMETER ipcCharData AS LONGCHAR NO-UNDO.
   DEFINE INPUT  PARAMETER ipiNumChars AS INTEGER  NO-UNDO.

   DEFINE BUFFER ttXMLNode FOR ttXMLNode.

   FIND  ttXMLNode 
      WHERE ttXMLNode.IDXMLNode EQ lviCurrentNode NO-ERROR.
   IF AVAILABLE ttXMLNode THEN 
   DO:
      
      IF LENGTH (ttXMLNode.XMLValue) + ipiNumChars GT 1000
         OR LENGTH (ttXMLNode.XMLBLOB) GT 0 THEN 
      DO:
         /*         MESSAGE "Big Data?" ipiNumChars*/
         /*         VIEW-AS ALERT-BOX.             */

         IF ttXMLNode.XMLValue NE "" THEN 
         DO:
            lvcLongChar = ttXMLNode.XMLValue.
            ttXMLNode.XMLValue = "".
         END.
         ELSE 
         DO:
            COPY-LOB FROM ttXMLNode.XMLBLOB TO lvcLongChar.
         END.
            
         lvcLongChar = lvcLongChar + TRIM (ipcCharData).
         COPY-LOB FROM lvcLongChar TO ttXMLNode.XMLBLOB.
      END.
      ELSE 
      DO:
         ttXMLNode.XMLValue = ttXMLNode.XMLValue + TRIM (ipcCharData).
      END.
   END.
   
END PROCEDURE.

PROCEDURE StartElement:
   /*------------------------------------------------------------------------------
    Purpose: Handle StartElement callback of SAX-Reader
    Notes:
   ------------------------------------------------------------------------------*/
   DEFINE INPUT  PARAMETER ipcNamespaceURI AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipcLocalName    AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipcElementName  AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER iphAttributes   AS HANDLE NO-UNDO.

   ASSIGN 
      lvcCurrentElement = ipcElementName
      lviCurrentLevel   = lviCurrentLevel + 1
      lviCurrentNode    = lviCurrentNode  + 1                                   
      .

   CREATE ttXMLNode.
   ASSIGN 
      ttXMLNode.IDXMLNode  = lviCurrentNode
      ttXMLNode.XMLLevel   = lviCurrentLevel
      ttXMLNode.XMLPath    = lvcCurrentPath
      ttXMLNode.XMLName    = lvcCurrentElement
      ttXMLNode.lProcessed = FALSE
      ttXMLNode.lOk        = ?
      ttXMLNode.cMessage   = "" 
      .
    
   IF lvcCurrentPath EQ "" THEN 
   DO:
      ASSIGN 
         lvcCurrentPath = lvcCurrentElement
         .
   END.
   ELSE 
   DO:
      ASSIGN
         lvcCurrentPath = SUBSTITUTE ("&1,&2",
                                      lvcCurrentPath,
                                      lvcCurrentElement)
         .                                   
   END.
   
END PROCEDURE.

PROCEDURE StartDocument:
   /*------------------------------------------------------------------------------
    Purpose: Handle StartDocument of SAX-Reader
    Notes:
   ------------------------------------------------------------------------------*/

   EMPTY TEMP-TABLE ttXMLNode.
   
   ASSIGN 
      lviCurrentLevel   = 0
      lviCurrentNode    = 0
      lvcCurrentElement = ""
      lvcCurrentPath    = ""
      .
   
END PROCEDURE.

PROCEDURE EndElement:
   /*------------------------------------------------------------------------------
    Purpose: Handle EndElement of SAX-Reader
    Notes:
   ------------------------------------------------------------------------------*/
   DEFINE INPUT  PARAMETER ipcNameSpaceURI AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipcLocalName    AS CHARACTER NO-UNDO.
   DEFINE INPUT  PARAMETER ipcElementName  AS CHARACTER NO-UNDO.

   DEFINE BUFFER ttXMLNode FOR ttXMLNode.


   /*   FOR EACH ttXMLNode                             */
   /*   WHERE ttXMLNode.XMLPath EQ lvcCurrentPath:     */
   /*      MESSAGE                                     */
   /*      ttXMLNode.XMLLevel ttXMLNode.IDXMLNode SKIP */
   /*      ttXMLNode.XMLPath ttXMLNode.XMLName SKIP (1)*/
   /*      ttXMLNode.XMLValue                          */
   /*      VIEW-AS ALERT-BOX.                          */
   /*   END.                                           */
         
   ASSIGN
      lviCurrentLevel      = lviCurrentLevel - 1
      lvcCurrentPath       = SUBSTRING (lvcCurrentPath, 1, R-INDEX (lvcCurrentPath, ",") - 1)
      lvcCurrentElement    = ""
      lvcCurrentCharacters = ""
      lvcLongChar          = ""
      .
      
END PROCEDURE.

PROCEDURE write_ttXMLNode:
   DEFINE INPUT  PARAMETER ipcFileName AS CHARACTER NO-UNDO.
   
   TEMP-TABLE ttXMLNode:WRITE-XML ("file", ipcFileName, TRUE).
END.

PROCEDURE openLogFile:
/*------------------------------------------------------------------------------
 Purpose:
 Notes:
------------------------------------------------------------------------------*/
DEFINE INPUT  PARAMETER ipcLogFileName AS CHARACTER NO-UNDO.
DEFINE INPUT  PARAMETER ipiLogLevel    AS INTEGER   NO-UNDO.
DEFINE OUTPUT PARAMETER oplOk          AS LOGICAL   NO-UNDO.
DEFINE OUTPUT PARAMETER opcMessage     AS CHARACTER NO-UNDO.

   IF LOG-MANAGER:LOGFILE-NAME NE ? THEN DO:
      ASSIGN 
         oplOk = FALSE 
         opcMessage = SUBSTITUTE ("LOG-MANAGER has already logfile open: '&1'.",
                                  LOG-MANAGER:LOGFILE-NAME)
      .
      RETURN.
   END.
                                     
   FILE-INFO:FILE-NAME = ipcLogFileName.
   IF FILE-INFO:FILE-TYPE NE ? THEN DO:
      ASSIGN 
         oplOk = FALSE 
         opcMessage = SUBSTITUTE ("Logfile already available: '&1'.",
                                 FILE-INFO:FULL-PATHNAME)
      .
      RETURN.
   END.
                                                                           
   ASSIGN 
      LOG-MANAGER:LOGFILE-NAME  = ipcLogFilename
      LOG-MANAGER:LOGGING-LEVEL = ipiLogLevel
   .    

   ASSIGN 
      oplOk = TRUE 
      opcMessage = SUBSTITUTE ("Logfile open: '&1'.",
                               ipcLogFileName)
   .                            
END PROCEDURE.

