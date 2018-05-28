unit UPingThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  {$IFDEF WINDOWS}
    pingsend;
  {$ENDIF}
  {$IFDEF LINUX}
    fpjson, jsonparser, process, Dialogs;
  {$ENDIF}

type
  TShowStatusEvent = procedure(status: boolean; return: string) of Object;
  TPingThread = class(TThread)
    private
      fResult: boolean;
      fStatusText: string;
      FOnShowStatus: TShowStatusEvent;
      host: string;
      procedure showStatus;
    protected
      procedure execute; override;
    public
      constructor create(hostC: string);
      property OnShowStatus: TShowStatusEvent read FOnShowStatus write FOnShowStatus;
  end;

implementation

constructor TPingThread.create(hostC: string);
begin
  host:=hostC;
  FreeOnTerminate:=true;
  inherited create(true);
end;

procedure TPingThread.showStatus;
begin
  if Assigned(FOnShowStatus) then
    begin
      FOnShowStatus(fResult, fStatusText);
    end;
end;

procedure TPingThread.execute;
var
  {$IFDEF WINDOWS}
    ping: TPingSend;
  {$ENDIF}
  {$IFDEF LINUX}
    ping: TProcess;
    response: TStringList;
    jData: TJSONData;
  {$ENDIF}
begin
  {$IFDEF WINDOWS}
    ping:=TPingSend.create();
    if (ping.ping(host)) then begin
      fResult:=true;
      fStatusText:=ping.replyFrom;
    end
    else begin
      fResult:=false;
      fStatusText:=ping.replyErrorDesc;
    end;
  {$ENDIF}
  {$IFDEF LINUX}
    ping:=TProcess.create(nil);
    ping.executable:='sh';
    ping.parameters.add('-c');
    ping.parameters.add('sudo PhilleConnectOnlineChecker '+host);
    ping.showWindow:=swoHIDE;
    ping.options:=ping.options + [poWaitOnExit, poUsePipes];
    ping.execute;
    response:=TStringList.create;
    response.LoadFromStream(ping.output);
    ping.free;
    jData:=GetJSON(response[0]);
    fStatusText:=jData.AsJSON;
    response.free;
    if (jData.FindPath('[0]').AsString = 'true') then begin
      fResult:=true;
      fStatusText:=jData.FindPath('[1]').AsString;
    end
    else begin
      fResult:=false;
      fStatusText:=jData.FindPath('[1]').AsString;
    end;
  {$ENDIF}
  Synchronize(@ShowStatus);
end;

end.

