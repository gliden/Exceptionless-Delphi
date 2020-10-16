unit ExceptionlessLib;

interface

uses
  System.SysUtils, System.Classes, {$IFDEF VER240}Data.DBXJson{$ELSE}System.JSON{$ENDIF}, System.Generics.Collections,
  HttpClientWrapperLib;

type
  //This class is from here: https://stackoverflow.com/a/11786659
  TSvJsonString = class(TJSONString)
  private
    function EscapeValue(const AValue: string): string;
  public
    constructor Create(const AValue: string); overload;
  end;

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

  TExceptionlessData = TPair<String, String>;

  TExceptionlessDataCollection = class(TList<TExceptionlessData>)
  public
    function ToJson: TJSONObject;
  end;

  TExceptionlessEnvironment = class(TObject)
  private
    FMachineName: String;
    FProcessName: String;
    FData: TExceptionlessDataCollection;
  public
    constructor Create;
    destructor Destroy; override;
    function ToJson: TJSONObject;

    property ProcessName: String read FProcessName write FProcessName;
    property MachineName: String read FMachineName write FMachineName;
    property Data: TExceptionlessDataCollection read FData;
  end;

  TExceptionlessEvent = class(TObject)
  private
    FType: TExceptionlessEventType;
    FTimestamp: TDateTime;
    FUser: TExceptionlessUser;
    FSource: String;
    FMessage: String;
    FTags: TExceptionlessTags;
    FVersion: String;
    FEnvironment: TExceptionlessEnvironment;
    FUserDescription: TExceptionlessUserDescription;
    function getTypeAsString: String;
  public
    constructor Create;
    destructor Destroy; override;
    function ToJson: TJsonObject; virtual;
    function ToString: String; override;

    property Version: String read FVersion write FVersion;
    property Source: String read FSource write FSource;
    property &Type: TExceptionlessEventType read FType write FType;
    property &Message: String read FMessage write FMessage;
    property TimeStamp: TDateTime read FTimestamp write FTimestamp;
    property User: TExceptionlessUser read FUser;
    property UserDescription: TExceptionlessUserDescription read FUserDescription;
    property Tags: TExceptionlessTags read FTags;
    property Environment: TExceptionlessEnvironment read FEnvironment;
  end;

  TExceptionlessSimpleError = class(TExceptionlessEvent)
  private
    FExceptionType: String;
    FStackTrace: String;
  public
    function ToJson: TJsonObject; override;
    function ToString: String; override;
    property ExceptionType: String read FExceptionType write FExceptionType;
    property StackTrace: String read FStackTrace write FStackTrace;
  end;

  TExceptionless = class(TObject)
  private
    FHttpWrapper: IHttpClientWrapper;
    FProjectId: String;
    FApiKey: String;
    FUserAgent: String;
  public
    constructor Create(httpWrapper: IHttpClientWrapper);
    procedure Send(event: TExceptionlessEvent);

    property ProjectId: String read FProjectId write FProjectId;
    property ApiKey: String read FApiKey write FApiKey;
    property UserAgent: String read FUserAgent write FUserAgent;
  end;

implementation

uses
  Soap.XSBuiltIns;

{ TExceptionless }

constructor TExceptionless.Create(httpWrapper: IHttpClientWrapper);
begin
  FHttpWrapper := httpWrapper;
end;

procedure TExceptionless.Send(event: TExceptionlessEvent);
const
  C_RequestUrl = 'https://collector.exceptionless.io/api/v2/projects/%s/events';
var
  strStream: TStringStream;
  header: TArray<THttpHeader>;
  url: string;
  client: THttpClientWrapper;
begin
  url := Format(C_RequestUrl, [ProjectId]);

  strStream := TStringStream.Create(event.ToString);

  header := THttpHeader.SingleItem('Authorization', Format('Bearer %s', [ApiKey]));
  THttpHeader.AddItem('userAgent', userAgent, header);

  client := THttpClientWrapper.Create(FHttpWrapper);
  client.OnResponse :=
    procedure (response: IHTTPClientResponse)
    begin
      strStream.Free;
      client.Free;
    end;
  client.AsyncPost(url, 'application/json', strStream, header);
end;

{ TExceptionlessSimpleError }

function TExceptionlessSimpleError.ToJson: TJsonObject;
var
  errorObj: TJSONObject;
begin
  Result := inherited;
  errorObj := TJSONObject.Create;
  errorObj.AddPair('type', TSvJsonString.Create(FExceptionType));
  errorObj.AddPair('stack_trace', TSvJsonString.Create(FStackTrace));

  Result.AddPair('@simple_error', errorObj);
