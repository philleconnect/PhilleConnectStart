program PhilleConnectStart;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, PCS, ugetmacadress, ugetipadress, UPingThread,
  URequestThread, ssl_openssl_lib;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(Twindow, window);
  Application.Run;
end.

