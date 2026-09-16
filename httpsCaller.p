
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
   DEFINE VARIABLE hXMLHandle   AS HANDLE        NO-UNDO.
   DEFINE VARIABLE lcXML        AS LONGCHAR      NO-UNDO.
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
      hXMLHandle = CAST(oResponse:Entity, WidgetHandle):Value.
       // Save the response to a LONGCHAR
      hXMLHandle:SAVE('LONGCHAR', lcXML).
      opcResponse = lcXML.
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