end;

function TExceptionlessSimpleError.ToString: String;
var
  jsonObj: TJSONObject;
begin
  jsonObj := ToJson;
  Result := jsonObj.ToString;
  jsonObj.Free;
end;

{ TExceptionlessUser }

function TExceptionlessUser.ToJson: TJSONObject;
begin
  result := TJSONObject.Create;
  result.AddPair('identity', TSvJsonString.Create(FIdentity));
  result.AddPair('name', TSvJsonString.Create(FName));
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

function TExceptionlessEvent.getTypeAsString: String;
begin
  case FType of
    etLog: Result := 'log';
    etError: Result := 'error';
    etFeature: Result := 'use';
  end;
end;

function TExceptionlessEvent.ToJson: TJsonObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', getTypeAsString);
  Result.AddPair('date', DateTimeToXMLTime(TimeStamp));
  Result.AddPair('source', TSvJsonString.Create(FSource));
  Result.AddPair('@version', TSvJsonString.Create(FVersion));
  Result.AddPair('message', TSvJsonString.Create(FMessage));
  Result.AddPair('tags', FTags.ToJson);
  Result.AddPair('@user', FUser.ToJson);
  Result.AddPair('@user_description', FUserDescription.ToJson);
  Result.AddPair('@environment', FEnvironment.ToJson);
end;

function TExceptionlessEvent.ToString: String;
var
  jsonObj: TJSONObject;
begin
  jsonObj := ToJson;
  Result := jsonObj.ToString;
  jsonObj.Free;
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

constructor TExceptionlessEnvironment.Create;
begin
  FData := TExceptionlessDataCollection.Create;
end;

destructor TExceptionlessEnvironment.Destroy;
begin
  FData.Free;
  inherited;
end;

function TExceptionlessEnvironment.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('ProcessName', TSvJsonString.Create(ProcessName));
  Result.AddPair('MachineName', TSvJsonString.Create(MachineName));
  Result.AddPair('Data', FData.ToJson);
end;

{ TExceptionlessUserDescription }

function TExceptionlessUserDescription.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Email_Address', TSvJsonString.Create(EmailAddress));
  Result.AddPair('Description', TSvJsonString.Create(Description));
end;

{ TExceptionlessDataCollection }

function TExceptionlessDataCollection.ToJson: TJSONObject;
var
  data: TExceptionlessData;
begin
  Result := TJSONObject.Create;
  for data in Self do
  begin
    Result.AddPair(data.Key, TSvJsonString.Create(data.Value));
  end;
end;

{ TSvJsonString }


constructor TSvJsonString.Create(const AValue: string);
begin
  inherited Create(EscapeValue(AValue));
end;

function TSvJsonString.EscapeValue(const AValue: string): string;

 procedure AddChars(const AChars: string; var Dest: string; var AIndex: Integer); inline;
  begin
    System.Insert(AChars, Dest, AIndex);
    System.Delete(Dest, AIndex + 2, 1);
    Inc(AIndex, 2);
  end;

  procedure AddUnicodeChars(const AChars: string; var Dest: string; var AIndex: Integer); inline;
  begin
    System.Insert(AChars, Dest, AIndex);
    System.Delete(Dest, AIndex + 6, 1);
    Inc(AIndex, 6);
  end;

var
  i, ix: Integer;
  AChar: Char;
begin
  Result := AValue;
  ix := 1;
  for i := 1 to System.Length(AValue) do
  begin
    AChar :=  AValue[i];
    case AChar of
      '/', '\'(*, '"'*):
      begin
        System.Insert('\', Result, ix);
        Inc(ix, 2);
      end;
      #8:  //backspace \b
      begin
        AddChars('\b', Result, ix);
      end;
      #9:
      begin
        AddChars('\t', Result, ix);
      end;
      #10:
      begin
        AddChars('\n', Result, ix);
      end;
      #12:
      begin
        AddChars('\f', Result, ix);
      end;
      #13:
      begin
        AddChars('\r', Result, ix);
      end;
      #0 .. #7, #11, #14 .. #31:
      begin
        AddUnicodeChars('\u' + IntToHex(Word(AChar), 4), Result, ix);
      end
      else
      begin
        if Word(AChar) > 127 then
        begin
          AddUnicodeChars('\u' + IntToHex(Word(AChar), 4), Result, ix);
        end
        else
        begin
          Inc(ix);
        end;
      end;
    end;
  end;
end;

end.



