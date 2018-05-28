unit UGetIPAdress;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  TGetIPAdress = class
    public
      function getIP: string;
    private
      {$IFDEF WINDOWS}
      function GetIpAddrList: string;
      {$ENDIF}
  end;

implementation

function TGetIPAdress.getIP: string;
var
  response: TStringList;
  {$IFDEF LINUX}
  process: TProcess;
  {$ENDIF}
begin
  {$IFDEF WINDOWS}
  response:=TStringList.create;
  response.delimiter:=' ';
  response.delimitedText:=GetIpAddrList;
  result:=response[1];
  {$ENDIF}
  {$IFDEF LINUX}
  process:=TProcess.create(nil);
  process.executable:='sh';
  process.parameters.add('-c');
  process.parameters.add('hostname -I | awk ''{print $1}''');
  process.options:=process.options + [poWaitOnExit, poUsePipes];
  process.showWindow:=swoHIDE;
  process.execute;
  response:=TStringList.create;
  response.LoadFromStream(process.output);
  process.free;
  result:=trim(response[0]);
  response.free;
  {$ENDIF}
end;

{$IFDEF WINDOWS}
function TGetIPAdress.GetIpAddrList: string;
var
  AProcess: TProcess;
  s: string;
  sl: TStringList;
  i, n: integer;
begin
  Result:='';
  sl:=TStringList.Create();
  AProcess:=TProcess.Create(nil);
  AProcess.CommandLine := 'ipconfig.exe';
  AProcess.Options := AProcess.Options + [poUsePipes, poNoConsole];
  try
    AProcess.Execute();
    Sleep(500); // poWaitOnExit don't work as expected
    sl.LoadFromStream(AProcess.Output);
  finally
    AProcess.Free();
  end;
  for i:=0 to sl.Count-1 do
  begin
    if (Pos('IPv4', sl[i])=0) and (Pos('IP-', sl[i])=0) and (Pos('IP Address', sl[i])=0) then Continue;
    s:=sl[i];
    s:=Trim(Copy(s, Pos(':', s)+1, 999));
    if Pos(':', s)>0 then Continue; // IPv6
    Result:=Result+s+' ';
  end;
  sl.Free();
end;
{$ENDIF}

end.
