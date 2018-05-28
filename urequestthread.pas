unit URequestThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, httpsend;

type
  TShowStatusEvent = procedure(response: string) of Object;
  TRequestThread = class(TThread)
    private
      url, params: string;
      fStatusText: string;
      FOnShowStatus: TShowStatusEvent;
      procedure showStatus;
    protected
      procedure execute; override;
    public
      constructor create(urlC, paramsC: string);
      property OnShowStatus: TShowStatusEvent read FOnShowStatus write FOnShowStatus;
  end;

implementation

constructor TRequestThread.create(urlC, paramsC: string);
begin
  url:=urlC;
  params:=paramsC;
  FreeOnTerminate:=true;
  inherited create(true);
end;

procedure TRequestThread.showStatus;
begin
  if Assigned(FOnShowStatus) then
    begin
      FOnShowStatus(fStatusText);
    end;
end;

procedure TRequestThread.execute;
var
  response: TMemoryStream;
begin
  response:=TMemoryStream.Create;
  try
    if HttpPostURL(url, params, response) then
      if response <> nil then begin
        response.Position := 0;
        SetString(fStatusText, PChar(response.Memory), response.Size);
      end;
  finally
    response.Free;
    Synchronize(@ShowStatus);
  end;
end;

end.

