//Copyright 2016-2018 Johannes Kreutz.
//Alle Rechte vorbehalten.
unit PCS;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Process,
  {$IFDEF WINDOWS}
    ULockCAENTF, Windows,
  {$ENDIF}
  HTTPSend, fpjson, jsonparser, UGetMacAdress, UGetIPAdress, StrUtils,
  ssl_openssl, UPingThread, resolve, URequestThread;

type

  { Twindow }

  Twindow = class(TForm)
    actionLabel: TLabel;
    noNetworkSub: TLabel;
    noNetworkHead: TLabel;
    noNetworkInfo: TLabel;
    successTimer: TTimer;
    errorTimer: TTimer;
    reloadTimer: TTimer;
    usersBox: TGroupBox;
    newsBox: TGroupBox;
    loginBox: TGroupBox;
    rechnerBox: TGroupBox;
    usernames: TListBox;
    search: TEdit;
    infoLabel: TLabel;
    loginProgress: TProgressBar;
    shutdownTimer: TTimer;
    versionLabel: TLabel;
    shutdownButton: TButton;
    rebootButton: TButton;
    shutdownLabel: TLabel;
    loginButton: TButton;
    clearButton: TButton;
    shutdownProgress: TProgressBar;
    unameLabel: TLabel;
    passwdLabel: TLabel;
    passwd: TEdit;
    uname: TEdit;
    headline: TLabel;
    news: TMemo;
    logo: TImage;
    procedure clearButtonClick(Sender: TObject);
    procedure errorTimerTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure loginButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure rebootButtonClick(Sender: TObject);
    procedure reloadTimerTimer(Sender: TObject);
    procedure searchChange(Sender: TObject);
    procedure shutdownButtonClick(Sender: TObject);
    procedure shutdownTimerTimer(Sender: TObject);
    procedure successTimerTimer(Sender: TObject);
    procedure usernamesSelectionChange(Sender: TObject; User: boolean);
  private
    //Login ausführen nach Klick auf Button
    procedure doLogin;
    procedure doLoginResponse(response: string);
    //System herunterfahren / neu Starten
    procedure system(reboot: boolean);
    //Nutzerliste laden
    procedure loadUsers;
    procedure loadUsersResponse(response: string);
    //Netzwerkverbindung prüfen
    procedure checkNetworkConnection;
    procedure networkConnectionResult(result: boolean; return: string);
    procedure trueNetworkResult;
    procedure falseNetworkResult;
    //Konfigurationsdatei / Serverkonfiguration laden
    procedure parseConfigFile;
    procedure loadConfig;
    procedure loadConfigResponse(response: string);
    //Verhalten nach fehlgeschlagenen Verbindungsversuchen
    procedure handleNoNetwork;
    //Inputs sperren / entsperren
    procedure lockInputs(mode: boolean);
    //Oberfläche sperren / entsperren
    procedure lockUI(mode: boolean);
    //Herunterfahren-Timer vorbereiten
    procedure prepareShutdownTimer(seconds: integer);
    //Hinweis-Textbox laden
    procedure loadTextBox(infotext: string);
    //Legt fest, ob der Rechner ohne Serverzugriff verwendet werden darf
    procedure setAllowOffline(value: string);
    //Wertet den Wartungsmodus-Parameter aus
    procedure setAllowNoLogin(value: string);
    //Keyboard Hook aktivieren / deaktivieren
    {$IFDEF WINDOWS}
      procedure keyboardHook(mode: boolean);
    {$ENDIF}
    function sendRequest(url, params: string): string;
    function MemStreamToString(Strm: TMemoryStream): AnsiString;
    function ValidateIP(IP4: string): Boolean;
  public
    { public declarations }
  end;
  {$IFDEF WINDOWS}
    //DLL Funktionen
    function InstallHook(Hwnd: THandle; strictParam: boolean): boolean; stdcall; external 'hook.dll';
    function UninstallHook: boolean; stdcall; external 'hook.dll';
    function InstallMouseHook(Hwnd: THandle): boolean; stdcall; external 'mhook.dll';
    function UninstallMouseHook: boolean; stdcall; external 'mhook.dll';
  {$ENDIF}

