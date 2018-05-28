unit UGetMacAdress;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  TGetMacAdress = class
    public
      function getMac: string;
  end;

implementation

function TGetMacAdress.getMac: string;
var
  process: TProcess;
  response, address: TStringList;
begin
  {$IFDEF WINDOWS}
    process:=TProcess.create(nil);
    process.executable:='cmd.exe';
    process.parameters.add('/C getmac -fo csv');
    process.options:=process.options + [poWaitOnExit, poUsePipes];
    process.showWindow:=swoHIDE;
    process.execute;
    response:=TStringList.create;
    response.LoadFromStream(process.output);
    process.free;
    address:=TStringList.create;
    address.delimiter:=',';
    address.delimitedText:=response[1];
    response.free;
    result:=StringReplace(address[0], '-', ':', [rfReplaceAll]);
    address.free;
  {$ENDIF}
  {$IFDEF LINUX}
    process:=TProcess.create(nil);
    process.executable:='sh';
    process.parameters.add('-c');
    process.parameters.add('cat /sys/class/net/$(ip route show default | awk ''/default/ {print $5}'')/address');
    process.options:=process.options + [poWaitOnExit, poUsePipes];
    process.showWindow:=swoHIDE;
    process.execute;
    response:=TStringList.create;
    response.LoadFromStream(process.output);
    process.free;
    result:=UpperCase(response[0]);
    response.free;
  {$ENDIF}
end;

end.

