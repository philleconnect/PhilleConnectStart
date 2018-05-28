program PhilleConnectStart;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, PCS, ULockCAENTF, ugetmacadress, ugetipadress, UPingThread,
  URequestThread;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(Twindow, window);
  Application.Run;
end.

