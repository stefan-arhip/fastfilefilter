unit uMain;

{$mode objfpc}{$H+}

interface

uses
  ShellApi, Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  ComCtrls, StdCtrls, PairSplitter, ExtCtrls, Buttons, Menus, EditBtn, LazUTF8,
  ListViewFilterEdit, ListFilterEdit, CommCtrl, StrUtils, Clipbrd;

type

  { TfMain }

  TfMain = class(TForm)
    biFolderGo: TBitBtn;
    biFolderUp: TBitBtn;
    buDelete: TButton;
    buDownload: TButton;
    buUpload: TButton;
    edPath: TDirectoryEdit;
    hcLocalFiles: THeaderControl;
    hcRemoteDevice: THeaderControl;
    ImageList1: TImageList;
    lf_LocalFiles: TListViewFilterEdit;
    lf_RemoteFiles: TListFilterEdit;
    ListBox1: TListBox;
    lvLocalFiles: TListView;
    miCopyLine: TMenuItem;
    PairSplitter1: TPairSplitter;
    PairSplitterSide1: TPairSplitterSide;
    PairSplitterSide2: TPairSplitterSide;
    Panel1: TPanel;
    Panel2: TPanel;
    pnLocal: TPanel;
    pnRemote: TPanel;
    PopupMenu1: TPopupMenu;
    StatusBar1: TStatusBar;
    procedure biFolderGoClick(Sender: TObject);
    procedure biFolderUpClick(Sender: TObject);
    procedure lvLocalFilesSelectItem(Sender: TObject; Item: TListItem;
      Selected: boolean);
    procedure miCopyLineClick(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
  private

  public

  end;

  TCustomInt = class
  private
    fId: integer;
  public
    property Id: integer read fId write fId;
    constructor Create(_Id: integer);
  end;

var
  fMain: TfMain;

implementation

{$R *.lfm}

{ TfMain }

var
  strFilterFileExt: string;
  intFilterFileSize: integer;

constructor TCustomInt.Create(_Id: integer);
begin
  fId := _Id;
end;

function FilesizeToCustomFormat(intFileSize: int64): string;
begin
  if intFileSize > 1024 * 1024 * 1024 then
    Result := Format('%.2f GB', [intFileSize / 1024 / 1024 / 1024])
  else if intFileSize > 1024 * 1024 then
    Result := Format('%.2f MB', [intFileSize / 1024 / 1024])
  else if intFileSize > 1024 then Result := Format('%.2f KB', [intFileSize / 1024])
  else
    Result := Format('%d', [intFileSize]);
end;

procedure TfMain.biFolderUpClick(Sender: TObject);
var
  Path, NewPath: string;
  i: integer;
begin
  Path := ExcludeTrailingPathDelimiter(edPath.Text);
  NewPath := '';
  i := Length(Path);
  repeat
    if Path[i] = '\' then
      NewPath := Copy(Path, 1, i);
    Dec(i);
  until (i = 1) or (NewPath <> '');
  if DirectoryExists(NewPath) then
  begin
    edPath.Text := NewPath;
  end;
  biFolderGoClick(Sender);
end;

procedure TfMain.lvLocalFilesSelectItem(Sender: TObject; Item: TListItem;
  Selected: boolean);
var
  SavedFilter, strDir: string;
  sL: TStringList;
  i: integer;
begin
  SavedFilter := lf_RemoteFiles.Text;
  lf_RemoteFiles.Text := '';
  lf_RemoteFiles.FilteredListbox := nil;

  ListBox1.Items.BeginUpdate;
  ListBox1.Items.Clear;
  sL := TStringList.Create;
  strDir := IncludeTrailingPathDelimiter(edPath.Directory);
  for i := 1 to lvLocalFiles.Items.Count do
    if lvLocalFiles.Items[i - 1].Selected then
    begin
      sL.LoadFromFile(strDir + lvLocalFiles.Items[i - 1].Caption);
      ListBox1.Items.AddStrings(sL);
    end;
  sL.Free;
  ListBox1.Items.EndUpdate;

  lf_RemoteFiles.FilteredListbox := Listbox1;
  lf_RemoteFiles.Text := SavedFilter;
end;

procedure TfMain.miCopyLineClick(Sender: TObject);
var
  sL: TStringList;
  i: integer;
begin
  sL := TStringList.Create;
  for i := 1 to ListBox1.Items.Count do
    if ListBox1.Selected[i - 1] then
      sL.Add(ListBox1.Items[i - 1]);
  Clipboard.AsText := sL.Text;
  //if ListBox1.ItemIndex >= 0 then
  //  Clipboard.AsText := ListBox1.Items[ListBox1.ItemIndex];
  sL.Free;
end;

procedure TfMain.PopupMenu1Popup(Sender: TObject);
begin
  miCopyLine.Enabled := ListBox1.ItemIndex >= 0;
end;

procedure TfMain.biFolderGoClick(Sender: TObject);
var
  sPath, sFile, sExt, sFilter: string;
  SysStr: WideString;
  intFileSize: int64;
  i, intFileDate: integer;
  dtFileDate: TDateTime;
  mIcon: TIcon;
  SearchRec: TSearchRec;
  ListItem: TListItem;
  FileInfo: SHFILEINFOw;
begin
  Screen.Cursor := crHourGlass;

  strFilterFileExt := '*';
  intFilterFileSize := MaxInt;

  hcLocalFiles.Sections.Items[0].Text :=
    Format('Size <= %d MB', [intFilterFileSize]);
  hcLocalFiles.Sections.Items[1].Text := Format('Ext %s', [strFilterFileExt]);

  sPath := edPath.Text;
  if sPath[Length(sPath)] <> '\' then
    sPath := sPath + '\';
  lvLocalFiles.SmallImages := ImageList1;
  mIcon := TIcon.Create;
  try
    sFilter := lf_LocalFiles.Text;
    lf_LocalFiles.Text := '';
    lf_LocalFiles.Items.Clear;
    lf_LocalFiles.FilteredListview := nil;

    lvLocalFiles.Items.BeginUpdate;
    lvLocalFiles.Items.Clear;
    i := FindFirst(sPath + '*.*', faAnyFile, SearchRec);
    while i = 0 do
    begin
      Application.ProcessMessages;
      with lvLocalFiles do
      begin
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        begin
          SysStr := UTF8ToUTF16(sPath + SearchRec.Name);

          if FileExists(SysStr) then
            intFileSize := FileSize(SysStr)
          else
            intFileSize := -1;

          sExt := ExtractFileExt(sysStr);
          if intFileSize < intFilterFileSize * 1024 * 1024 then
            if (intFileSize = -1) or (strFilterFileExt = '*') or
              AnsiContainsText(strFilterFileExt, sExt) then
            begin
              SHGetFileInfoW(pwidechar(SysStr), 0, FileInfo, SizeOf(FileInfo),
                SHGFI_DISPLAYNAME or SHGFI_TYPENAME or SHGFI_ICON or SHGFI_SMALLICON);
              sFile := UTF16ToUTF8(FileInfo.szDisplayName);
              mIcon.Handle := FileInfo.hIcon;

              ListItem := lvLocalFiles.Items.Add;
              ListItem.Caption := sFile;
              ListItem.ImageIndex := ImageList1.AddIcon(mIcon); // original
              ListItem.ImageIndex :=
                ImageList_ReplaceIcon(ImageList1.ReferenceForPPI[0,
                Font.PixelsPerInch].Handle, ListItem.ImageIndex, mIcon.Handle);
              ListItem.SubItems.AddObject(UTF16ToUTF8(FileInfo.szTypeName),
                TCustomInt.Create(ListItem.ImageIndex));

              if FileExists(sPath + sFile) then
              begin
                intFileDate := FileAge(sPath + sFile);
                if intFileDate > -1 then
                  dtFileDate := FileDateToDateTime(intFileDate);

                ListItem.SubItems.Add(FilesizeToCustomFormat(intFileSize));
                ListItem.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:mm', dtFileDate));
              end
              else
              begin
                ListItem.SubItems.Add('');
                ListItem.SubItems.Add('');
              end;
              ListItem.SubItems.Add(IntToStr(ListItem.ImageIndex));
            end;
        end;

      end;
      i := FindNext(SearchRec);
    end;
  finally
    lf_LocalFiles.FilteredListview := lvLocalFiles;
    lf_LocalFiles.Text := sFilter;
    lvLocalFiles.Items.EndUpdate;
    mIcon.Free;
    //LastSortedColumn := 0;
    //Ascending := True;
    //sbMain.Panels[0].Text:= Format('%d', [LastSortedColumn]);
  end;
  Screen.Cursor := crDefault;
  lvLocalFilesSelectItem(Sender, nil, False);
end;

end.