var
  window: Twindow;
  actualShutdown, networkRetry, actualNetworkRetry: integer;
  userdata, fullUserdata, searchUserdata: TStrings;
  serverURL, globalPW, login, loginPending, loginFailed, wrongCredentials,
  networkFailed, success, mac, ip, cleanServerURL: string;
  allowOffline, isOnline: boolean;
  pingthread: TPingThread;
  loadUsersThread, loadConfigThread, doLoginThread: TRequestThread;
  {$IFDEF WINDOWS}
    lock: TLockCAENTF;
  {$ENDIF}

implementation

{$R *.lfm}

{ Twindow }

procedure Twindow.shutdownTimerTimer(Sender: TObject);
begin
   actualShutdown:=actualShutdown-1;
   shutdownProgress.position:=actualShutdown;
   if (actualShutdown = 0) then begin
     system(false);
   end;
end;

procedure Twindow.successTimerTimer(Sender: TObject);
begin
  close;
end;

procedure Twindow.FormCreate(Sender: TObject);
var
  version, build: string;
begin
  version:='1.4';
  //build:='1E045';
  allowOffline:=false;
  networkRetry:=30;
  actualNetworkRetry:=1;
  isOnline:=false;
  {$IFDEF WIN64}
    versionLabel.Caption:='PhilleConnect LoginClient Win64 v'+version+' by Johannes Kreutz';
  {$ENDIF}
  {$IFDEF WIN32}
    versionLabel.Caption:='PhilleConnect LoginClient Win32 v'+version+' by Johannes Kreutz';
  {$ENDIF}
  {$IFDEF LINUX}
    versionLabel.Caption:='PhilleConnect LoginClient Linux v'+version+' by Johannes Kreutz';
  {$ENDIF}
  {$IFDEF DARWIN}
    versionLabel.Caption:='PhilleConnect LoginClient macOS v'+version+' by Johannes Kreutz';
  {$ENDIF}
  {$IFDEF WINDOWS}
    lock:=TLockCAENTF.create;
    keyboardHook(true);
  {$ENDIF}
  {$IFDEF LINUX}
    windowState := wsFullScreen;
    window.left:=0;
    window.top:=0;
    usernames.Top:=usernames.top+8;
    usernames.height:=usernames.height-8;
  {$ENDIF}
  parseConfigFile;
end;

procedure Twindow.clearButtonClick(Sender: TObject);
begin
  uname.text:='';
  passwd.text:='';
  actionLabel.visible:=true;
end;

procedure Twindow.errorTimerTimer(Sender: TObject);
begin
  system(false);
end;

procedure Twindow.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  {$IFDEF WINDOWS}
    lock.disable;
    lock.free;
    keyboardHook(false);
  {$ENDIF}
end;

procedure Twindow.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState
  );
begin
  if (key = 13) then begin
    if (window.activeControl = search) then begin
      if (searchUserdata.count = 1) then begin
        uname.text:=searchUserdata[0];
        passwd.setFocus;
      end;
    end
    else begin
      loginButtonClick(loginButton);
    end;
  end;
end;

procedure Twindow.loginButtonClick(Sender: Tobject);
begin
   if (uname.text = '') then begin
     infoLabel.caption:='Bitte gib einen Nutzernamen ein.';
     infoLabel.visible:=true;
   end
   else if (passwd.text = '') then begin
     infoLabel.caption:='Bitte gib dein Passwort ein.';
     infoLabel.visible:=true;
   end
   else begin
     infoLabel.visible:=false;
     uname.readOnly:=true;
     passwd.readOnly:=true;
     doLogin;
   end;
end;

procedure Twindow.rebootButtonClick(Sender: TObject);
begin
  system(true);
end;

procedure Twindow.reloadTimerTimer(Sender: TObject);
begin
  checkNetworkConnection;
end;

procedure Twindow.shutdownButtonClick(Sender: TObject);
begin
  system(false);
end;

procedure Twindow.system(reboot: boolean);
var
  process: TProcess;
begin
  process:=TProcess.create(nil);
  {$IFDEF WINDOWS}
  process.executable:='cmd';
  if (reboot = false) then begin
    process.parameters.add('/C shutdown /s /f /t 0');
  end
  else begin
    process.parameters.add('/C shutdown /r /f /t 0');
  end;
  {$ENDIF}
  {$IFDEF LINUX}
  process.executable:='sh';
  process.parameters.add('-c');
  if (reboot = false) then begin
    process.parameters.add('shutdown -h -P now');
  end
  else begin
    process.parameters.add('reboot');
  end;
  {$ENDIF}
  process.showWindow:=swoHIDE;
  process.execute;
  process.free;
