unit ExceptionlessLib;

interface

uses
  System.SysUtils, System.Net.HttpClient, System.Classes, System.Net.URLClient,
  System.JSON, System.Generics.Collections;

type
  TExceptionlessEventType = (etLog, etError, etFeature);

  TExceptionlessUser = class(TObject)
  private
    FName: String;
    FIdentity: String;
  public
    function ToJson: TJSONObject;
    property Identity: String read FIdentity write FIdentity;
    Property Name: String read FName write FName;
  end;

  TExceptionlessUserDescription = class(TObject)
  private
    FDescription: String;
    FEmailAddress: String;
  public
    function ToJson: TJSONObject;
    property EmailAddress: String read FEmailAddress write FEmailAddress;
    Property Description: String read FDescription write FDescription;
  end;

  TExceptionlessTags = class(TList<String>)
  public
    function ToJson: TJSONArray;
  end;

  TExceptionlessEnvironment = class(TObject)
  private
    FMachineName: String;
    FProcessName: String;
  public
    function ToJson: TJSONObject;

    property ProcessName: String read FProcessName write FProcessName;
    property MachineName: String read FMachineName write FMachineName;
  end;

  TExceptionlessEvent = class(TObject)
  private
    FType: TExceptionlessEventType;
    FTimestamp: TDateTime;
    FUser: TExceptionlessUser;
    FSource: String;
    FTags: TExceptionlessTags;
    FVersion: String;
    FEnvironment: TExceptionlessEnvironment;
    FUserDescription: TExceptionlessUserDescription;
  public
    constructor Create;
    destructor Destroy; override;
    function ToJson: TJsonObject; virtual;

    property Version: String read FVersion write FVersion;
    property Source: String read FSource write FSource;
    property &Type: TExceptionlessEventType read FType write FType;
    property TimeStamp: TDateTime read FTimestamp write FTimestamp;
    property User: TExceptionlessUser read FUser;
    property UserDescription: TExceptionlessUserDescription read FUserDescription;
    property Tags: TExceptionlessTags read FTags;
    property Environment: TExceptionlessEnvironment read FEnvironment;
  end;

  TExceptionlessSimpleError = class(TExceptionlessEvent)
  private
    FMessage: String;
    FExceptionType: String;
    FStackTrace: String;
  public
    function ToJson: TJsonObject; override;
    function ToString: String; override;
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

  strStream := TStringStream.Create(error.ToString);

  SetLength(header, 2);
  header[0].Name := 'Authorization';
  header[0].Value := Format('Bearer %s', [ApiKey]);

  header[1].Name := 'userAgent';
  header[1].Value := UserAgent;


  TThread.CreateAnonymousThread(
    procedure
    begin
      client := THTTPClient.Create;
      client.ContentType := 'application/json';
      try
        client.Post(url, strStream, nil, header);
      except
      end;
      client.Free;
    end
  ).Start;
end;

{ TExceptionlessSimpleError }

function TExceptionlessSimpleError.ToJson: TJsonObject;
var
  errorObj: TJSONObject;
begin
  Result := inherited;
  errorObj := TJSONObject.Create;
  errorObj.AddPair('message', FMessage);
  errorObj.AddPair('type', FExceptionType);
  errorObj.AddPair('stack_trace', FStackTrace);

  Result.AddPair('@simple_error', errorObj);
end;

function TExceptionlessSimpleError.ToString: String;
var
  jsonObj: TJSONObject;
begin
  jsonObj := ToJson;
  Result := jsonObj.ToJSON;
  jsonObj.Free;
end;

{ TExceptionlessUser }

function TExceptionlessUser.ToJson: TJSONObject;
begin
  result := TJSONObject.Create;
  result.AddPair('identity', FIdentity);
  result.AddPair('name', FName);
end;

{ TExceptionlessEvent }

constructor TExceptionlessEvent.Create;
begin
  FUser := TExceptionlessUser.Create;
  FUserDescription := TExceptionlessUserDescription.Create;
  FTags := TExceptionlessTags.Create;
  FEnvironment := TExceptionlessEnvironment.Create;
end;

destructor TExceptionlessEvent.Destroy;
begin
  FUser.Free;
  FUserDescription.Free;
  FTags.Free;
  FEnvironment.Free;
  inherited;
end;

function TExceptionlessEvent.ToJson: TJsonObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'error');
  Result.AddPair('date', DateTimeToXMLTime(TimeStamp));
  Result.AddPair('source', FSource);
  Result.AddPair('@version', FVersion);
  Result.AddPair('tags', FTags.ToJson);
  Result.AddPair('@user', FUser.ToJson);
  Result.AddPair('@user_description', FUserDescription.ToJson);
  Result.AddPair('@environment', FEnvironment.ToJson);
end;

{ TExceptionlessTags }

function TExceptionlessTags.ToJson: TJSONArray;
var
  s: String;
begin
  Result := TJSONArray.Create;
  for s in Self do
  begin
    Result.Add(s);
  end;
end;

{ TExceptionlessEnvironment }

function TExceptionlessEnvironment.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('ProcessName', ProcessName);
  Result.AddPair('MachineName', MachineName);
end;

{ TExceptionlessUserDescription }

function TExceptionlessUserDescription.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Email_Address', EmailAddress);
  Result.AddPair('Description', Description);
end;

end.



