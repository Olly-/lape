unit lpvartypes_map;

{$mode objfpc}{$H+}
{$rangechecks OFF}

interface

uses
  Classes, SysUtils,
  lptypes, lpvartypes, lpvartypes_array, lpvartypes_record, lpcompiler, lptree;

type

  { TLapeTree_InternalMethod_Map }

  TLapeTree_InternalMethod_Map = class(TLapeTree_InternalMethod)
  protected
    FEntry: TLapeType_Record;
    FTable1D: TLapeType_DynArray;
    FTable2D: TLapeType_DynArray;
  public
    constructor Create(ACompiler: TLapeCompilerBase; ADocPos: PDocPos = nil); override;
    function isConstant: Boolean; override;
    procedure addMethod(Name: String; AParams: array of TLapeType; AParamTypes: array of ELapeParameterType; ResultType: TLapeType; Body: String);
    function resType: TLapeType; override;
    function Evaluate: TLapeGlobalVar; override;
  end;

procedure InitializeMapType(Compiler: TLapeCompiler);

implementation

constructor TLapeTree_InternalMethod_Map.Create(ACompiler: TLapeCompilerBase; ADocPos: PDocPos);
begin
  inherited Create(ACompiler, ADocPos);

  FForceParam := False;
end;

function TLapeTree_InternalMethod_Map.isConstant: Boolean;
begin
  FConstant := bTrue;

  Result := inherited;
end;

procedure TLapeTree_InternalMethod_Map.addMethod(Name: String; AParams: array of TLapeType; AParamTypes: array of ELapeParameterType; ResultType: TLapeType; Body: String);
var
  Header: TLapeType_MethodOfType;
  Param: TLapeParameter;
  i: Int32;
begin
  Header := TLapeType_MethodOfType.Create(FCompiler, FTable2D, nil, ResultType, Name);

  for i := 0 to High(AParams) do
  begin
    Param := NullParameter;
    Param.VarType := AParams[i];
    Param.ParType := AParamTypes[i];

    Header.Params.Add(Param);
  end;

  with FCompiler as TLapeCompiler do
  begin
    Header := addManagedDecl(Header) as TLapeType_MethodOfType;

    addGlobalFunc(Header, Name, Body);
  end;
end;

function TLapeTree_InternalMethod_Map.resType: TLapeType;
begin
  if (FResType = nil) then
  begin
    FEntry := FCompiler.addLocalDecl(TLapeType_Record.Create(FCompiler, nil, '')) as TLapeType_Record;
    with FEntry do
    begin
      addField(TLapeTree_VarType(FParams[0]).VarType, 'Key');
      addField(TLapeTree_VarType(FParams[1]).VarType, 'Value');
    end;

    FTable1D := FCompiler.addLocalDecl(TLapeType_DynArray.Create(FEntry, FCompiler)) as TLapeType_DynArray;
    FTable2D := FCompiler.addLocalDecl(TLapeType_DynArray.Create(FTable1D, FCompiler)) as TLapeType_DynArray;

    FCompiler.Options := FCompiler.Options + [lcoLooseSyntax];

    addMethod('Init', [FCompiler.BaseTypes[ltUInt32]], [lptConstRef], nil,
      'begin' + LineEnding +
      '  SetLength(Self, Param0);' + LineEnding +
      'end;'
    );

    addMethod('Add', [TLapeTree_VarType(FParams[0]).VarType, TLapeTree_VarType(FParams[1]).VarType], [lptNormal, lptNormal], nil,
      'begin' + LineEnding +
      '  var h: UInt32 := Hash(Param0) and Length(Self[0]);'                     + LineEnding +
      '  var l: Int32 := Length(Self[h]);'                                       + LineEnding +
      '  SetLength(Self[h], l + 1);'                                             + LineEnding +
      '  Self[h][l].Key := Param0;'                                              + LineEnding +
      '  Self[h][l].Value := Param1;'                                            + LineEnding +
      'end;'
    );

    addMethod('Get', [TLapeTree_VarType(FParams[0]).VarType, TLapeTree_VarType(FParams[1]).VarType], [lptConstRef, lptVar], FCompiler.BaseTypes[ltEvalBool],
      'begin' + LineEnding +
      '  var h: UInt32 := Hash(Param0) and Length(Self[0]);'                     + LineEnding +
      '  var l: Int32 := High(Self[h]);'                                         + LineEnding +
      '  var i: Int32;'                                                          + LineEnding +
      '  for i := 0 to l do'                                                     + LineEnding +
      '  if (Self[h][i].Key = Param0) then'                                      + LineEnding +
      '  begin'                                                                  + LineEnding +
      '    Param1 := Self[h][i].Value;'                                          + LineEnding +
      '    Exit(True);'                                                          + LineEnding +
      '  end;'                                                                   + LineEnding +
      'end;'
    );

    FCompiler.Options := FCompiler.Options - [lcoLooseSyntax];

    FResType := FTable2D;
  end;

  Result := inherited;
end;

function TLapeTree_InternalMethod_Map.Evaluate: TLapeGlobalVar;
begin
  if (FRes = nil) then
    FRes := FCompiler.getTypeVar(resType());

  Result := inherited Evaluate;
end;

procedure _Lape_HashString(const Params: PParamArray; const Result: Pointer); {$IFDEF Lape_CDECL}cdecl;{$ENDIF}

  function HashString(constref k: lpString): UInt32;
  var i:Int32;
  begin
    Result := $811C9DC5;
    for i := 1 to Length(k) do
    begin
      Result := Result xor Ord(k[i]);
      Result := Result * $1000193;
    end;
  end;

begin
  PUInt32(Result)^ := HashString(PlpString(Params^[0])^);
end;

procedure InitializeMapType(Compiler: TLapeCompiler);
begin
  Compiler.InternalMethodMap['Map'] := TLapeTree_InternalMethod_Map;
  Compiler.addGlobalFunc('function Hash(constref Data: String): UInt32;', @_Lape_HashString);
end;

end.