end;

procedure Twindow.doLogin;
var
   os: string;
begin
  if (uname.text = '') then begin
    showMessage('Bitte gib einen Nutzernamen ein.');
  end
  else if (passwd.text = '') then begin
    showMessage('Bitte gib ein Passwort ein.');
  end
  else begin
    {$IFDEF WINDOWS}
      os:='win';
    {$ENDIF}
    {$IFDEF LINUX}
      os:='linux';
    {$ENDIF}
    //UI sperren
    actionLabel.caption:=loginPending;
    loginProgress.visible:=true;
    loginProgress.position:=30;
    doLoginThread:=TRequestThread.create('https://'+serverURL+'/client.php', 'usage=login&machine='+mac+'&ip='+ip+'&uname='
    +uname.text+'&password='+passwd.text+'&globalpw='+globalPW+'&os='+os);
    doLoginThread.OnShowStatus:=@doLoginResponse;
    doLoginThread.resume;
  end;
end;

procedure Twindow.doLoginResponse(response: string);
var
  credentials: TStringList;
begin
  loginProgress.position:=80;
    //Login erfolgreich
    if (response = '0') then begin
      shutdownTimer.enabled:=false;
      loginProgress.visible:=false;
      actionLabel.caption:=success;
      actionLabel.font.color:=clGreen;
      //Nutzerdaten für DRIVE speichern
      credentials:=TStringList.create;
      credentials.add(XOREncode(mac, uname.text));
      credentials.add(XOREncode(mac, passwd.text));
      {$IFDEF WINDOWS}
        credentials.saveToFile(getUserDir+'login.jkm');
      {$ENDIF}
      {$IFDEF LINUX}
        credentials.saveToFile('/tmp/login.jkm');
      {$ENDIF}
      credentials.free;
      uname.text:='';
      passwd.text:='';
      successTimer.enabled:=true;
    end
    //Login nicht erfolgreich
    else begin
      loginProgress.visible:=false;
      if (actualShutdown < 60) then begin
        actualShutdown:=180;
      end;
      uname.readOnly:=false;
      passwd.readOnly:=false;
      passwd.text:='';
      if (response = '1') then begin
        actionLabel.caption:=wrongCredentials;
      end
      else if (response = '2') or (response = '') then begin
        actionLabel.caption:=loginFailed;
      end;
    end;
end;

procedure Twindow.loadUsers;
begin
  loadUsersThread:=TRequestThread.create('https://'+serverURL+'/client.php', 'usage=userlist&globalpw='+globalPW+'&machine='+mac+'&ip='+ip);
  loadUsersThread.OnShowStatus:=@loadUsersResponse;
  loadUsersThread.resume;
end;

procedure Twindow.loadUsersResponse(response: string);
var
  c: integer;
  jData: TJSONData;
begin
  if (response = '') then begin
    if (allowOffline) then begin
      {$IFDEF WINDOWS}
        lock.disable;
        lock.free;
        keyboardHook(false);
      {$ENDIF}
      halt;
    end
    else begin
      errorTimer.enabled:=true;
      showMessage('Der Server ist nicht erreichbar. Der Computer wird heruntergefahren.');
      system(false);
    end;
  end
  else if (response = '!') then begin
    showMessage('Konfigurationsfehler. Programm wird beendet.');
    {$IFDEF WINDOWS}
      lock.disable;
      lock.free;
      keyboardHook(false);
    {$ENDIF}
    halt;
  end
  else begin
    userdata:=TStringList.create;
    fullUserdata:=TStringList.create;
    searchUserdata:=TStringList.create;
    jData:=GetJSON(response);
    c:=0;
    while (c < jData.count) do begin
      userdata.add(jData.FindPath(IntToStr(c)+'[2]').AsString);
      searchUserdata.add(jData.FindPath(IntToStr(c)+'[2]').AsString);
      fullUserdata.add(jData.FindPath(IntToStr(c)+'[0]').AsString+' '+jData.FindPath(IntToStr(c)+'[1]').AsString+' ('+jData.FindPath(IntToStr(c)+'[2]').AsString+')');
      usernames.items.add(jData.FindPath(IntToStr(c)+'[0]').AsString+' '+jData.FindPath(IntToStr(c)+'[1]').AsString+' ('+jData.FindPath(IntToStr(c)+'[2]').AsString+')');
      c:=c+1;
    end;
  end;
