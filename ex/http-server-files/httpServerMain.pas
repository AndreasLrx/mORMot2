unit httpServerMain;

{$I mormot.defines.inc}

interface

uses
  sysutils,
  classes,
  mormot.core.base,
  mormot.core.os,
  mormot.core.rtti,
  mormot.core.json,
  mormot.core.log,
  mormot.core.text,
  mormot.core.data,
  mormot.net.sock,
  mormot.net.http,
  mormot.net.server,
  mormot.net.async,
  mormot.lib.openssl11,
  mormot.crypt.openssl;

var
  silent: boolean;

procedure Main;

implementation


procedure Main;
var
  F: TSearchRec;
  fn: TFileName;
  console, verbose: boolean;
  settingsfolder, folder: TFileName;
  url: RawUtf8;
  settings: THttpProxyServerSettings;
  one: THttpProxyUrl;
  server: THttpProxyServer;
begin
  settings := THttpProxyServerSettings.Create;
  try
    // command line switches
    with Executable.Command do
    begin
      console := Option(['c', 'console'],    'debug output to the console');
      verbose := Option(['v', 'logverbose'], 'enable verbose log');
      silent  := Option('silent', 'no output to the console');
      SetObjectFromExecutableCommandLine(settings.Server, '', ' for HTTP/HTTPS');
      {$ifdef USE_OPENSSL}
      OpenSslDefaultPath := ParamS(['LibSsl'], 'OpenSSL libraries #path');
      if OpenSslInitialize then
        RegisterOpenSsl;
      {$endif USE_OPENSSL}
      settingsfolder := ParamS(['s', 'settings'], '#folder where *.json are located',
        Executable.ProgramFilePath + 'sites-enabled');
      folder := ParamS(['f', 'folder'], 'a local #foldername to serve');
      url := Param(['u', 'url'], 'a root #uri to serve this folder');
      if ConsoleHelpFailed('mORMot HTTP/HTTPS File Server') then
      begin
        ExitCode := 1;
        exit;
      end;
    end;
    // load local *.json files with URI
    if (settingsfolder <> '') and
       (FindFirst(settingsfolder + '*.json', faAnyFile - faDirectory, F) = 0) then
    begin
      repeat
        if SearchRecValidFile(F) then
        begin
          fn := Executable.ProgramFilePath + F.Name;
          one := THttpProxyUrl.Create;
          if JsonFileToObject(fn, one, nil, JSONPARSER_TOLERANTOPTIONS) then
            settings.AddUrl(one)
          else
            one.Free;
        end;
      until FindNext(F) <> 0;
      FindClose(F);
    end;
    // ensure we have something to serve (maybe from command line)
    if folder <> '' then
      settings.AddFolder(folder, url);
    if settings.Url = nil then
    begin
      ConsoleWrite('No folder to serve', ccLightRed);
      ExitCode := 2;
      exit;
    end;
    // setup the TSynLog context
    if console or
       verbose then
      with TSynLog.Family do
      begin
        if verbose then
        begin
          Level := LOG_VERBOSE;
          settings.Server.Options := settings.Server.Options + [psoLogVerbose];
        end
        else
          Level := [sllWarning] + LOG_FILTER[lfErrors];
        if console and
           not silent then
          EchoToConsole := Level;
        PerThreadLog := ptIdentifiedInOneFile;
        HighResolutionTimestamp := true;
        AutoFlushTimeOut := 1;

      end;
    // run the server
    server := THttpProxyServer.Create(settings);
    try
      if not silent then
        ConsoleWrite(['Bind server at ', settings.Server.Port]);
      server.Start;
      ConsoleWaitForEnterKey;
      if not silent then
        ConsoleWrite('Server shuting down');
    finally
      server.Free;
    end;
  finally
    settings.Free;
  end;
end;

end.

