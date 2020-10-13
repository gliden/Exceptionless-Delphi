unit ExceptionlessLib;

interface

uses
  System.SysUtils, System.Net.HttpClient, System.Classes, System.Net.URLClient,
  System.JSON;

type
  TExceptionlessEventType = (etLog, etError, etFeature);

  TExceptionlessUser = class(TObject)
  private
    FName: String;
    FIdentity: String;
  public
    function ToJson: String;
    property Identity: String read FIdentity write FIdentity;
    Property Name: String read FName write FName;
  end;

  TExceptionlessEvent = class(TObject)
  private
    FType: TExceptionlessEventType;
    FTimestamp: TDateTime;
    FUser: TExceptionlessUser;
  public
    constructor Create;
    destructor Destroy; override;
    property &Type: TExceptionlessEventType read FType write FType;
    property TimeStamp: TDateTime read FTimestamp write FTimestamp;
    property User: TExceptionlessUser read FUser;
  end;

  TExceptionlessSimpleError = class(TExceptionlessEvent)
  private
    FMessage: String;
    FExceptionType: String;
    FStackTrace: String;
  public
    function ToJson: String;
    property &Message: String read FMessage write FMessage;
    property ExceptionType: String read FExceptionType write FExceptionType;
    property StackTrace: String read FStackTrace write FStackTrace;
  end;

  TExceptionless = class(TObject)
  private
    FProjectId: String;
    FApiKey: String;
    FUserAgent: String;
  public
    procedure Send(error: TExceptionlessSimpleError);

    property ProjectId: String read FProjectId write FProjectId;
    property ApiKey: String read FApiKey write FApiKey;
    property UserAgent: String read FUserAgent write FUserAgent;
  end;

implementation

uses
  Soap.XSBuiltIns;

{ TExceptionless }

procedure TExceptionless.Send(error: TExceptionlessSimpleError);
const
  C_RequestUrl = 'https://collector.exceptionless.io/api/v2/projects/%s/events';
var
  client: THTTPClient;
  strStream: TStringStream;
  header: TArray<TNameValuePair>;
  url: string;
begin
  url := Format(C_RequestUrl, [ProjectId]);

  strStream := TStringStream.Create(error.ToJson);

  SetLength(header, 2);
  header[0].Name := 'Authorization';
  header[0].Value := Format('Bearer %s', [ApiKey]);

  header[1].Name := 'userAgent';
  header[1].Value := UserAgent;


  client := THTTPClient.Create;
  client.ContentType := 'application/json';
  try
    client.Post(url, strStream, nil, header);
  except
  end;
  client.Free;
end;

{ TExceptionlessSimpleError }

function TExceptionlessSimpleError.ToJson: String;
var
  jsonObj: TJSONObject;
  errorObj: TJSONObject;
begin
  errorObj := TJSONObject.Create;
  errorObj.AddPair('message', FMessage);
  errorObj.AddPair('type', FExceptionType);
  errorObj.AddPair('stack_trace', FStackTrace);

  jsonObj := TJSONObject.Create;
  jsonObj.AddPair('type', 'error');
  jsonObj.AddPair('date', DateTimeToXMLTime(TimeStamp));
  jsonObj.AddPair('@simple_error', errorObj);

  Result := jsonObj.ToJSON;
  jsonObj.Free;
end;

{ TExceptionlessUser }

function TExceptionlessUser.ToJson: String;
var
  jsonObj: TJSONObject;
begin
  jsonObj := TJSONObject.Create;
  jsonObj.AddPair('identity', FIdentity);
  jsonObj.AddPair('name', FName);
  Result := jsonObj.ToJSON;
  jsonObj.Free;
end;

{ TExceptionlessEvent }

constructor TExceptionlessEvent.Create;
begin
  FUser := TExceptionlessUser.Create;
end;

destructor TExceptionlessEvent.Destroy;
begin
  FUser.Free;
  inherited;
end;

end.