end;

procedure Twindow.usernamesSelectionChange(Sender: TObject; User: boolean);
var
  counter: integer;
begin
  counter:=0;
  while (counter < searchUserdata.count) do begin
    if (counter = usernames.ItemIndex) then begin
      uname.Text:=searchUserdata[counter];
      break;
    end;
    counter:=counter+1;
  end;
  passwd.setFocus;
end;

procedure Twindow.searchChange(Sender: TObject);
var
  counter: NativeInt;
  rpl: string;
begin
  usernames.items.clear();
  searchUserdata.clear();
  counter:=0;
  while (counter < fullUserdata.count) do begin
    rpl:=StringReplace(LowerCase(fullUserdata[counter]), LowerCase(search.text), '', [rfReplaceAll]);
    if not(LowerCase(fullUserdata[counter]) = rpl) or (search.Text = '') then begin
      usernames.items.add(fullUserdata[counter]);
      searchUserdata.add(userdata[counter]);
    end;
    counter:=counter+1;
  end;
end;

procedure Twindow.checkNetworkConnection;
var
  noPort: TStringList;
  cache: string;
begin
  if (pos(':', serverURL) > 0) then begin
    noPort:=TStringList.create;
    noPort.delimiter:=':';
    noPort.strictDelimiter:=true;
    noPort.delimitedText:=serverURL;
    cache:=noPort[0];
  end
  else begin
    cache:=serverURL;
  end;
  cleanServerURL:=cache;
  pingthread:=TPingThread.create(cache);
  pingthread.OnShowStatus:=@networkConnectionResult;
  pingthread.resume;
end;

procedure Twindow.networkConnectionResult(result: boolean; return: string);
var
  host: THostResolver;
begin
  if (result) then begin
    if (ValidateIP(cleanServerURL)) then begin
      if (cleanServerURL = return) then begin
        trueNetworkResult;
      end
      else begin
        noNetworkInfo.caption:='PING-Ergebnis: Wrong reply. Versuch: '+IntToStr(actualNetworkRetry);
        falseNetworkResult;
      end;
    end
    else begin
      host:=THostResolver.create(nil);
      host.clearData();
      if (host.NameLookup(cleanServerURL)) then begin
        if (host.AddressAsString = return) then begin
          trueNetworkResult;
        end
        else begin
          noNetworkInfo.caption:='PING-Ergebnis: Wrong reply. Versuch: '+IntToStr(actualNetworkRetry);
          falseNetworkResult;
        end;
      end
      else begin
        noNetworkInfo.caption:='PING-Ergebnis: DNS failed. Versuch: '+IntToStr(actualNetworkRetry);
        falseNetworkResult;
      end;
    end;
  end
  else begin
    noNetworkInfo.caption:='PING-Ergebnis: Host is down. Versuch: '+IntToStr(actualNetworkRetry);
    falseNetworkResult;
  end;
end;

procedure Twindow.trueNetworkResult;
begin
  reloadTimer.enabled:=false;
  lockUI(false);
  if not(isOnline) then begin
    loadConfig;
  end;
  isOnline:=true;
end;

procedure Twindow.falseNetworkResult;
begin
  reloadTimer.enabled:=true;
  lockUI(true);
  if (actualNetworkRetry >= networkRetry) then begin
    handleNoNetwork;
  end;
  actualNetworkRetry:=actualNetworkRetry+1;
end;

procedure Twindow.parseConfigFile;
var
  config, value: TStringList;
  c: integer;
begin
  config:=TStringList.create;
  {$IFDEF WINDOWS}
    config.loadFromFile('C:\Program Files\PhilleConnect\pcconfig.jkm');
  {$ENDIF}
  {$IFDEF LINUX}
    config.loadFromFile('/etc/pcconfig.jkm');
  {$ENDIF}
  c:=0;
  while (c < config.count) do begin
    if (pos('#', config[c]) = 0) then begin
      value:=TStringList.create;
      value.clear;
      value.strictDelimiter:=true;
      value.delimiter:='=';
      value.delimitedText:=config[c];
      case value[0] of
        'server':
          serverURL:=value[1];
        'global':
          globalPW:=value[1];
        'allowOffline':
          setAllowOffline(value[1]);
        'badNetworkReconnect':
          networkRetry:=StrToInt(value[1]);
      end;
    end;
    c:=c+1;
  end;
  checkNetworkConnection;
