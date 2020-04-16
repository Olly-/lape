unit lpvartypes_map;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  lptypes, lpvartypes, lpvartypes_array, lpvartypes_record, lptree;

type
  TLapeTree_InternalMethod_StringMap = class(TLapeTree_InternalMethod)
  protected
    FValueType: TLapeType;
  public
    function isConstant: Boolean; override;
    function resType: TLapeType; override;
    function Evaluate: TLapeGlobalVar; override;

    constructor Create(ACompiler: TLapeCompilerBase; ADocPos: PDocPos=nil); override;
  end;

  TLapeType_StringMap = class(TLapeType_DynArray)
  protected
    FValueType: TLapeType;
  public
    function CreateCopy(DeepCopy: Boolean=False): TLapeType; override;

    constructor Create(AValueType: TLapeType; ACompiler: TLapeCompilerBase); reintroduce;
  end;

implementation

uses
  lpcompiler;

function TLapeType_StringMap.CreateCopy(DeepCopy: Boolean): TLapeType;
begin
  Result := inherited CreateCopy(DeepCopy);

  TLapeType_StringMap(Result).FValueType := FValueType;
end;

constructor TLapeType_StringMap.Create(AValueType: TLapeType; ACompiler: TLapeCompilerBase);
var
  Entry: TLapeType_Record;
begin
  inherited Create(nil, ACompiler);

  FValueType := AValueType;

  Entry := FCompiler.addManagedType(TLapeType_Record.Create(FCompiler, nil)) as TLapeType_Record;
  with Entry do
  begin
    addField(FCompiler.getBaseType(ltString), 'Key');
    addField(FValueType, 'Value');
  end;

  FPType := FCompiler.addManagedType(TLapeType_DynArray.Create(Entry, FCompiler)) as TLapeType_DynArray;
end;

function TLapeTree_InternalMethod_StringMap.isConstant: Boolean;
begin
  FConstant := bTrue;

  Result := inherited;
end;

function TLapeTree_InternalMethod_StringMap.resType: TLapeType;
var
  Header: TLapeType_MethodOfType;
begin
  if (FResType = nil) then
  begin
    FValueType := TLapeTree_VarType(FParams[0]).VarType;
    FResType := FCompiler.addManagedDecl(FCompiler.addLocalDecl(TLapeType_StringMap.Create(FValueType, FCompiler))) as TLapeType_DynArray;

    Header := TLapeType_MethodOfType.Create(FCompiler, FResType, [FCompiler.getBaseType(ltString), FValueType], [lptConstRef, lptConstRef]);
    Header := FCompiler.addManagedType(Header) as TLapeType_MethodOfType;

    TLapeCompiler(FCompiler).addGlobalFunc(Header, 'Add',
      'begin _StringMap_Add(Pointer(@Self), Param0, Param1, SizeOf(Param1)); end;'
    );

    Header := TLapeType_MethodOfType.Create(FCompiler, FResType, [FCompiler.getBaseType(ltString)], [lptConstRef], FValueType);
    Header := FCompiler.addManagedType(Header) as TLapeType_MethodOfType;

    TLapeCompiler(FCompiler).addGlobalFunc(Header, 'Get',
      'begin _StringMap_Get(Pointer(@Self), Param0, Result, SizeOf(Result)); end;'
    );
  end;

  Result := inherited;
end;

function TLapeTree_InternalMethod_StringMap.Evaluate: TLapeGlobalVar;
begin
  if (FRes = nil) then
    FRes := FCompiler.getTypeVar(resType());

  Result := inherited;
end;

constructor TLapeTree_InternalMethod_StringMap.Create(ACompiler: TLapeCompilerBase; ADocPos: PDocPos);
begin
  inherited Create(ACompiler, ADocPos);

  IsGeneric := True;
end;

end.

