unit uftab_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, LCLProc, ShellAPI,fphttpclient;

type

  { TForm1 }

  TForm1 = class(TForm)
    eFilter: TEdit;
    lv: TListView;
    procedure eFilterChange(Sender: TObject);
    procedure eFilterKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure lvDblClick(Sender: TObject);
  private
    { private declarations }
  public
    FileName:string; // Table ToLoad
    inited:boolean;
    fAction:string; // action onRow
    procedure ReloadFiltered(F:WideString);
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

function getTill(var S:WideString; Del:string):Widestring; // extract word till a tab
var i:integer;
begin
  i:=Pos(Del,S);
  if i=0 then begin  Result:=S; S:=''; end
  else begin Result:=Copy(S,1,i-Length(Del)); Delete(S,1,i+Length(Del)-1); end;
end;



function getTabWord(var S:WideString):Widestring; // extract word till a tab
//var i:integer;
begin
  Result:=getTill(S,#9);
  {
  i:=Pos(#9,S);
  if i=0 then begin  Result:=S; S:=''; end
  else begin Result:=Copy(S,1,i-1); Delete(S,1,i); end;
  }
end;

function getRow(var S:WideString):WideString;
var l:integer;
begin
  Result:=getTill(S,#10);
  l:=Length(Result);
  if (l>0) and (Result[l]=#13) then Delete(Result,l,1);
end;

function getRowCount(S:Widestring):integer;
begin
  Result:=0;
  while S<>'' do begin
    getRow(S); inc(Result);
  end;
end;

function trans(Row:Utf8String):Utf8String;
var i,p:integer;
var P2:WideString;
const P1:WideString='QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?';
      p2_u='ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,';
var R,Out:WideString;
begin
  R:=Utf8Decode(Row);
  P2:=Utf8Decode(P2_u); // couse it is in
  Out:='';
  for i:=1 to Length(R) do begin
    p:=Pos(R[i],P1);
     if (p>0) then Out:=Out+P2[p]
       else   Out:=Out+R[i];
    end;
    Result:=Utf8Encode(Out);
end;

function FilterOK(Row,F:Widestring):boolean;
begin
  Row:=UTF8UpperCase(Row);
  F:=UTF8UpperCase(F);
  Result:=Pos(F,Row)>0;
  if Result then exit;
  Result:=Pos( trans(F), Row)>0; // try lat->rus
end;

function strLoad(FileName:String):string;
var S:TStringList;
begin
  S:=TStringList.Create;   S.LoadFromFile(FileName); Result:=S.Text; S.Free;
end;


function strReplace(S,F,T:string):String;
var p:integer;
begin
  p:=Pos(F,S); if (p=0) then begin Result:=S; exit; end; // not found - no changes
  Result:=Copy(S,1,p-1) + T+ Copy(S,p+Length(F),Length(S)); // change it
end;

procedure TForm1.ReloadFiltered(F:WideString);
var Row,Txt,W:WideString;
    i,j,col_count,row_count:integer;
    LI:TListItem;
    LC:TListColumn;
    firstLoad:boolean;
begin
  lv.Items.Clear;
    if Pos('http://',FileName)=1 then  txt := TFPCustomHTTPClient.SimpleGet(strReplace( FileName,'$f', F)) //;'http://10.77.36.58/cgi-bin/cc.sh?f:'+F);
        else txt:=strLoad(FileName); //  ShowMessage(Row);
    row_count:=getRowCount(Txt);
  lv.BeginUpdate;      FirstLoad:=false;
  col_count:=lv.Columns.Count;

  for i:=0 to row_count-1 do begin
     Row:=GetRow(Txt); //S[i];
     if (i=0) then begin
        // first call - fill columns from a Row
        if not inited then begin
        col_count:=0;      LV.Columns.Clear;
        while(Row<>'') do begin
        LC:=lv.Columns.Add;
         LC.Caption:=GetTabWord(Row);
         LC.Width:=200;
         inc(col_count);
        end;
        inited:=true;  FirstLoad:=true;
        end;
        continue; // headers
        end;
     if (F='') or FilterOk(Row,F) then begin
     W:=GetTabWord(Row);
     LI:=lv.Items.Add;
     LI.Caption:=W;
     for j:=0 to col_count do  LI.SubItems.Add( GetTabWord(Row)); // Num,Mobile
     end;
  end;
lv.EndUpdate;
if FirstLoad then begin // AutoSize columns width
  for j:=0 to lv.Columns.Count-1 do lv.Columns[j].width:=-2;
  end;
//  Caption:='F='+F+' upper:'+ trans( UTF8UpperCase(F) );
end;

procedure TForm1.eFilterChange(Sender: TObject);
begin

end;

procedure TForm1.eFilterKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState
  );
begin
  ReloadFiltered(eFilter.Text);
  if (Key = 13) and (lv.Items.Count = 1) then begin // single result -> default action
    lv.Selected:=lv.Items[0];
   lvDblClick(Self);
  end;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  FileName:='view.fv'; // default file name
  if ParamCount>0 then begin
       //ShowMessage(ParamStr(1));
       FileName:=ParamStr(1);
       end;
  if ParamCount>1 then begin
       fAction:=ParamStr(2);
       end;
  //ShowMessage(inttostr(ParamCount)+' fAction:'+fAction);
  Caption:=FileName;
  eFilter.Text:='';
  ReloadFiltered('');
end;

procedure Dial(Num:string);
begin
  Num:='tel:'+Num;
  ShellExecute(0,'open',PCHAR(num),nil,nil,0);
end;


procedure TForm1.lvDblClick(Sender: TObject);
var P:TPOINT;
    i,row:integer;
    num,N,V,Act:String;
begin
//  P:=Mouse.get
 // lv.GetHitTestInfoAt(ms.X,ms.Y);
  //row:= lv.Selected;
  if fAction='' then exit;
  Act:=fAction;
  if lv.Selected = nil then exit;
  for i:=0 to lv.Columns.Count-1 do begin
    N:=lv.Columns[i].Caption; V:='';
    if i=0 then V:=lv.Selected.Caption
      else if (i-1)<lv.Selected.Subitems.Count then V:=lv.Selected.SubItems[i-1];
    // now - replace
    Act:=strReplace(Act,'$'+N,V);           /// $Name
    Act:=strReplace(Act,'$'+inttostr(i),V);      // $0 $1 ...
    end;
    //num:=lv.Selected.SubItems[0];
    //Dial(num);
//ShowMessage(Act); // Resulted Action
ShellExecute(0,'open',PCHAR(Act),nil,nil,0);
end;


end.