end;

procedure Twindow.loadConfig;
var
  os: string;
  MacAddr: TGetMacAdress;
  IPAddr: TGetIPAdress;
begin
  MacAddr:=TGetMacAdress.create;
  mac:=MacAddr.getMac;
  MacAddr.free;
  IPAddr:=TGetIPAdress.create;
  ip:=IPAddr.getIP;
  IPAddr.free;
  {$IFDEF WINDOWS}
    os:='win';
  {$ENDIF}
  {$IFDEF LINUX}
    os:='linux';
  {$ENDIF}
  loadConfigThread:=TRequestThread.create('https://'+serverURL+'/client.php', 'usage=config&globalpw='+globalPW+'&machine='+mac+'&ip='+ip+'&os='+os);
  loadConfigThread.OnShowStatus:=@loadConfigResponse;
  loadConfigThread.resume;
end;

procedure Twindow.loadConfigResponse(response: string);
var
  jData: TJSONData;
  c: integer;
begin
  if (response = '!') then begin
    showMessage('Konfigurationsfehler. Programm wird beendet.');
    {$IFDEF WINDOWS}
      lock.disable;
      lock.free;
      keyboardHook(false);
    {$ENDIF}
    halt;
  end
  else if (response = 'nomachine') then begin
    showMessage('Rechner nicht registriert. Programm wird beendet.');
    {$IFDEF WINDOWS}
      lock.disable;
      lock.free;
      keyboardHook(false);
    {$ENDIF}
    halt;
  end
  else if (response = 'noconfig') then begin
    showMessage('Rechner nicht fertig eingerichtet. Programm wird beendet.');
    {$IFDEF WINDOWS}
      lock.disable;
      lock.free;
      keyboardHook(false);
    {$ENDIF}
    halt;
  end
  else if (response <> '') then begin
    lockInputs(false);
    reloadTimer.Enabled:=false;
    jData:=GetJSON(response);
    c:=0;
    while (c < jData.count) do begin
      case jData.FindPath(IntToStr(c)+'[0]').AsString of
        'dologin':
          login:=jData.FindPath(IntToStr(c)+'[1]').AsString;
        'loginpending':
          loginPending:=jData.FindPath(IntToStr(c)+'[1]').AsString;
        'loginfailed':
          loginFailed:=jData.FindPath(IntToStr(c)+'[1]').AsString;
        'wrongcredentials':
          wrongCredentials:=jData.FindPath(IntToStr(c)+'[1]').AsString;
        'networkfailed':
          networkFailed:=jData.FindPath(IntToStr(c)+'[1]').AsString;
        'success':
          success:=jData.FindPath(IntToStr(c)+'[1]').AsString;
        'shutdown':
          prepareShutdownTimer(jData.FindPath(IntToStr(c)+'[1]').AsInteger);
        'infotext':
          loadTextBox(jData.FindPath(IntToStr(c)+'[1]').AsString);
        'servicemode':
          setAllowNoLogin(jData.FindPath(IntToStr(c)+'[1]').AsString);
      end;
      c:=c+1;
    end;
    loadUsers;
  end
  else begin
    lockInputs(true);
    handleNoNetwork;
  end;
end;

procedure Twindow.handleNoNetwork;
begin
  if (allowOffline) then begin
    {$IFDEF WINDOWS}
      lock.disable;
      lock.free;
      keyboardHook(false);
    {$ENDIF}
    halt;
  end
  else begin
    errorTimer.enabled:=true;
    showMessage('Der Server ist nicht erreichbar. Der Computer wird heruntergefahren.');
    system(false);
  end;
end;

procedure Twindow.lockInputs(mode: boolean);
begin
  if (mode) then begin
    actionLabel.caption:='Netzwerkverbindung wird aufgebaut...';
    uname.enabled:=false;
    passwd.enabled:=false;
    clearButton.enabled:=false;
    loginButton.enabled:=false;
    search.enabled:=false;
    usernames.enabled:=false;
  end
  else begin
    actionLabel.caption:='Bitte melde dich mit deinen Zugangsdaten an.';
    uname.enabled:=true;
    passwd.enabled:=true;
    clearButton.enabled:=true;
    loginButton.enabled:=true;
    search.enabled:=true;
    usernames.enabled:=true;
    if (window.visible) then begin
      search.setFocus;
    end;
  end;
end;

