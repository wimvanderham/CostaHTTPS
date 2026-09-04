
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
USING OpenEdge.Net.HTTP.ClientBuilder.
USING OpenEdge.Net.HTTP.IHttpClient.
USING OpenEdge.Net.HTTP.IHttpRequest.
USING OpenEdge.Net.HTTP.RequestBuilder.
USING OpenEdge.Net.HTTP.IHttpResponse.
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
                             
   oRequest = RequestBuilder:Post(cURL, oRequestBody):REQUEST.
                         
   oResponse = oClient:Execute(oRequest).

   IF oResponse:StatusCode NE 200 THEN DO:
      ASSIGN 
         oplOk = FALSE 
         opcMessage = SUBSTITUTE ("Error in call: &1 (&2)",
                                  oResponse:StatusReason,
                                  oResponse:StatusCode)
      .
      RETURN.
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
          
      MESSAGE oError:GetMessage(1) SKIP(2)
         oError:CallStack
         VIEW-AS ALERT-BOX.
   END CATCH.   

END PROCEDURE.

