unit UPingThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, pingsend;

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
  ping: TPingSend;
begin
  ping:=TPingSend.create();
  if (ping.ping(host)) then begin
    fResult:=true;
    fStatusText:=ping.replyFrom;
  end
  else begin
    fResult:=false;
    fStatusText:=ping.replyErrorDesc;
  end;
  Synchronize(@ShowStatus);
end;

end.