procedure Twindow.lockUI(mode: boolean);
begin
  if (mode) then begin
    window.color:=clBlack;
    rechnerBox.visible:=false;
    usersBox.visible:=false;
    loginBox.visible:=false;
    newsBox.visible:=false;
    versionLabel.visible:=false;
    headline.font.color:=clWhite;
    noNetworkInfo.visible:=true;
    noNetworkHead.visible:=true;
    noNetworkSub.visible:=true;
    noNetworkHead.left:=(window.width div 2)-(noNetworkHead.width div 2);
    noNetworkHead.top:=(window.height div 2)-(noNetworkHead.height div 2)-30;
    noNetworkSub.left:=(window.width div 2)-(noNetworkSub.width div 2);
    noNetworkSub.top:=(window.height div 2)-(noNetworkSub.height div 2)+20;
  end
  else begin
    window.color:=clDefault;
    rechnerBox.visible:=true;
    usersBox.visible:=true;
    loginBox.visible:=true;
    newsBox.visible:=true;
    versionLabel.visible:=true;
    headline.font.color:=clDefault;
    noNetworkInfo.visible:=false;
    noNetworkHead.visible:=false;
    noNetworkSub.visible:=false;
    if (window.visible) then begin
      search.setFocus;
    end;
  end;
end;

procedure Twindow.prepareShutdownTimer(seconds: integer);
begin
  actualShutdown:=seconds;
  shutdownProgress.max:=seconds;
  shutdownProgress.position:=seconds;
  shutdownTimer.enabled:=true;
  shutdownLabel.caption:='Der Rechner wird nach '+IntToStr(seconds)
  +' Sekunden ohne Eingabe automatisch heruntergefahren.';
end;

procedure Twindow.loadTextBox(infotext: string);
var
  content: TStringList;
begin
  content:=TStringList.create;
  content.delimiter:='%';
  content.strictDelimiter:=true;
  content.delimitedText:=infotext;
  news.lines:=content;
end;

procedure Twindow.setAllowOffline(value: string);
begin
  if (value = '1') then begin
    allowOffline:=true;
  end
  else begin
    allowOffline:=false;
  end;
end;

procedure Twindow.setAllowNoLogin(value: string);
begin
  if (value = 'noPasswordRequired') then begin
    {$IFDEF WINDOWS}
      lock.disable;
      lock.free;
      keyboardHook(false);
    {$ENDIF}
    halt;
  end;
end;

{$IFDEF WINDOWS}
procedure Twindow.keyboardHook(mode: boolean);
begin
  if (mode) then begin
    if (@installHook <> nil) then begin
      installHook(handle, false);
    end;
  end
  else begin
    if (@uninstallHook <> nil) then begin
      uninstallHook;
    end;
  end;
end;
{$ENDIF}

function Twindow.sendRequest(url, params: string): string;
var
   Response: TMemoryStream;
begin
  Response := TMemoryStream.Create;
  try
    if HttpPostURL(url, params, Response) then
      result:=MemStreamToString(Response);
  finally
    Response.Free;
  end;
end;

function Twindow.MemStreamToString(Strm: TMemoryStream): AnsiString;
begin
  if Strm <> nil then begin
    Strm.Position := 0;
    SetString(Result, PChar(Strm.Memory), Strm.Size);
  end;
end;

function Twindow.ValidateIP(IP4: string): Boolean; // Coding by Dave Sonsalla
var
  Octet : String;
  Dots, I : Integer;
begin
  IP4 := IP4+'.'; //add a dot. We use a dot to trigger the Octet check, so need the last one
  Dots := 0;
  Octet := '0';
  for I := 1 to length(IP4) do begin
    if IP4[I] in ['0'..'9','.'] then begin
      if IP4[I] = '.' then begin //found a dot so inc dots and check octet value
        Inc(Dots);
        if (length(Octet) =1) Or (StrToInt(Octet) > 255) then Dots := 5; //Either there's no number or it's higher than 255 so push dots out of range
        Octet := '0'; // Reset to check the next octet
      end // End of IP4[I] is a dot
      else // Else IP4[I] is not a dot so
        Octet := Octet + IP4[I]; // Add the next character to the octet
    end // End of IP4[I] is not a dot
    else // Else IP4[I] Is not in CheckSet so
      Dots := 5; // Push dots out of range
  end;
  result := (Dots = 4) // The only way that Dots will equal 4 is if we passed all the tests
end;

end.

